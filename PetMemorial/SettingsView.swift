import SwiftUI

struct SettingsView: View {
    @ObservedObject private var analytics = AppAnalytics.shared
    @State private var showAnalyticsConsent = false
    @AppStorage("parkAvatarStyle") private var avatarStyle = "classic"
    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var account: AccountStore
    @State private var showLogin = false
    @State private var showLogout = false
    @State private var restoreAccount = false
    @State private var consent = false
    @State private var deletion = false
    @State private var restore = false
    @State private var key: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let session=account.session {
                        HStack(spacing:14) {
                            Image(systemName:"person.crop.circle.fill")
                                .font(.system(size:42)).foregroundStyle(Palette.green)
                                .frame(width:60,height:60).background(Palette.cream,in:RoundedRectangle(cornerRadius:20))
                            VStack(alignment:.leading,spacing:6) {
                                Text(session.maskedPhone).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text(L("账号 ID：{0}", session.userId)).font(.caption).foregroundStyle(Palette.muted)
                            }
                        }.padding(.vertical,8)
                    } else {
                        Button { showLogin=true } label: {
                            HStack(spacing:14) {
                                Image(systemName:"person.crop.circle").font(.system(size:34)).foregroundStyle(Palette.green)
                                VStack(alignment:.leading,spacing:5) {
                                    Text(L("登录，让陪伴与你相随")).font(.headline).foregroundStyle(Palette.ink)
                                    Text(L("验证码 / 密码登录 · 留住每一份想念")).font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer();Image(systemName:"chevron.right").font(.caption)
                            }.padding(.vertical,10)
                        }.disabled(store.isSyncing).accessibilityIdentifier("openLogin")
                    }
                    if let error=account.error { Text(error).font(.caption).foregroundStyle(.red) }
                }

