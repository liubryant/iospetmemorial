import SwiftUI
import PhotosUI

struct EmptyMemoryView: View {
    var symbol: String
    var title: String
    var detail: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 42, weight: .light)).foregroundStyle(Palette.green).padding(28).background(.white, in: Circle())
            Text(title).font(.title3.weight(.medium))
            Text(detail).font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(5)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30).background(Palette.cream)
    }
}
struct PhotosView: View {
    @EnvironmentObject private var store: GardenStore
    @State private var picker: PhotosPickerItem?
    @State private var draft: Data?
    @State private var caption = ""
    @State private var isLoading = false
    @State private var selected: MemoryPhoto?
    @State private var showAdd = false
    var body: some View {
        NavigationStack {
            Group {
                if store.garden == nil { EmptyMemoryView(symbol: "photo", title: "先为它留一个位置", detail: "在花园页创建纪念资料，\n就能珍藏你们的照片。") }
                else if store.garden?.photos.isEmpty == true { EmptyMemoryView(symbol: "photo.on.rectangle.angled", title: "把最喜欢的瞬间留下", detail: "点击右上角添加照片。\n第一张照片也会出现在 3D 花园中。") }
                else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                            ForEach(store.garden?.photos ?? []) { photo in
                                Button { selected = photo } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        GeometryReader { geometry in
                                            PhotoImage(photo: photo).frame(width: geometry.size.width, height: geometry.size.height)
                                        }.frame(height: 180).background(Palette.cream).clipShape(RoundedRectangle(cornerRadius: 16))
                                        Text(photo.caption.isEmpty ? "关于你的记忆" : photo.caption).font(.subheadline).lineLimit(2).foregroundStyle(Palette.ink)
                                        Text(photo.createdAt, style: .date).font(.caption2).foregroundStyle(Palette.muted)
                                    }.padding(10).background(.white, in: RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain)
                            }
                        }.padding(18)
                    }.background(Palette.cream)
                }
            }.navigationTitle("珍藏相册")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $picker, matching: .images, photoLibrary: .shared()) {
                            if isLoading { ProgressView() } else { Image(systemName: "plus").frame(width: 44, height: 44) }
                        }.disabled(store.garden == nil || (store.garden?.photos.count ?? 0) >= 6 || isLoading).accessibilityLabel("添加照片")
                    }
                }
                .onChange(of: picker) { _, item in
                    guard let item else { return }
                    isLoading = true
                    Task {
                        defer { isLoading = false; picker = nil }
                        do {
                            guard let data = try await item.loadTransferable(type: Data.self), data.count <= 30_000_000 else { throw MemorialError(message: "照片无法读取或超过 30 MB，请换一张。") }
                            draft = data; caption = ""; showAdd = true
                        } catch { store.error = error.localizedDescription }
                    }
                }
                .sheet(isPresented: $showAdd) {
                    NavigationStack {
                        Form {
                            if let draft, let image = UIImage(data: draft) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 280) }
                            TextField("写一句照片背后的故事", text: $caption).onChange(of: caption) { _, value in caption = String(value.prefix(80)) }
                            Text("最多 6 张。照片会压缩为适合手机显示的副本，原照片不受影响。").font(.footnote).foregroundStyle(.secondary)
                        }.navigationTitle("珍藏这一刻").navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) { Button("取消") { showAdd = false; draft = nil } }
                                ToolbarItem(placement: .confirmationAction) { Button("保存") {
                                    do { if let draft { try store.addPhoto(data: draft, caption: caption) }; showAdd = false; draft = nil }
                                    catch { store.error = error.localizedDescription }
                                } }
                            }
                    }
                }
                .sheet(item: $selected) { photo in PhotoDetail(photo: photo) }
        }
    }
}
struct PhotoImage: View {
    let photo: MemoryPhoto
    var body: some View {
        if let data = Data(base64Encoded: photo.imageBase64), let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        } else { Rectangle().fill(Palette.cream).overlay(Image(systemName: "photo")) }
    }
}
struct PhotoDetail: View {
    @EnvironmentObject private var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    let photo: MemoryPhoto
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let data = Data(base64Encoded: photo.imageBase64), let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)) }
                    Text(photo.caption).font(.body).lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading)
                    Text(photo.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                }.padding(22)
            }.background(Palette.cream).navigationTitle("珍藏照片").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) { Button(role: .destructive) { confirm = true } label: { Image(systemName: "trash") }.accessibilityLabel("删除照片") }
                }
                .confirmationDialog("删除这张纪念照片？不会删除系统相册中的原图。", isPresented: $confirm, titleVisibility: .visible) {
                    Button("删除照片", role: .destructive) { store.update { $0.photos.removeAll { $0.id == photo.id } }; dismiss() }
                }
        }
    }
}
struct LettersView: View {
    @EnvironmentObject private var store: GardenStore
    @State private var compose = false
    var body: some View {
        NavigationStack {
            Group {
                if store.garden == nil { EmptyMemoryView(symbol: "envelope", title: "有些话，想慢慢对你说", detail: "先在花园页创建纪念资料，\n再写下属于你们的故事。") }
                else if store.garden?.letters.isEmpty == true { EmptyMemoryView(symbol: "envelope.open", title: "第一封信，从这里开始", detail: "今天发生了什么？又想起了哪个瞬间？\n写下来，留给心里的它。") }
                else {
                    List {
                        ForEach(store.garden?.letters ?? []) { letter in
                            NavigationLink { LetterDetail(letter: letter) } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack { Image(systemName: "envelope").foregroundStyle(Palette.green); Text(letter.createdAt, style: .date).font(.caption).foregroundStyle(Palette.muted) }
                                    Text(letter.text).font(.system(size: 17, design: .serif)).lineSpacing(5).lineLimit(4)
                                }.padding(.vertical, 12)
                            }.listRowBackground(Color.white)
                        }
                    }.scrollContentBackground(.hidden).background(Palette.cream)
                }
            }.navigationTitle("写给你的信")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { compose = true } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }.disabled(store.garden == nil || (store.garden?.letters.count ?? 0) >= 100).accessibilityLabel("写一封信") } }
                .sheet(isPresented: $compose) { LetterComposer() }
        }
    }
}
struct LetterComposer: View {
    @EnvironmentObject private var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("亲爱的\(store.garden?.name ?? "你")：").font(.title2.weight(.medium))
                TextEditor(text: $text).scrollContentBackground(.hidden).font(.body).lineSpacing(7).onChange(of: text) { _, value in text = String(value.prefix(2000)) }
                    .overlay(alignment: .topLeading) { if text.isEmpty { Text("想你的时候，就写一封信吧……").foregroundStyle(.secondary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) } }
                Text("\(text.count)/2000 · 仅你可见").font(.caption).foregroundStyle(Palette.muted)
            }.padding(24).background(Palette.cream).navigationTitle("把想念写下来").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("存入信箱") { store.addLetter(text); dismiss() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }.interactiveDismissDisabled(!text.isEmpty)
        }
    }
}
struct LetterDetail: View {
    @EnvironmentObject private var store: GardenStore
    @Environment(\.dismiss) private var dismiss
    let letter: MemoryLetter
    @State private var confirm = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("亲爱的\(store.garden?.name ?? "你")：").font(.title2)
                Text(letter.text).font(.system(size: 18, design: .serif)).lineSpacing(9).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Text(letter.createdAt, style: .date).font(.caption).foregroundStyle(Palette.muted)
            }.padding(26)
        }.background(Palette.cream).navigationTitle("一封想念").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(role: .destructive) { confirm = true } label: { Image(systemName: "trash") }.accessibilityLabel("删除信件") }
            .confirmationDialog("删除这封信？此操作不可撤销。", isPresented: $confirm, titleVisibility: .visible) { Button("删除", role: .destructive) { store.update { $0.letters.removeAll { $0.id == letter.id } }; dismiss() } }
    }
}
