import SwiftUI

struct TributeVisit: Decodable, Identifiable {
    let kind: String
    let time: Double
    let visitor: String
    var id: String { "\(time)-\(kind)-\(visitor)" }
}
struct TributeSummary: Decodable {
    var flowers: Int = 0
    var candles: Int = 0
    var sent: [String] = []
    var favorite = false
    var visits: [TributeVisit] = []
}
@MainActor final class CommunityStore: ObservableObject {
    @Published var summary = TributeSummary()
    @Published var favorites = Set<String>()
    @Published var busy = false
    @Published var loaded = false
    @Published var error: String?
    @Published var notice: String?
    func load(_ id: String) async {
        guard !busy else { return }; busy=true; defer { busy=false }
        do { summary=try JSONDecoder().decode(TributeSummary.self,from:await ParkClient.request("GET",path:"community/\(id)")); loaded=true;error=nil }
        catch { self.error=error.localizedDescription }
    }
    func loadFavorites() async {
        do {
            struct Favorites:Decodable { let favorites:[String] }
            favorites=Set(try JSONDecoder().decode(Favorites.self,from:await ParkClient.request("GET",path:"community")).favorites);error=nil
        } catch { self.error=error.localizedDescription }
    }
    func send(_ action: String, id: String) async -> Bool {
        guard !busy else { return false };busy=true;defer { busy=false }
        do {
            _=try await ParkClient.request("POST",path:"community/\(id)/\(action)")
            summary=try JSONDecoder().decode(TributeSummary.self,from:await ParkClient.request("GET",path:"community/\(id)"));loaded=true;error=nil
            if action=="flower" { notice=L("一束花，替你说想念。") }
            if action=="candle" { notice=L("一盏灯，温暖这份记忆。") }
            UIImpactFeedbackGenerator(style:.soft).impactOccurred()
            return true
        }catch { self.error=error.localizedDescription;return false }
    }
}

struct ParkDirectoryView: View {
    @ObservedObject var park: ParkStore
    @StateObject private var community=CommunityStore()
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var filter=0
    @State private var showSlots=false
    let travel:(Int)->Void
    private var results:[PublicMonument] {
        park.plots.filter { p in
            (filter != 1 || community.favorites.contains(p.publicId ?? "")) && (filter != 2 || p.isMine) &&
            (query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || p.name.localizedCaseInsensitiveContains(query.trimmingCharacters(in:.whitespacesAndNewlines)) || "\(p.index+1)" == query.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"号",with:""))
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    VStack(alignment:.leading,spacing:8) {
                        Text(L("每一份想念，都有归处")).font(.system(size:25,weight:.medium,design:.serif))
                        Text(L("寻找一位伙伴，或回到你最牵挂的地方。")).font(.subheadline).foregroundStyle(Palette.muted)
                    }.padding(.top,8)
                    Picker(L("筛选"),selection:$filter) { Text(L("全部伙伴")).tag(0);Text(L("我的收藏")).tag(1);Text(L("我的碑位")).tag(2) }.pickerStyle(.segmented)
                    if park.busy { ProgressView().frame(maxWidth:.infinity) }
                    if let error=park.error ?? community.error { Text(error).font(.footnote).foregroundStyle(.red);Button(L("重新加载")) { Task { await park.refresh();await community.loadFavorites() } } }
                    if !showSlots && results.isEmpty && !park.busy {
                        EmptyMemoryView(symbol:filter == 1 ? "heart" : "leaf",title:query.isEmpty ? L("这里还没有伙伴") : L("没有找到这位伙伴"),detail:filter == 1 ? L("在纪念碑详情中轻触爱心，\n下次就能很快找到它。") : L("试试其他名字或碑号，也可以先认领一座纪念碑。"))
                    }
                    if !showSlots { ForEach(results) { p in
                        HStack(spacing:14) {
                            Group { if let photo=p.memoryPhoto { PhotoImage(photo:photo) } else { Image(systemName:"pawprint.fill").font(.title).foregroundStyle(Palette.green) } }.frame(width:65,height:72).background(Palette.cream,in:RoundedRectangle(cornerRadius:14)).clipShape(RoundedRectangle(cornerRadius:14))
                            VStack(alignment:.leading,spacing:6) {
                                Text(p.name).font(.headline).lineLimit(1)
                                Text(String(format:L("%02d 号纪念碑"),p.index+1)+(p.isMine ? L(" · 我的伙伴") : "")).font(.caption).foregroundStyle(Palette.muted)
                                HStack(spacing:10) { Label("\(p.flowers ?? 0)",systemImage:"camera.macro");Label("\(p.candles ?? 0)",systemImage:"flame") }.font(.caption2).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength:0)
                            Button { dismiss();travel(p.index) } label: { Image(systemName:"arrow.up.right").font(.headline).frame(width:44,height:44).background(Palette.green.opacity(0.1),in:Circle()) }.accessibilityLabel(L("前往{0}的纪念碑", p.name))
                        }.padding(16).background(.white,in:RoundedRectangle(cornerRadius:22))
                    }
                    }
                    if showSlots {
                        Text(L("园区地图")).font(.headline).padding(.top,8)
                        Text(L("浅色为空位，爱心表示已有伙伴。轻触即可前往。")).font(.caption).foregroundStyle(Palette.muted)
                        LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:6),spacing:10) {
                            ForEach(0..<ParkLayout.count,id:\.self) { index in
                                Button { dismiss();travel(index) } label: {
                                    VStack(spacing:6) { Image(systemName:park.plots.contains{$0.index==index} ? "heart.fill":"leaf");Text("\(index+1)").font(.caption) }.frame(maxWidth:.infinity).padding(.vertical,12).background(park.mine?.index==index ? Palette.green.opacity(0.18):.white,in:RoundedRectangle(cornerRadius:12))
                                }.accessibilityLabel(L("前往{0}号纪念碑", index+1))
                            }
                        }
                    }
                }.padding(20)
            }.background(Palette.cream).foregroundStyle(Palette.ink)
                .searchable(text:$query,prompt:L("搜索名字或碑号"))
                .onChange(of:query) { _,value in if !value.isEmpty { showSlots=false } }
                .onChange(of:filter) { _,_ in showSlots=false }
                .navigationTitle(L("寻找伙伴")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarLeading) { Button { showSlots.toggle();query="" } label: { Label(showSlots ? L("伙伴列表"):L("碑位地图"),systemImage:showSlots ? "list.bullet":"square.grid.3x3") } };ToolbarItem(placement:.confirmationAction) { Button(L("完成")) { dismiss() } } }
                .refreshable { await park.refresh();await community.loadFavorites() }
                .task { await community.loadFavorites() }
        }.tint(Palette.green)
    }
}

