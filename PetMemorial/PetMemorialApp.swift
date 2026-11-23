import SwiftUI

@main
struct PetMemorialApp: App {
    @StateObject private var store = GardenStore()
    @StateObject private var account = AccountStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).environmentObject(account).preferredColorScheme(.light) }
    }
}
enum Palette {
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let ink = Color(red: 0.20, green: 0.27, blue: 0.23)
    static let green = Color(red: 0.30, green: 0.43, blue: 0.34)
    static let muted = Color(red: 0.49, green: 0.53, blue: 0.48)
}
struct PillButton: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .foregroundStyle(filled ? .white : Palette.ink)
            .background(filled ? Palette.green : Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
struct RootView: View {
    @EnvironmentObject private var store: GardenStore
    @State private var tab = 0
    @Environment(\.scenePhase) private var scenePhase
    private var reminderIdentity:String { "\(store.state.accountId ?? "guest")|\(store.garden?.id ?? "")|\(store.garden?.name ?? "")|\(store.garden?.birthday?.timeIntervalSince1970 ?? 0)|\(store.garden?.memorialDate?.timeIntervalSince1970 ?? 0)" }
    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("花园", systemImage: "leaf") }.tag(0)
            PhotosView().tabItem { Label("相册", systemImage: "photo.on.rectangle.angled") }.tag(1)
            LettersView().tabItem { Label("信箱", systemImage: "envelope") }.tag(2)
            SettingsView().tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(3)
        }
        .tint(Palette.green)
        .task(id:reminderIdentity) { await MemorialReminders.sync(store.garden,account:store.state.accountId) }
        .onChange(of:scenePhase) { _,phase in if phase == .active { Task { await MemorialReminders.sync(store.garden,account:store.state.accountId) } } }
        .task { if store.state.cloudEnabled { await store.backup() } }
        .alert("温馨提示", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .overlay(alignment: .top) {
            if let notice = store.notice {
                Text(notice).font(.subheadline).padding(14).background(.regularMaterial, in: Capsule()).padding(.horizontal).padding(.top, 8)
                    .allowsHitTesting(false)
                    .task(id: notice) { try? await Task.sleep(for: .seconds(2.5)); if store.notice == notice { store.notice = nil } }
            }
        }
    }
}
struct HomeView: View {
    @EnvironmentObject private var store: GardenStore
    @State private var edit = false
    @State private var immersive = false
    @State private var dates = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PAWS & MEMORIES").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(3).foregroundStyle(Palette.muted)
                                Text(store.garden.map { "\($0.name)的花园" } ?? "让想念，有处安放")
                                    .font(.system(size: 29, weight: .medium, design: .serif)).foregroundStyle(Palette.ink)
                            }
                            Spacer()
                            Button { edit = true } label: { Image(systemName: store.garden == nil ? "plus" : "slider.horizontal.3").font(.title3).frame(width: 44, height: 44).background(.white, in: Circle()) }.accessibilityLabel("编辑纪念资料")
                        }
                        ZStack(alignment: .bottomLeading) {
                            Group {
                                if immersive { Palette.cream }
                                else { GardenSceneView(garden: store.garden, onTap: interact) }
                            }.frame(height: min(geometry.size.width * 1.12, 470))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.garden == nil ? "一方小天地，一份长久的陪伴" : "风会记得，你来过这里。")
                                    .font(.system(size: 17, weight: .medium, design: .serif))
                                Text("拖动看看四周 · 走进小镇探索更多")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.ultraThinMaterial)
                        }.clipShape(RoundedRectangle(cornerRadius: 30))
                        if let garden = store.garden {
                            HStack(spacing: 0) {
                                stat("\(garden.daysTogetherInMemory)", "想念的日子")
                                Divider().frame(height: 30)
                                stat("\(garden.photos.count)", "珍藏照片")
                                Divider().frame(height: 30)
                                stat("\(garden.letters.count)", "写给你的信")
                            }.padding(.vertical, 10)
                            Button { immersive = true } label: { Label("走进爪印小镇，陪你一会儿", systemImage: "sparkles") }.buttonStyle(PillButton())
                            Button { dates=true } label: { HStack(spacing:14) { Image(systemName:"calendar.badge.clock").font(.title2);VStack(alignment:.leading,spacing:5) { Text("值得记住的日子").font(.headline);Text("生日、纪念日，让想念如约而至").font(.caption).foregroundStyle(Palette.muted) };Spacer();Image(systemName:"chevron.right").font(.caption) }.padding(20).background(.white,in:RoundedRectangle(cornerRadius:22)) }
                            if !garden.story.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("我们的故事", systemImage: "heart").font(.subheadline.weight(.semibold))
                                    Text(garden.story).font(.subheadline).lineSpacing(5).foregroundStyle(Palette.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
                            }
                            HStack(spacing: 12) {
                                Button { store.offerFlower() } label: { Label("献一束花", systemImage: "camera.macro") }.buttonStyle(PillButton(filled: false))
                                Button { store.lightCandle() } label: { Label("点一盏灯", systemImage: "flame") }.buttonStyle(PillButton(filled: false))
                            }
                        } else {
                            Text("把照片、故事和没说完的话，\n放进只属于你们的纪念花园。")
                                .font(.subheadline).lineSpacing(6).foregroundStyle(Palette.muted)
                            Button { edit = true } label: { Label("创建我的纪念花园", systemImage: "plus") }.buttonStyle(PillButton())
                            Button { immersive=true } label: { Label("先逛逛纪念园",systemImage:"leaf") }.buttonStyle(PillButton(filled:false))
                            Text("默认私密 · 本机保存 · 云备份由你选择").font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
                        }
                    }.padding(22).padding(.bottom, 12)
                }.background(Palette.cream)
            }.toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $edit) { GardenEditor(garden: store.garden) }
                .fullScreenCover(isPresented: $immersive) { ImmersiveGarden() }
                .sheet(isPresented:$dates) { MemorialDatesView() }
        }
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) { Text(value).font(.system(size: 25, weight: .medium, design: .serif)); Text(label).font(.caption).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity)
    }
    private func interact(_ target: String) { store.notice = target == "pet" ? "轻轻摸摸你，就像从前一样。" : "照片里的你，一直都在。" }
}
struct GardenEditor: View {
    @EnvironmentObject private var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    let original: MemorialGarden?
    @State private var name: String
    @State private var species: String
    @State private var story: String
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var hasMemorial: Bool
    @State private var memorialDate: Date
    init(garden: MemorialGarden?) {
        original = garden
        _name = State(initialValue: garden?.name ?? "")
        _species = State(initialValue: garden?.species ?? "cat")
        _story = State(initialValue: garden?.story ?? "")
        _hasBirthday = State(initialValue: garden?.birthday != nil)
        _birthday = State(initialValue: garden?.birthday ?? Date())
        _hasMemorial = State(initialValue: garden?.memorialDate != nil)
        _memorialDate = State(initialValue: garden?.memorialDate ?? Date())
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("记住你的名字") {
                    TextField("宠物名字（最多 30 字）", text: $name).onChange(of: name) { _, value in name = String(value.prefix(30)) }
                    Picker("伙伴", selection: $species) { Text("猫咪").tag("cat"); Text("狗狗").tag("dog") }.pickerStyle(.segmented)
                }
                Section("值得记住的日子") {
                    Toggle("记录生日", isOn: $hasBirthday)
                    if hasBirthday { DatePicker("生日", selection: $birthday, in: ...Date(), displayedComponents: .date) }
                    Toggle("记录告别日期", isOn: $hasMemorial)
                    if hasMemorial { DatePicker("告别日期", selection: $memorialDate, in: ...Date(), displayedComponents: .date) }
                }
                Section { TextEditor(text: $story).frame(minHeight: 120).onChange(of: story) { _, value in story = String(value.prefix(500)) } } header: { Text("我们的故事") } footer: { Text("\(story.count)/500 · 可以写下它的小习惯、喜欢的食物，或最想记住的瞬间。") }
                Section { Text("资料和照片默认仅保存在本机。开启云备份前，会再次征求你的同意。此处的小动物是纪念形象，不是由照片重建的真实宠物。") .font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle(original == nil ? "创建纪念花园" : "纪念资料").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }.tint(Palette.green)
    }
    private func save() {
        if hasBirthday && hasMemorial && birthday > memorialDate { store.error = "生日不能晚于告别日期。"; return }
        var garden = original ?? MemorialGarden(name: "", species: species, story: "")
        garden.name = name.trimmingCharacters(in: .whitespacesAndNewlines); garden.species = species; garden.story = story
        garden.birthday = hasBirthday ? birthday : nil; garden.memorialDate = hasMemorial ? memorialDate : nil
        store.setGarden(garden); dismiss()
    }
}
struct ImmersiveGarden: View {
    @EnvironmentObject private var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controls = ParkControls()
    @StateObject private var park = ParkStore()
    @State private var showMap = false
    var body: some View {
        ZStack {
            MemorialParkScene(controls: controls, garden: store.garden, plots: park.plots).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width:44,height:44).background(.regularMaterial,in:Circle()) }.accessibilityLabel("返回")
                    Spacer()
                    Menu {
                        Button("刷新碑位") { Task { await park.refresh() } }
                        Button("晴日") { store.update { $0.theme="sage" } }
                        Button("黄昏") { store.update { $0.theme="sunset" } }
                        Button("月夜") { store.update { $0.theme="moon" } }
                    } label: { VStack(spacing:4) {
                        Text("爪印小镇").font(.headline)
                        Text(park.loaded ? "48 个碑位 · 已认领 \(park.plots.count)" : "共享园区未连接").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal,20).padding(.vertical,10).background(.regularMaterial,in:Capsule()) }
                    Spacer()
                    Button { controls.movement = .zero; showMap = true } label: { Image(systemName:"magnifyingglass").frame(width:44,height:44).background(.regularMaterial,in:Circle()) }.accessibilityLabel("纪念碑地图")
                }
                Text(controls.petMessage ?? "摇杆行走 · 点击建筑进入 · 地图快捷传送").font(.caption2).padding(9).background(.regularMaterial,in:Capsule())
                Spacer()
                if let place=controls.nearbyPlace {
                    Button { openPlace(place) } label: {
                        Label("进入"+place.title,systemImage:place.icon).font(.headline).padding(16).background(.regularMaterial,in:Capsule())
                    }
                }
                if store.garden != nil {
                    HStack(spacing:16) {
                        Button { controls.petRequest += 1; controls.autoWalk=false;controls.movement = .zero } label: { Label("摸摸它",systemImage:"hand.draw") }
                        Divider().frame(height:24)
                        Button { controls.petSitting.toggle() } label: { Label(controls.petSitting ? "跟我走":"坐一会儿",systemImage:controls.petSitting ? "pawprint":"moon") }
                        Divider().frame(height:24)
                        Button { controls.autoWalk.toggle();controls.petSitting=false } label: { Label(controls.autoWalk ? "停一停":"一起散步",systemImage:controls.autoWalk ? "pause.fill":"leaf") }
                    }.font(.system(size:13,weight:.medium)).padding(16).background(.regularMaterial,in:Capsule())
                }
                HStack(alignment:.bottom) {
                    ParkJoystick(controls:controls)
                    Spacer()
                    VStack(spacing:12) {
                        Button {
                            controls.movement = .zero
                            let index = park.mine?.index ?? 0
                            controls.destination = ParkLayout.arrival(index)
                        } label: { Label(park.mine?.index == nil ? "前往碑区" : "我的纪念碑",systemImage:"location.fill").padding(14).background(.regularMaterial,in:Capsule()) }
                        if let near = controls.nearest {
                            Button { controls.movement = .zero; controls.selected = near } label: { Text("查看 \(near+1) 号碑").padding(14).background(Palette.green,in:Capsule()).foregroundStyle(.white) }
                        }
                    }.font(.subheadline.weight(.medium))
                }
            }.padding(20)
        }.foregroundStyle(Palette.ink)
            .sheet(isPresented:$showMap) {
                TownMapView(park:park, onPlace: { place in
                    controls.destination=place.arrival; controls.autoWalk=false
                }, onMonument: { index in controls.destination=ParkLayout.arrival(index) })

            }
            .sheet(isPresented:Binding(get:{ controls.selected != nil },set:{ if !$0 { controls.selected = nil } })) {
                if let index = controls.selected { MonumentDetail(index:index).environmentObject(park) }
            }
            .sheet(item:$controls.venue) { place in
                TownVenueView(place:place, controls:controls)
            }
            .onChange(of:controls.venue) { _, _ in syncActivity() }
            .onChange(of:scenePhase) { _, _ in syncActivity() }
            .onChange(of:controls.selected) { _, _ in syncActivity() }
            .onChange(of:showMap) { _, _ in syncActivity() }
            .onDisappear { controls.active = false; controls.movement = .zero }
            .task { await park.refresh() }
            .alert("共享园区",isPresented:Binding(get:{ park.error != nil },set:{ if !$0 { park.error=nil } })) { Button("重试") { Task { await park.refresh() } }; Button("稍后",role:.cancel) {} } message: { Text(park.error ?? "") }
    }
    private func syncActivity() {
        controls.active = scenePhase == .active && controls.selected == nil && controls.venue == nil && !showMap
        controls.movement = .zero
        if !controls.active { controls.autoWalk=false }
    }
    private func openPlace(_ place:TownPlace) {
        controls.movement = .zero;controls.autoWalk=false;controls.venue=place
    }
}

