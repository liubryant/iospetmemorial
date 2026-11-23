import SwiftUI
import Security

struct AccountSession: Codable, Equatable {
    let userId: String
    let phone: String
    let token: String
    var maskedPhone: String { phone.count == 11 ? String(phone.prefix(3)) + "****" + String(phone.suffix(4)) : phone }
}
enum AccountVault {
    private static var query: [String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"cn.cjym.petmemorial.account",kSecAttrAccount as String:"session"] }
    static func read() throws -> AccountSession? {
        var q=query; q[kSecReturnData as String]=true; q[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?; let status=SecItemCopyMatching(q as CFDictionary,&result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,let data=result as? Data else { throw MemorialError(message:"暂时无法读取登录信息，请解锁设备后重试") }
        return try JSONDecoder().decode(AccountSession.self,from:data)
    }
    static func save(_ session: AccountSession) throws {
        let data=try JSONEncoder().encode(session)
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var q=query; q[kSecValueData as String]=data; q[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(q as CFDictionary,nil) == errSecSuccess else { throw MemorialError(message:"无法保存登录状态，本机资料未被清除") }
        } else if status != errSecSuccess { throw MemorialError(message:"无法更新登录状态") }
    }
    static func clear() throws {
        let status=SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw MemorialError(message:"退出失败，请解锁设备后重试") }
    }
}
struct AccountAPI {
    var network: URLSession = .shared
    static func validPhone(_ phone:String)->Bool { phone.range(of:"^1[0-9]{10}$",options:.regularExpression) != nil }
    func post(_ path:String,_ body:[String:Any],token:String?=nil,guestKey:String?=nil) async throws -> [String:Any] {
        let host = path.hasPrefix("/api/petmemorial") ? "https://www.cjym123.cn:8066" : "https://www.cjym123.cn"
        var request=URLRequest(url:URL(string:host+path)!); request.httpMethod="POST"; request.timeoutInterval=20
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let token { request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization") }
        if let guestKey { request.setValue(guestKey,forHTTPHeaderField:"X-Guest-Key") }
        request.httpBody=try JSONSerialization.data(withJSONObject:body)
        let (data,response)=try await network.data(for:request)
        guard let http=response as? HTTPURLResponse, let json=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw MemorialError(message:"服务器响应格式异常，请稍后重试") }
        let success=(200...299).contains(http.statusCode) && (json["code"] == nil || (json["code"] as? Int)==0 || (json["code"] as? String)=="0")
        guard success else { throw MemorialError(message:(json["msg"] as? String) ?? (json["message"] as? String) ?? "操作失败，请稍后重试") }
        return json
    }
    func sendCode(phone:String) async throws { _=try await post("/im/bot/login-code",["phone":phone]) }
    func login(phone:String,credential:String,passwordMode:Bool,resetPassword:String?=nil) async throws -> (phone:String,token:String) {
        let device=await MainActor.run { (UIDevice.current.model,UIDevice.current.systemVersion) }
        var body:[String:Any]=["phone":phone,"deviceModel":device.0,"osVersion":device.1,"appName":"PetMemorial"]
        let path:String
        if let resetPassword { path="/im/bot/set-password";body["code"]=credential;body["password"]=resetPassword }
        else if passwordMode { path="/im/bot/login-by-password";body["password"]=credential }
        else { path="/im/bot/login-by-code";body["code"]=credential }
        let json=try await post(path,body); let result=json["data"] as? [String:Any] ?? [:]
        let token=[result["accessToken"],result["token"],json["accessToken"],json["token"]].compactMap { $0 as? String }.first { !$0.isEmpty }
        guard let token else { throw MemorialError(message:"登录接口未返回有效凭证，无法关联纪念园。请稍后重试") }
        return ((result["phone"] as? String).flatMap { $0.isEmpty ? nil:$0 } ?? phone,token)
    }
    func bind(token:String,guestKey:String,attach:Bool) async throws -> (session:AccountSession,adopted:Bool) {
        let json=try await post("/api/petmemorial/account/bind",["attachGuest":attach],token:token,guestKey:guestKey)
        guard let id=json["userId"] as? String,id.range(of:"^[0-9]+$",options:.regularExpression) != nil,let phone=json["phone"] as? String,let adopted=json["adoptedGuest"] as? Bool else { throw MemorialError(message:"账号关联结果不完整，请重试") }
        return (AccountSession(userId:id,phone:phone,token:token),adopted)
    }
}
@MainActor final class AccountStore: ObservableObject {
    @Published private(set) var session: AccountSession? = try? AccountVault.read()
    @Published var busy=false
    @Published var error:String?
    func signIn(phone:String,credential:String,passwordMode:Bool,resetPassword:String?,attach:Bool,garden:GardenStore) async -> Bool {
        guard !busy,!garden.isSyncing else { error="资料正在同步，请稍后登录";return false }
        busy=true;error=nil;defer { busy=false }
        do {
            let login=try await AccountAPI().login(phone:phone,credential:credential,passwordMode:passwordMode,resetPassword:resetPassword)
            let identity=try await AccountAPI().bind(token:login.token,guestKey:BackupKey.read(),attach:attach)
            try await garden.activateAccount(identity.session,adoptGuest:identity.adopted)
            session=identity.session
            return true
        } catch { self.error=error.localizedDescription;return false }
    }
    func signOut(garden:GardenStore) {
        guard !busy,!garden.isSyncing else { error="资料正在同步，请稍后退出";return }
        do { try garden.deactivateAccount();session=nil;error=nil }
        catch { self.error=error.localizedDescription }
    }
}