                Section {
                    Picker(selection: $avatarStyle) {
                        Text(L("默认 · 绿衣短发")).tag("classic")
                        Text(L("男生 · 蓝衣短发")).tag("male")
                        Text(L("女生 · 自然齐肩发")).tag("female")
                    } label: { settingsLabel(L("人物形象"),icon:"person.crop.square") }
                    .tint(Palette.green)
                } header: { Text(L("外观偏好")) } footer: {
                    Text(L("外观仅保存在本机，也可在小镇顶部菜单切换。"))
                }
                Section {
                    Button { if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: {
                        Label(L("在系统设置中更改语言"),systemImage:"globe")
                    }
                } header: { Text(L("语言")) } footer: { Text(L("跟随系统语言，可在系统设置中更改此应用的语言。")) }
                Section {
                    HStack(spacing:12) {
                        Image(systemName:store.state.cloudEnabled ? "checkmark.icloud" : "iphone")
                            .font(.title2).foregroundStyle(Palette.green)
                        VStack(alignment:.leading,spacing:5) {
                            Text(store.state.cloudEnabled ? L("本机 + 私密云备份") : L("资料保存在本机"))
                                .font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                            if let date = store.state.lastBackup {
                                Text(L("上次备份：{0}", date.formatted(.dateTime.month().day().hour().minute())))
                                    .font(.caption).foregroundStyle(Palette.muted)
                            } else { Text(L("保存方式")).font(.caption).foregroundStyle(Palette.muted) }
                        }
                    }.padding(.vertical,6)
                    Button {
                        if store.state.cloudEnabled { Task { await store.backup() } } else { consent = true }
                    } label: { HStack { settingsLabel(store.state.cloudEnabled ? L("立即备份") : L("开启云备份"), icon: "icloud.and.arrow.up"); Spacer(); if store.isSyncing { ProgressView() } } }
                        .disabled(store.garden == nil || store.isSyncing).opacity(store.garden == nil || store.isSyncing ? 0.4 : 1)
                    Button { do { key = try BackupKey.read() } catch { store.error = error.localizedDescription } } label: { settingsLabel(L("保管备份钥匙"), icon: "key") }.disabled(account.session != nil || !store.state.cloudEnabled || store.isSyncing).opacity(account.session != nil || !store.state.cloudEnabled || store.isSyncing ? 0.4 : 1)
                    Button { if account.session != nil { restoreAccount=true } else { restore=true } } label: { settingsLabel(account.session != nil ? L("恢复账号云备份") : L("恢复云端花园"), icon: "arrow.counterclockwise.icloud") }.disabled(store.isSyncing)
                } header: { Text(L("记忆备份")) } footer: {
                    Text(account.session != nil ? L("登录后，已开启的云备份归属当前账号。换设备使用同一手机号登录即可恢复；本机未备份内容不会自动上传。") : L("云备份开启后修改会自动同步。游客请保管备份钥匙；也可以登录并关联账号，通过账号恢复。"))
                }
                if account.session != nil {
                    Section(L("账号管理")) {
                        Button { showLogin=true } label: { settingsLabel(L("重新验证登录"),icon:"person.badge.key") }.disabled(store.isSyncing)
                        Button(L("退出登录"),role:.destructive) { showLogout=true }.disabled(store.isSyncing)
                    }
                }
                Section {
                    Toggle(L("使用统计"), isOn: Binding(get: { analytics.enabled }, set: { enabled in
                        if enabled { showAnalyticsConsent = true } else { analytics.decide(false) }
                    })).tint(Palette.green)
                } footer: { Text(L("可选的友盟应用统计，用于了解活跃情况与功能使用次数。关闭后停止统计，已上传数据不会自动删除。")) }
                Section(L("关于")) {
                    NavigationLink { LegalDocumentView(document:.agreement) } label: { settingsLabel(L("用户协议"),icon:"doc.text") }
                    NavigationLink { LegalDocumentView(document:.privacy) } label: { settingsLabel(L("隐私政策"),icon:"hand.raised.fill") }
                    NavigationLink { PrivacyView() } label: { settingsLabel(L("隐私与使用说明"), icon: "hand.raised") }
                    LabeledContent(L("版本"), value: L("1.0.0 · 首版"))
                }
                if store.garden != nil {
                    Section { Button(L("删除全部纪念资料"), role: .destructive) { deletion = true }.disabled(store.isSyncing) } footer: { Text(L("删除照片、信件和纪念资料，释放已认领的公开碑位；已开启的云备份也会一并删除。不会删除系统相册的原图。")) }
                }
                Section {
                    VStack(spacing:8) {
                        Label(L("宠物纪念馆"),systemImage:"pawprint.fill").font(.subheadline.weight(.medium))
                        Text(L("没有要求你放下，也不急着说再见。\n愿这里成为你安放想念的小小角落。"))
                            .font(.caption).lineSpacing(5).multilineTextAlignment(.center)
                    }.foregroundStyle(Palette.muted).frame(maxWidth:.infinity).padding(.vertical,12)
                }.listRowBackground(Color.clear)
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Palette.cream).navigationTitle(L("我的"))
                .alert(L("开启私密云备份？"), isPresented: $consent) {
                    Button(L("暂不开启"), role: .cancel) { }
                    Button(L("同意并备份")) { Task { await store.enableCloud() } }
                } message: { Text(L("宠物资料、照片、信件和花园设置将通过 HTTPS 上传至开发者运营的中国境内服务器。内容不会公开展示；备份不是端到端加密。持有备份钥匙的人可以访问或删除资料，请勿分享给他人。")) }
                .alert(L("永久删除全部纪念资料？"), isPresented: $deletion) {
                    Button(L("保留"), role: .cancel) { }
                    Button(L("确认删除"), role: .destructive) { Task { await store.deleteGarden() } }
                } message: { Text(L("此操作无法撤销。如已认领碑位或开启云备份，需要联网完成删除；失败时将保留本机资料。")) }
                .confirmationDialog(L("用当前账号的云备份替换本机纪念资料？尚未备份的本机更改会被覆盖。"),isPresented:$restoreAccount,titleVisibility:.visible) { Button(L("确认恢复"),role:.destructive) { Task { await store.restoreAccountBackup() } } }
                .sheet(isPresented: $showAnalyticsConsent) { AnalyticsConsentView() }
                .sheet(isPresented: $restore) { RestoreView() }
                .sheet(isPresented: $showLogin) { AccountLoginView() }
                .confirmationDialog(L("退出后回到游客花园，账号的纪念资料和已认领碑位会保留。"),isPresented:$showLogout,titleVisibility:.visible) { Button(L("确认退出"),role:.destructive) { account.signOut(garden:store) } }
                .sheet(isPresented: Binding(get: { key != nil }, set: { if !$0 { key = nil } })) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 24) {
                            Image(systemName: "key.horizontal").font(.largeTitle).foregroundStyle(Palette.green)
                            Text(L("这把钥匙，只交给你")).font(.title2.weight(.medium))
                            Text(L("它可以在另一台设备恢复你的纪念花园。任何持有者都能读取或删除备份，建议存入密码管理器，不要发布到聊天群或社交平台。"))
                            Text(key ?? "").font(.system(.footnote, design: .monospaced)).textSelection(.enabled).padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                            ShareLink(item: key ?? "") { Label(L("导出备份钥匙"), systemImage: "square.and.arrow.up") }.buttonStyle(PillButton())
                            Spacer()
                        }.padding(24).background(Palette.cream).navigationTitle(L("备份钥匙")).navigationBarTitleDisplayMode(.inline).toolbar { Button(L("关闭")) { key = nil } }
                    }
                }
        }
    }
    private func settingsLabel(_ title:String, icon:String) -> some View {
        HStack(spacing:12) {
            Image(systemName:icon).font(.system(size:16,weight:.medium))
                .foregroundStyle(Palette.green).frame(width:32,height:32)
                .background(Palette.green.opacity(0.08),in:RoundedRectangle(cornerRadius:10))
            Text(title).foregroundStyle(Palette.ink)
        }.padding(.vertical,2)
    }

}
struct RestoreView: View {
    @EnvironmentObject private var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            Form {
                Section(L("输入备份钥匙")) {
                    TextField(L("64 位钥匙"), text: $key, axis: .vertical).font(.system(.body, design: .monospaced)).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section { Text(L("恢复会用云端资料替换本机花园。请先确认当前内容已保存到你需要的位置。恢复失败不会替换本机记录。")) }
                Button { confirm = true } label: { HStack { Text(L("恢复花园")); if store.isSyncing { ProgressView() } } }.disabled(store.isSyncing || key.trimmingCharacters(in: .whitespacesAndNewlines).count != 64)
            }.navigationTitle(L("恢复云端花园")).navigationBarTitleDisplayMode(.inline).toolbar { Button(L("关闭")) { dismiss() }.disabled(store.isSyncing) }
                .alert(L("用云备份替换本机资料？"), isPresented: $confirm) {
                    Button(L("取消"), role: .cancel) { }
                    Button(L("确认恢复")) { Task { await store.restore(key: key); if store.error == nil { dismiss() } } }
                }
        }.interactiveDismissDisabled(store.isSyncing)
    }
}
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(L("只属于你们的记忆")).font(.title2.weight(.medium))
                paragraph(L("本机保存"), L("默认在本机保存宠物资料、你选择的照片、信件与纪念设置。选照片使用系统选择器，不会扫描或上传整本相册。删除应用可能丢失本机资料。"))
                paragraph(L("可选云备份"), L("同意开启后，以上内容通过 HTTPS 发送至开发者服务器并保存于中国境内。云端按备份钥匙隔离，不公开展示，也没有陌生人聊天。数据不是端到端加密；不要上传身份证件、家庭住址等无关敏感信息。"))
                paragraph(L("共享纪念园"), L("主动认领并确认后，仅公开宠物昵称、相册首张照片及纪念介绍。其他照片与信件不会公开。修改私密资料后，需在纪念碑详情点击更新公开资料。可以释放碑位撤回公开内容；每个身份仅可认领一座碑位。"))
                paragraph(L("纪念分享与访客互动"), L("公开纪念页可在浏览器访问，只展示你已发布的昵称、首张照片和介绍。访客献花、点灯会保存互动类型、日期及匿名身份索引；仅主人可查看最近来访记录，不展示手机号。收藏按当前身份保存，可随时取消。释放碑位将使原链接失效，并删除对应祝福和收藏关联；别人已保存的分享图片无法远程收回。"))
                paragraph(L("本地提醒"), L("纪念日通知默认关闭，开启前申请系统通知权限。提醒日期和开关仅用于本机通知；退出账号会取消该账号的待发提醒。系统关闭通知或勿扰模式可能影响提醒展示。"))
                paragraph(L("账号登录"), L("复用已有后台手机号账号，支持验证码与密码登录。登录令牌保存在设备钥匙串中。首次确认关联时，可将游客资料及碑位绑定到账户；已有云端资料不会被游客资料覆盖。账号与游客的本机数据分开保存。退出不会注销账号或删除其纪念碑。验证码登录可能自动注册账号。"))
                paragraph(L("可选使用统计 · 友盟"), L("SDK 名称：友盟移动统计 SDK（UMCommon / UMDevice）。服务提供方：友盟同欣（北京）科技有限公司。用途：统计应用启动、活跃情况与功能使用次数。仅在你选择同意后初始化；处理设备标识（如 IDFV）、设备型号、系统与应用版本、网络信息（包括 IP 地址、网络状态）及使用事件。本次不接入广告追踪，不申请定位权限。自定义事件只含固定功能名称，不提交宠物资料、照片、信件、手机号、账号 ID 或登录令牌。可在“我的 → 使用统计”中关闭统计；已上传数据如需查询或删除，可通过友盟隐私政策中的联系渠道申请处理。"))
                Link(L("查看友盟隐私政策"), destination: URL(string:"https://www.umeng.com/page/policy")!)
                paragraph(L("访问与删除"), L("备份钥匙保存在设备钥匙串中。你可以导出并自行保管，也可以通过“删除全部纪念资料”删除当前本机与云端的业务数据。服务器运维备份的清理规则应在正式上线隐私政策中进一步明确。"))
                paragraph(L("陪伴的边界"), L("场景小动物是预制纪念形象。花、灯和动作仅用于表达怀念，不代表真实生命或超自然能力。本版本不提供 AI 对话、医疗服务、付费项目或公共聊天功能。"))
                paragraph(L("运营与联系"), L("本应用由深圳市春江月明科技有限公司运营。联系邮箱：bryant_liu24@126.com。完整数据处理规则请在“我的 → 隐私政策”查看；账号注销及数据权益请求可通过该邮箱联系。"))
            }.padding(24)
        }.background(Palette.cream).navigationTitle(L("隐私与使用说明")).navigationBarTitleDisplayMode(.inline)
    }
    private func paragraph(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(text).font(.subheadline).lineSpacing(6).foregroundStyle(Palette.muted) }
    }
}
