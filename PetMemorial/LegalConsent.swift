import SwiftUI
import WebKit

enum LegalPolicy {
    static let version = "2026-11-24"
    static let key = "legalConsentVersion"
    enum Document: String, Identifiable {
        case agreement, privacy
        var id: String { rawValue }
        var title: String { self == .agreement ? L("用户协议") : L("隐私政策") }
        var url: URL { URL(string:"https://www.cjym123.cn/docs/petmemorial/\(rawValue).html")! }
    }
}

struct LegalGateView: View {
    @AppStorage(LegalPolicy.key) private var acceptedVersion = ""
    @State private var preview = false
    @State private var document: LegalPolicy.Document?
    var body: some View {
        Group {
            if acceptedVersion == LegalPolicy.version { AcceptedGardenView() }
            else {
                ZStack {
                    Palette.cream.ignoresSafeArea()
                    if preview {
                        VStack(spacing:20) {
                            Text(L("先在花园坐一会儿")).font(.title2.bold())
                            GardenSceneView(garden:nil,onTap:{ _ in }).frame(maxHeight:380).clipShape(RoundedRectangle(cornerRadius:28))
                            Text(L("当前为离线基础预览，不读取账号或云端资料，也不开启统计。完整功能需先阅读并同意协议。"))
                                .font(.subheadline).foregroundStyle(Palette.muted)
                            Button(L("重新阅读协议")) { preview=false }.buttonStyle(PillButton())
                        }.padding(24)
                    } else {
                        GeometryReader { geometry in
                            ZStack {
                                LinearGradient(colors:[Palette.cream,Color(red:0.78,green:0.85,blue:0.72)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
                                VStack {
                                    Image(systemName:"leaf.fill").font(.system(size:150)).rotationEffect(.degrees(-25)).offset(x:-100,y:40)
                                    Spacer()
                                    Image(systemName:"leaf.fill").font(.system(size:210)).rotationEffect(.degrees(30)).offset(x:110,y:60)
                                }.foregroundStyle(Palette.green.opacity(0.12)).accessibilityHidden(true)
                                Color.black.opacity(0.22).ignoresSafeArea()
                                VStack(spacing:18) {
                                    VStack(spacing:10) {
                                        Image(systemName:"pawprint.fill").font(.system(size:32)).foregroundStyle(Palette.green)
                                            .frame(width:62,height:62).background(Palette.green.opacity(0.08),in:RoundedRectangle(cornerRadius:20))
                                        Text(L("用户协议与隐私保护")).font(.title3.bold()).foregroundStyle(Palette.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                                        Text(L("欢迎来到宠物纪念馆")).font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                                    }
                                    ScrollView {
                                        VStack(alignment:.leading,spacing:14) {
                                            Text(L("请先阅读以下协议，了解我们如何保存资料、保护隐私，以及你享有的选择权。"))
                                            Text(L("照片和信件默认保存在本机；云备份、公开纪念碑与通知按需确认。使用统计默认关闭，可在“我的”中自主开启。"))
                                            Text(L("点击“同意并进入”表示你已阅读并同意以上协议。"))
                                                .font(.footnote).foregroundStyle(Palette.muted)
                                        }.font(.subheadline).lineSpacing(5).frame(maxWidth:.infinity,alignment:.leading).padding(16)
                                    }.frame(maxHeight:230).background(Palette.cream,in:RoundedRectangle(cornerRadius:18))
                                    VStack(spacing:10) {
                                        Button(L("《用户协议》")) { document = .agreement }.accessibilityIdentifier("legalAgreement")
                                        Button(L("《隐私政策》")) { document = .privacy }.accessibilityIdentifier("legalPrivacy")
                                    }.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                                    VStack(spacing:10) {
                                        Button(L("同意并进入")) { acceptedVersion=LegalPolicy.version }.buttonStyle(PillButton()).accessibilityIdentifier("legalAccept")
                                        Button(L("暂不同意，基础浏览")) { preview=true }.buttonStyle(PillButton(filled:false))
                                    }
                                    Text(L("深圳市春江月明科技有限公司")).font(.caption2).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                                }
                                .padding(24)
                                .frame(maxWidth:360)
                                .frame(maxHeight:min(640,geometry.size.height-32))
                                .background(.white,in:RoundedRectangle(cornerRadius:28))
                                .shadow(color:.black.opacity(0.14),radius:24,y:10)
                                .padding(.horizontal,24)
                            }.frame(maxWidth:.infinity,maxHeight:.infinity)
                        }
                    }
                }
            }
        }
        .sheet(item:$document) { item in
            NavigationStack {
                LegalDocumentView(document:item)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button(L("完成")) { document=nil } } }
            }
        }
    }
}

/// Account and business stores are created only after general privacy consent.
private struct AcceptedGardenView: View {
    @StateObject private var store=GardenStore()
    @StateObject private var account=AccountStore()
    var body: some View { RootView().environmentObject(store).environmentObject(account) }
}

struct LegalDocumentView: View {
    let document: LegalPolicy.Document
    var body: some View {
        VStack(spacing:0) {
            LegalHTMLView(document:document)
            Link(L("查看线上版本"),destination:document.url).font(.footnote).padding(12)
        }.background(Palette.cream).navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
    }
}
private struct LegalHTMLView: UIViewRepresentable {
    let document: LegalPolicy.Document
    func makeUIView(context:Context)->WKWebView {
        let configuration=WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view=WKWebView(frame:.zero,configuration:configuration)
        if let url=Bundle.main.url(forResource:document.rawValue,withExtension:"html",subdirectory:"Legal") {
            view.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
        } else {
            view.loadHTMLString("<meta name='viewport' content='width=device-width'><p>" + L("协议文本暂不可用，请通过下方入口查看线上版本。") + "</p>",baseURL:nil)
        }
        return view
    }
    func updateUIView(_ view:WKWebView,context:Context) {}
}