struct AccountLoginView: View {
    @EnvironmentObject private var account:AccountStore
    @EnvironmentObject private var garden:GardenStore
    @Environment(\.dismiss) private var dismiss
    private enum Field:Hashable { case phone,code,password }
    @FocusState private var focusedField:Field?
    @State private var phone=""
    @State private var code=""
    @State private var password=""
    @State private var mode=0
    @State private var accepted=false
    @State private var attach=true
    @State private var sending=false
    @State private var notice:String?
    @AppStorage("accountCodeDeadline") private var deadline=0.0
    private var enabled:Bool { AccountAPI.validPhone(phone) && accepted && !account.busy && !sending && (mode == 1 ? password.count >= 6 : code.count == 6 && (mode != 2 || password.count >= 6)) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    Image(systemName:"pawprint.fill").font(.system(size:35)).foregroundStyle(Palette.green).padding(23).background(.white,in:Circle())
                    Text(mode == 2 ? "找回熟悉的陪伴" : "让想念，与你相随").font(.system(size:28,weight:.medium,design:.serif)).foregroundStyle(Palette.ink)
                    Text("使用手机号登录，找回属于你和它的纪念。").font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
                    if mode != 2 { Picker("登录方式",selection:$mode) { Text("验证码登录").tag(0);Text("密码登录").tag(1) }.pickerStyle(.segmented).disabled(account.busy || sending) }
                    VStack(spacing:18) {
                        TextField("手机号",text:$phone).focused($focusedField,equals:.phone).keyboardType(.phonePad).textContentType(.telephoneNumber).onChange(of:phone) { _,value in phone=String(value.filter { $0.isASCII && $0.isNumber }.prefix(11)) }.padding(16).background(.white,in:RoundedRectangle(cornerRadius:16))
                        if mode != 1 {
                            HStack {
                                TextField("6 位验证码",text:$code).focused($focusedField,equals:.code).keyboardType(.numberPad).textContentType(.oneTimeCode).onChange(of:code) { _,value in code=String(value.filter { $0.isASCII && $0.isNumber }.prefix(6)) }
                                TimelineView(.periodic(from:.now,by:1)) { context in
                                    let seconds=max(0,Int(ceil(deadline-context.date.timeIntervalSince1970)))
                                    Button(seconds>0 ? "\(seconds)s" : "获取验证码") { sendCode() }.font(.subheadline.weight(.medium)).disabled(seconds>0 || !AccountAPI.validPhone(phone) || !accepted || sending || account.busy)
                                }
                            }.padding(16).background(.white,in:RoundedRectangle(cornerRadius:16))
                        }
                        if mode != 0 { SecureField(mode == 2 ? "设置新密码（至少 6 位）" : "密码（至少 6 位）",text:$password).focused($focusedField,equals:.password).textContentType(mode == 2 ? .newPassword:.password).padding(16).background(.white,in:RoundedRectangle(cornerRadius:16)) }
                    }.disabled(account.busy || sending)
                    if garden.garden != nil && account.session == nil {
                        Toggle("关联本机纪念资料和碑位",isOn:$attach).font(.subheadline)
                        Text("账号尚无纪念园时才会关联。若已有云端资料，将优先进入该账号；本机游客资料保留，退出后可继续查看。登录不会自动公开信件或开启云备份。").font(.caption).foregroundStyle(Palette.muted)
                    }
                    Toggle(isOn:$accepted) { Text("我已阅读并同意隐私与使用说明").font(.footnote) }.tint(Palette.green)
                    NavigationLink("查看隐私与使用说明") { PrivacyView() }.font(.footnote)
                    if let error=account.error { Text(error).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("loginError") }
                    if let notice { Text(notice).font(.footnote).foregroundStyle(Palette.green) }
                    Button {
                        Task { if await account.signIn(phone:phone,credential:mode == 1 ? password:code,passwordMode:mode == 1,resetPassword:mode == 2 ? password:nil,attach:attach && garden.garden != nil,garden:garden) { dismiss() } }
                    } label: { HStack { if account.busy { ProgressView().tint(.white) }; Text(mode == 2 ? "设置密码并登录" : "登录") } }.buttonStyle(PillButton()).disabled(!enabled)
                    HStack {
                        Button(mode == 2 ? "返回验证码登录" : "忘记密码？") { mode=mode == 2 ? 0:2;account.error=nil;password="" }.font(.footnote)
                        Spacer()
                        Text("验证码验证成功后，未注册账号将自动注册。").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    }
                }.padding(26)
            }.scrollDismissesKeyboard(.interactively).background(Palette.cream).navigationTitle("账号登录").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItemGroup(placement:.keyboard) { Spacer(); Button("完成") { focusedField=nil } }; ToolbarItem(placement:.cancellationAction) { Button("暂不登录") { dismiss() }.disabled(account.busy || sending) } }
        }.tint(Palette.green).interactiveDismissDisabled(account.busy || sending)
            .onChange(of:mode) { _,_ in account.error=nil;focusedField=nil }
    }
    private func sendCode() {
        guard accepted,AccountAPI.validPhone(phone),!sending,!account.busy,deadline<=Date().timeIntervalSince1970 else { return }
        sending=true;account.error=nil;notice=nil
        Task {
            defer { sending=false }
            do { try await AccountAPI().sendCode(phone:phone);deadline=Date().timeIntervalSince1970+60;notice="验证码已发送，请查看短信" }
            catch { account.error=error.localizedDescription }
        }
    }
}