struct MonumentDetail: View {
    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var park: ParkStore
    @Environment(\.dismiss) private var dismiss
    let index: Int
    @State private var confirmClaim = false
    @State private var confirmRelease = false
    private var monument: PublicMonument? { park.plots.first { $0.index == index } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:20) {
                    Image(systemName:"pawprint.fill").font(.system(size:42)).foregroundStyle(Palette.green).padding(25).background(.white,in:Circle())
                    Text(monument?.name ?? "\(index+1) 号空碑位").font(.title2.bold())
                    if let monument {
                        if let photo = monument.memoryPhoto { PhotoImage(photo:photo).frame(height:220) }
                        Text(monument.story).frame(maxWidth:.infinity,alignment:.leading)
                        MonumentCommunityView(monument:monument) { Task { await park.refresh() } }
                        if monument.isMine {
                            Text("我的纪念碑 · 昵称、首张照片与介绍已公开").font(.caption).foregroundStyle(.secondary)
                            Button("更新公开资料") { confirmClaim=true }.disabled(store.garden == nil)
                            Button("释放这个碑位",role:.destructive) { confirmRelease=true }
                        } else { Text("一位被爱着的伙伴").foregroundStyle(.secondary) }
                    } else {
                        Text("为你的伙伴认领一个位置，每人限一座纪念碑。").multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("认领这个纪念碑") { confirmClaim=true }.buttonStyle(PillButton()).disabled(store.garden == nil || !park.loaded)
                    }
                    if park.busy { ProgressView() }
                    if let error=park.error { Text(error).foregroundStyle(.red); Button("刷新园区") { Task { await park.refresh() } } }
                    Text("共享园区仅展示主动发布的昵称、首张照片和介绍。相册其他照片及信件不公开。登录账号可跨设备识别碑位；私密资料仍需在“我的”主动开启云备份。").font(.footnote).foregroundStyle(.secondary)
                }.padding(24).disabled(park.busy)
            }.background(Palette.cream).navigationTitle("\(index+1) 号纪念碑").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("关闭") { dismiss() }.disabled(park.busy).accessibilityIdentifier("monumentClose") } }
                .confirmationDialog("将宠物昵称、首张照片和纪念介绍公开到共享园区。若已有碑位，将迁至此处；信件始终保持私密。",isPresented:$confirmClaim,titleVisibility:.visible) {
                    Button("确认公开并认领") {
                        guard let garden=store.garden else { return }
                        // Remember possible ownership even if the network loses the success response.
                        store.update { $0.plotIndex = index }
                        Task { if await park.claim(index,garden:garden) { dismiss() } }
                    }
                }
                .confirmationDialog("释放后别人可以认领。你的私密照片、信件仍保留。",isPresented:$confirmRelease,titleVisibility:.visible) {
                    Button("确认释放",role:.destructive) { Task { if await park.release() { store.update { $0.plotIndex=nil }; dismiss() } } }
                }
        }.interactiveDismissDisabled(park.busy)
    }
}

