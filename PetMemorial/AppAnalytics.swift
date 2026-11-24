import SwiftUI
import UMCommon

protocol AnalyticsClient {
    func start()
    func setEnabled(_ enabled: Bool)
    func event(_ name: String)
}

private struct UMengClient: AnalyticsClient {
    func start() {
        UMConfigure.setLogEnabled(false)
        UMConfigure.enablePi(false)
        MobClick.setAutoPageEnabled(false)
        UMConfigure.setAnalyticsEnabled(true)
        UMConfigure.initWithAppkey("6b0500a8863270068cdcfeb0", channel: "App Store")
    }
    func setEnabled(_ enabled: Bool) { UMConfigure.setAnalyticsEnabled(enabled) }
    func event(_ name: String) { MobClick.event(name) }
}

/// Only allow fixed event names; never send pet content, credentials or account IDs.
@MainActor
final class AppAnalytics: ObservableObject {
    enum Event: String {
        case home = "view_garden", photos = "view_photos", letters = "view_letters", settings = "view_settings"
        case town = "enter_town", forest = "enter_forest", map = "open_map"
    }
    static let shared = AppAnalytics()
    static let consentKey = "analyticsConsentV1"
    @Published private(set) var decision: Bool?
    private let defaults: UserDefaults
    private let client: AnalyticsClient
    private let sdkAllowed: Bool
    private(set) var started = false

    init(defaults: UserDefaults = .standard, client: AnalyticsClient? = nil, sdkAllowed: Bool? = nil) {
        self.defaults = defaults
        self.client = client ?? UMengClient()
        self.decision = defaults.object(forKey: Self.consentKey) == nil ? nil : defaults.bool(forKey: Self.consentKey)
        #if DEBUG
        self.sdkAllowed = sdkAllowed ?? (NSClassFromString("XCTestCase") == nil && !ProcessInfo.processInfo.arguments.contains("-disableAnalyticsSDK"))
        #else
        self.sdkAllowed = sdkAllowed ?? true
        #endif
    }
    var enabled: Bool { decision == true }
    func startIfConsented() {
        guard defaults.string(forKey: LegalPolicy.key) == LegalPolicy.version, enabled, sdkAllowed, !started else { return }
        client.start()
        started = true
    }
    func decide(_ accepted: Bool) {
        decision = accepted
        defaults.set(accepted, forKey: Self.consentKey)
        if started { client.setEnabled(accepted) }
        else if accepted { startIfConsented() }
    }
    func record(_ event: Event) {
        guard defaults.string(forKey: LegalPolicy.key) == LegalPolicy.version, enabled, sdkAllowed else { return }
        startIfConsented()
        guard started else { return }
        client.event(event.rawValue)
    }
}

struct AnalyticsConsentView: View {
    @ObservedObject private var analytics = AppAnalytics.shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "leaf.circle").font(.system(size: 52)).foregroundStyle(Palette.green)
                    Text(L("一起让花园更好用")).font(.title2.bold()).foregroundStyle(Palette.ink)
                    Text(L("是否允许使用友盟统计，帮助我们了解应用活跃情况和功能使用次数？"))
                    Text(L("同意后，友盟同欣（北京）科技有限公司提供的 SDK 会处理设备标识（如 IDFV）、设备与应用版本、网络信息和使用事件。本次不接入广告追踪，不申请定位权限，也不会将宠物昵称、照片、信件或手机号提交给友盟。"))
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    NavigationLink(L("查看隐私与使用说明")) { PrivacyView() }
                    Link(L("友盟隐私政策"), destination: URL(string:"https://www.umeng.com/page/policy")!)
                    Button(L("同意开启统计")) { analytics.decide(true); dismiss() }.buttonStyle(PillButton())
                    Button(L("暂不开启，继续使用")) { analytics.decide(false); dismiss() }.buttonStyle(PillButton(filled:false))
                    Text(L("是否开启均不影响花园功能，可随时在“我的 → 使用统计”中调整。"))
                        .font(.footnote).foregroundStyle(Palette.muted)
                }.padding(24)
            }.background(Palette.cream).navigationTitle(L("使用统计")).navigationBarTitleDisplayMode(.inline)
        }.interactiveDismissDisabled()
    }
}
