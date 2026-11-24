import SwiftUI
import UserNotifications

@MainActor enum MemorialReminders {
    private static var generation=0
    private static var latestGarden:MemorialGarden?
    private static var latestAccount:String?
    static func preferenceKey(_ garden:MemorialGarden, account:String?)->String { "memorial.reminders.\(account ?? "guest").\(garden.id)" }
    static func enabled(_ garden:MemorialGarden, account:String?)->Bool { UserDefaults.standard.bool(forKey:preferenceKey(garden,account:account)) }
    static func components(_ date:Date, calendar:Calendar = .current)->DateComponents {
        var c=calendar.dateComponents([.month,.day],from:date)
        // Annual February 29 reminders are intentionally observed on February 28.
        if c.month==2 && c.day==29 { c.day=28 };c.hour=9;c.minute=0;return c
    }
    static func next(_ date:Date, now:Date=Date(), calendar:Calendar = .current)->Date? {
        calendar.nextDate(after:now,matching:components(date,calendar:calendar),matchingPolicy:.nextTime)
    }
    @discardableResult static func sync(_ garden:MemorialGarden?,account:String?) async -> String? {
        latestGarden=garden;latestAccount=account
        generation+=1;let version=generation
        let center=UNUserNotificationCenter.current()
        let pending=await center.pendingNotificationRequests()
        let delivered=await center.deliveredNotifications()
        guard version==generation else { return nil }
        center.removePendingNotificationRequests(withIdentifiers:pending.filter{$0.identifier.hasPrefix("petmemorial.")}.map(\.identifier))
        center.removeDeliveredNotifications(withIdentifiers:delivered.map(\.request.identifier).filter{$0.hasPrefix("petmemorial.")})
        guard let garden,enabled(garden,account:account) else { return nil }
        let settings=await center.notificationSettings()
        guard version==generation,settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return nil }
        for (kind,date) in [("birthday",garden.birthday),("memorial",garden.memorialDate)] {
            guard let date,version==generation else { continue }
            let content=UNMutableNotificationContent()
            content.title=L("今天，留一点时间给想念")
            content.body=kind=="birthday" ? L("今天是{0}的生日，去花园陪它一会儿吧。", garden.name):L("今天是纪念{0}的日子，一束花、一封信，都是陪伴。", garden.name)
            content.sound = .default
            let request=UNNotificationRequest(identifier:"petmemorial.\(kind)",content:content,trigger:UNCalendarNotificationTrigger(dateMatching:components(date),repeats:true))
            do { try await center.add(request) }
            catch {
                if version==generation { center.removePendingNotificationRequests(withIdentifiers:["petmemorial.birthday","petmemorial.memorial"]);return L("提醒未能保存，请稍后重试。") }
            }
        }
        if version != generation { return await sync(latestGarden,account:latestAccount) }
        return nil
    }

}
struct MemorialDatesView:View {
    @EnvironmentObject private var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var enabled=false
    @State private var working=false
    @State private var denied=false
    @State private var error:String?
    @State private var edit=false
    private var account:String? { store.state.accountId }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    Image(systemName:"sun.max").font(.system(size:42,weight:.light)).foregroundStyle(Color(red:0.73,green:0.56,blue:0.28)).padding(22).background(.white,in:Circle()).frame(maxWidth:.infinity)
                    Text(L("值得记住的日子")).font(.system(size:28,weight:.medium,design:.serif)).frame(maxWidth:.infinity)
                    Text(L("日子向前，爱留在心里。\n在特别的一天，给想念留一点时间。")).font(.subheadline).lineSpacing(5).multilineTextAlignment(.center).foregroundStyle(Palette.muted).frame(maxWidth:.infinity)
                    if let garden=store.garden {
                        if let date=garden.birthday { dateCard(L("它的生日"),symbol:"gift",date:date) }
                        if let date=garden.memorialDate { dateCard(L("我们的纪念日"),symbol:"leaf",date:date) }
                        if garden.birthday==nil && garden.memorialDate==nil { EmptyMemoryView(symbol:"calendar",title:L("为想念留一个日期"),detail:L("添加生日或告别日期，\n让特别的日子被温柔记住。")) }
                        Button { edit=true } label:{ Label(L("编辑纪念日期"),systemImage:"calendar.badge.plus") }.buttonStyle(PillButton(filled:false))
                        VStack(alignment:.leading,spacing:12) {
                            Toggle(isOn:Binding(get:{enabled},set:{value in Task { await change(value,garden:garden) }})) { Label(L("纪念日提醒"),systemImage:"bell.badge") }.disabled(working || (garden.birthday==nil && garden.memorialDate==nil))
                            Text(L("每年当天上午 9:00，按手机当地时间提醒。只在本机设置，默认关闭；退出账号后会停止该账号的提醒。")).font(.caption).lineSpacing(4).foregroundStyle(Palette.muted)
                            Text(L("2 月 29 日按每年 2 月 28 日提醒。")).font(.caption2).foregroundStyle(Palette.muted)
                            if denied { Button(L("到系统设置开启通知")) { if let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
                            if working { ProgressView() }
                            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                        }.padding(20).background(.white,in:RoundedRectangle(cornerRadius:22))
                    }
                }.padding(24)
            }.background(Palette.cream).foregroundStyle(Palette.ink).navigationTitle(L("纪念日")).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(L("完成")) { dismiss() } }
                .sheet(isPresented:$edit) { GardenEditor(garden:store.garden) }
                .task { if let garden=store.garden { enabled=MemorialReminders.enabled(garden,account:account) };denied=await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied }
        }.tint(Palette.green)
    }
    private func dateCard(_ title:String,symbol:String,date:Date)->some View {
        let c=MemorialReminders.components(date)
        let today=Calendar.current.dateComponents([.month,.day],from:Date())
        let days=(c.month==today.month && c.day==today.day) ? 0 : MemorialReminders.next(date).map { max(0,Calendar.current.dateComponents([.day],from:Calendar.current.startOfDay(for:Date()),to:Calendar.current.startOfDay(for:$0)).day ?? 0) } ?? 0
        return HStack(spacing:16) {
            Image(systemName:symbol).font(.title2).foregroundStyle(Palette.green).frame(width:52,height:52).background(Palette.cream,in:Circle())
            VStack(alignment:.leading,spacing:6) { Text(title).font(.headline);Text(date,format:.dateTime.month().day()).font(.subheadline).foregroundStyle(Palette.muted) }
            Spacer();VStack(spacing:4) { Text(days==0 ? L("今天"):"\(days)").font(.system(size:27,weight:.medium,design:.serif));if days>0 { Text(L("天后")).font(.caption).foregroundStyle(Palette.muted) } }
        }.padding(20).background(.white,in:RoundedRectangle(cornerRadius:22))
    }
    private func change(_ value:Bool,garden:MemorialGarden) async {
        working=true;defer { working=false };error=nil
        if value {
            do { guard try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge]) else { denied=true;error=L("通知尚未允许，可以在系统设置中开启。");return } }
            catch { self.error=error.localizedDescription;return }
        }
        enabled=value;denied=false;UserDefaults.standard.set(value,forKey:MemorialReminders.preferenceKey(garden,account:account))
        if let failure=await MemorialReminders.sync(garden,account:account) { error=failure;enabled=false;UserDefaults.standard.set(false,forKey:MemorialReminders.preferenceKey(garden,account:account)) }
    }
}