struct TownMapView: View {
    @ObservedObject var park:ParkStore
    let onPlace:(TownPlace)->Void
    let onMonument:(Int)->Void
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    Text("今天，想去哪里坐坐？").font(.title2.weight(.medium))
                    Text("轻点目的地即可抵达。建筑门前也可以进入。").font(.subheadline).foregroundStyle(Palette.muted)
                    ForEach(TownPlace.allCases) { place in
                        Button { onPlace(place);dismiss() } label: {
                            HStack(spacing:16) {
                                Image(systemName:place.icon).font(.title2).frame(width:56,height:56).background(Palette.cream,in:RoundedRectangle(cornerRadius:18))
                                VStack(alignment:.leading,spacing:6) { Text(place.title).font(.headline);Text(place.detail).font(.caption).foregroundStyle(Palette.muted) }
                                Spacer();Image(systemName:"location.fill")
                            }.padding(16).background(.white,in:RoundedRectangle(cornerRadius:24))
                        }.buttonStyle(.plain)
                    }
                    NavigationLink { ParkDirectoryView(park:park) { index in onMonument(index);dismiss() } } label: {
                        Label("共享纪念园 · 查找伙伴与碑位",systemImage:"leaf").frame(maxWidth:.infinity).padding(20).background(Palette.green,in:RoundedRectangle(cornerRadius:22)).foregroundStyle(.white)
                    }
                }.padding(20)
            }.background(Palette.cream).navigationTitle("小镇导览").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("返回小镇") { dismiss() } } }
        }.tint(Palette.green)
    }
}