struct MonumentCommunityView: View {
    let monument:PublicMonument
    let onUpdate:()->Void
    @StateObject private var community=CommunityStore()
    @State private var share=false
    @State private var pulse=false
    var body: some View {
        if let id=monument.publicId {
            VStack(spacing:18) {
                HStack {
                    VStack(alignment:.leading,spacing:5) {
                        Text(L("被温柔记挂着")).font(.headline)
                        Text(L("{0} 束花  ·  {1} 盏灯", community.loaded ? community.summary.flowers : monument.flowers ?? 0, community.loaded ? community.summary.candles : monument.candles ?? 0)).font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button { Task { if await community.send(community.summary.favorite ? "unfavorite":"favorite",id:id) { onUpdate() } } } label: {
                        Image(systemName:community.summary.favorite ? "heart.fill":"heart").font(.title3).foregroundStyle(community.summary.favorite ? Color.pink:Palette.green).frame(width:44,height:44).background(Palette.cream,in:Circle())
                    }.disabled(!community.loaded || community.busy).accessibilityLabel(community.summary.favorite ? L("取消收藏"):L("收藏伙伴")).accessibilityIdentifier("communityFavorite")
                }
                HStack(spacing:12) {
                    tribute("flower","camera.macro",L("献一束花"),id)
                    tribute("candle","flame",L("点一盏灯"),id)
                }
                if let notice=community.notice { Label(notice,systemImage:"heart.fill").font(.subheadline).foregroundStyle(Palette.green).transition(.opacity.combined(with:.scale)) }
                Text(L("每位访客每天可献花、点灯各一次（北京时间）。")).font(.caption2).foregroundStyle(Palette.muted)
                Button { share=true } label: { Label(L("分享这份想念"),systemImage:"square.and.arrow.up").frame(maxWidth:.infinity).padding(13).background(Palette.cream,in:Capsule()) }
                if monument.isMine {
                    Divider()
                    HStack { Label(L("来访的温暖"),systemImage:"sparkles").font(.headline);Spacer();Text(L("最近 50 条")).font(.caption).foregroundStyle(Palette.muted) }
                    if community.summary.visits.isEmpty { Text(L("有人来送上祝福时，会在这里留下记录。")).font(.subheadline).foregroundStyle(Palette.muted).frame(maxWidth:.infinity,alignment:.leading) }
                    ForEach(Array(community.summary.visits.enumerated()),id:\.offset) { _,visit in
                        HStack(spacing:12) {
                            Image(systemName:visit.kind=="flower" ? "camera.macro":"flame.fill").foregroundStyle(visit.kind=="flower" ? Palette.green:Color.orange).frame(width:36,height:36).background(Palette.cream,in:Circle())
                            VStack(alignment:.leading,spacing:4) { Text(L(visit.visitor)).font(.subheadline);Text(visit.kind=="flower" ? L("送来一束花"):L("点亮了一盏灯")).font(.caption).foregroundStyle(Palette.muted) }
                            Spacer();Text(Date(timeIntervalSince1970:visit.time/1000),format:.dateTime.month().day().hour().minute()).font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                }
                if community.busy { ProgressView() }
                if let error=community.error { Text(error).foregroundStyle(.red).font(.footnote);Button(L("重新加载祝福")) { Task { await community.load(id) } } }
            }.padding(20).background(.white,in:RoundedRectangle(cornerRadius:24))
                .task(id:id) { await community.load(id) }
                .sheet(isPresented:$share) { MemorialShareView(monument:monument) }
        } else { Text(L("请刷新园区后分享和互动。")).font(.footnote).foregroundStyle(Palette.muted) }
    }
    private func tribute(_ kind:String,_ symbol:String,_ title:String,_ id:String)->some View {
        let sent=community.summary.sent.contains(kind)
        return Button {
            Task { if await community.send(kind,id:id) { withAnimation(.spring(response:0.3)) { pulse.toggle() };onUpdate() } }
        } label: {
            VStack(spacing:8) { Image(systemName:sent ? "checkmark.circle.fill":symbol).font(.title2).symbolEffect(.bounce,value:pulse);Text(sent ? L("今日已送出"):title).font(.subheadline.weight(.medium)) }
                .frame(maxWidth:.infinity).padding(.vertical,18).foregroundStyle(kind=="flower" ? Palette.green:Color(red:0.65,green:0.42,blue:0.17)).background(kind=="flower" ? Palette.green.opacity(0.09):Color.orange.opacity(0.09),in:RoundedRectangle(cornerRadius:18))
        }.disabled(sent || community.busy || !community.loaded).accessibilityIdentifier("tribute-\(kind)")
    }
}

struct MemorialShareCard:View {
    let monument:PublicMonument
    var body:some View {
        VStack(spacing:20) {
            Text("PAWS & MEMORIES").font(.system(size:10,weight:.semibold,design:.rounded)).tracking(4).foregroundStyle(Palette.muted)
            Group {
                if let photo=monument.memoryPhoto { PhotoImage(photo:photo) }
                else { Image(systemName:"pawprint.fill").font(.system(size:70)).foregroundStyle(Palette.green) }
            }.frame(width:260,height:240).background(.white,in:RoundedRectangle(cornerRadius:24)).clipShape(RoundedRectangle(cornerRadius:24))
            Text(monument.name).font(.system(size:30,weight:.medium,design:.serif)).multilineTextAlignment(.center)
            Text(monument.story.isEmpty ? L("爱不会因为告别而消失。"):monument.story).font(.system(size:16,design:.serif)).lineSpacing(6).multilineTextAlignment(.center).lineLimit(6)
            HStack { Image(systemName:"leaf");Text(L("爪印花园 · 留一处温柔的想念")) }.font(.caption).foregroundStyle(Palette.muted)
        }.padding(28).frame(width:340).background(Palette.cream).foregroundStyle(Palette.ink)
    }
}
struct MemorialShareView:View {
    let monument:PublicMonument
    @Environment(\.dismiss) private var dismiss
    @State private var items:[Any]=[]
    @State private var sharing=false
    @State private var error:String?
    private var url:URL? { monument.publicId.flatMap { URL(string:"https://www.cjym123.cn:8066/api/petmemorial/public/\($0)") } }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:20) {
                    MemorialShareCard(monument:monument).clipShape(RoundedRectangle(cornerRadius:26)).shadow(color:Palette.green.opacity(0.1),radius:15,y:8)
                    Button {
                        let renderer=ImageRenderer(content:MemorialShareCard(monument:monument));renderer.scale=3
                        guard let image=renderer.uiImage,let url else { error=L("分享卡生成失败，请重试");return }
                        items=[image,url];sharing=true
                    } label:{ Label(L("分享纪念卡与链接"),systemImage:"square.and.arrow.up") }.buttonStyle(PillButton())
                    if let url { ShareLink(item:url) { Label(L("仅分享访问链接"),systemImage:"link") } }
                    Text(L("链接可在浏览器打开，亲友无需安装 App。\n只包含已公开资料，信件和私密相册不会分享。")).font(.caption).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }.background(Palette.cream).navigationTitle(L("分享想念")).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(L("完成")) { dismiss() }.accessibilityIdentifier("shareDone") }
                .sheet(isPresented:$sharing) { ActivitySheet(items:items) }
        }.tint(Palette.green)
    }
}
struct ActivitySheet:UIViewControllerRepresentable {
    let items:[Any]
    func makeUIViewController(context:Context)->UIActivityViewController { UIActivityViewController(activityItems:items,applicationActivities:nil) }
    func updateUIViewController(_ controller:UIActivityViewController,context:Context) {}
}