struct TownVenueView: View {
    let place:TownPlace
    @ObservedObject var controls:ParkControls
    @EnvironmentObject private var store:GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var editor=false
    @State private var composer=false
    @State private var sent=false
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    ZStack {
                        LinearGradient(colors:[Palette.green.opacity(0.85),Color(red:0.64,green:0.73,blue:0.57)],startPoint:.topLeading,endPoint:.bottomTrailing)
                        VStack(spacing:18) {
                            Image(systemName:sent ? "envelope.badge.shield.half.filled":place.icon).font(.system(size:58,weight:.ultraLight)).symbolEffect(.bounce,value:sent)
                            Text(sent ? "信已放进你的私密信箱":place.title).font(.system(size:28,weight:.medium,design:.serif))
                            Text(place.detail).font(.subheadline).multilineTextAlignment(.center)
                        }.foregroundStyle(.white).padding(24)
                    }.frame(height:250).clipShape(RoundedRectangle(cornerRadius:28))
                    if place == .plaza {
                        Text("一座小镇，几种想念的方式").font(.title3.weight(.semibold))
                        ForEach(TownPlace.allCases.filter{$0 != .plaza}) { item in
                            Button { travel(item) } label: { Label(item.title+" · "+item.detail,systemImage:item.icon).frame(maxWidth:.infinity,alignment:.leading).padding(18).background(.white,in:RoundedRectangle(cornerRadius:20)) }
                        }
                        Button("前往共享纪念园") { controls.destination=ParkLayout.arrival(0);dismiss() }.buttonStyle(PillButton())
                    } else if store.garden == nil {
                        Text("先为你的伙伴创建一份纪念资料，就能在这里留下照片、写信和一起散步。").foregroundStyle(Palette.muted)
                        Button("创建纪念资料") { editor=true }.buttonStyle(PillButton())
                    } else if place == .memories {
                        Text("\(store.garden?.name ?? "伙伴")的记忆墙").font(.title3.weight(.semibold))
                        if let photo=store.garden?.photos.first { PhotoImage(photo:photo).frame(maxWidth:.infinity).frame(height:220).padding(12).background(.white,in:RoundedRectangle(cornerRadius:20)) }
                        Text(store.garden?.story.isEmpty == false ? store.garden!.story : "把它的小习惯、喜欢的食物，或最难忘的瞬间写下来。").lineSpacing(6)
                        NavigationLink { PhotosView() } label: { Label("打开相册 · 添加与浏览照片",systemImage:"photo.on.rectangle").frame(maxWidth:.infinity).padding(18).background(.white,in:RoundedRectangle(cornerRadius:20)) }
                        Button("记录我们的故事") { editor=true }.buttonStyle(PillButton())
                        NavigationLink("生日与纪念日") { MemorialDatesView() }
                    } else if place == .post {
                        Label("这里的信件仅你可见，不会进入共享园区。",systemImage:"lock.shield").font(.subheadline).foregroundStyle(Palette.muted)
                        Text("已经珍藏 \(store.garden?.letters.count ?? 0) 封信").font(.title3)
                        Button { composer=true } label: { Label("写一封信",systemImage:"square.and.pencil") }.buttonStyle(PillButton()).disabled((store.garden?.letters.count ?? 0)>=100)
                        NavigationLink { LettersView() } label: { Label("打开我的私密信箱",systemImage:"tray.full").frame(maxWidth:.infinity).padding(18).background(.white,in:RoundedRectangle(cornerRadius:20)) }
                    } else {
                        Text("不用赶路，今天只是来陪陪它。").font(.title3)
                        Button("一起沿草地散步") { controls.destination=place.arrival;controls.petSitting=false;dismiss();DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { if controls.active { controls.autoWalk=true } } }.buttonStyle(PillButton())
                        Button("玩一次追球") { controls.destination=place.arrival;controls.petSitting=false;controls.ballRequest += 1;dismiss() }.buttonStyle(PillButton(filled:false))
                        Button("坐下来，摸摸它") { controls.destination=place.arrival;controls.petSitting=true;controls.petRequest += 1;dismiss() }.buttonStyle(PillButton(filled:false))
                        Text("这是为陪伴而设计的纪念形象。").font(.caption).foregroundStyle(Palette.muted)
                    }
                }.padding(22)
            }.background(Palette.cream).navigationTitle(place.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("回到小镇") { dismiss() } } }
        }.tint(Palette.green)
            .sheet(isPresented:$editor) { GardenEditor(garden:store.garden) }
            .sheet(isPresented:$composer) { LetterComposer() }
            .onChange(of:store.garden?.letters.count) { old,new in if (new ?? 0)>(old ?? 0) { withAnimation { sent=true } } }
    }
    private func travel(_ destination:TownPlace) { controls.destination=destination.arrival;dismiss() }
}
