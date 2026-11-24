import SwiftUI
import UIKit
import ImageIO

@MainActor
final class GardenStore: ObservableObject {
    @Published private(set) var state = SavedState()
    @Published private(set) var isSyncing = false
    @Published var notice: String?
    @Published var error: String?
    private var revision = 0
    private var pendingSync = false
    private var canWrite = true
    private let client = BackupClient()
    private var file: URL
    var garden: MemorialGarden? { state.garden }
    init(fileURL: URL? = nil) {
        let dir = fileURL?.deletingLastPathComponent() ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PetMemorial", isDirectory: true)
        let account = fileURL == nil ? (try? AccountVault.read()) : nil
        file = fileURL ?? dir.appendingPathComponent(account.map { "account-\($0.userId).json" } ?? "garden.json")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { state = try MemorialCoding.decoder.decode(SavedState.self, from: Data(contentsOf: file)); if account == nil && state.accountId != nil { state = SavedState() } }
        } catch {
            canWrite = false
            self.error = L("本机资料读取失败。为保护原有记录，暂不覆盖，请保留应用并联系支持。")
        }
    }
    func setGarden(_ garden: MemorialGarden) {
        guard canWrite else { return }
        state.garden = garden
        revision += 1
        persist()
        if state.cloudEnabled { Task { await backup() } }
    }
    func update(_ edit: (inout MemorialGarden) -> Void) {
        guard var garden = garden else { return }
        edit(&garden)
        setGarden(garden)
    }
    func addPhoto(data: Data, caption: String) throws {
        guard (garden?.photos.count ?? 0) < 6 else { throw MemorialError(message: L("首版最多保存 6 张珍贵照片。")) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 900
              ] as CFDictionary) else { throw MemorialError(message: L("这张照片无法读取，请换一张。")) }
        let image = UIImage(cgImage: thumbnail)
        var encoded = image.jpegData(compressionQuality: 0.7)
        for quality in [0.55, 0.4, 0.25, 0.12] where (encoded?.count ?? Int.max) > 145000 { encoded = image.jpegData(compressionQuality: quality) }
        guard let encoded, encoded.count <= 145000 else { throw MemorialError(message: L("照片过大，请裁剪后再试。")) }
        update { $0.photos.append(MemoryPhoto(imageBase64: encoded.base64EncodedString(), caption: String(caption.prefix(80)))) }
    }
    func addLetter(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 2000, (garden?.letters.count ?? 0) < 100 else { error = L("信件需为 1–2000 字，最多保存 100 封。"); return }
        update { $0.letters.insert(MemoryLetter(text: value), at: 0) }
    }
    func offerFlower() { update { $0.flowerCount = min(9999, $0.flowerCount + 1) }; notice = L("一束花，替你说想念。") }
    func lightCandle() { update { $0.candleCount = min(9999, $0.candleCount + 1) }; notice = L("留一盏灯，温暖这份记忆。") }
    func enableCloud() async {
        state.cloudEnabled = true
        persist()
        await backup()
    }
    func backup() async {
        guard state.cloudEnabled, garden != nil, canWrite else { return }
        pendingSync = true
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let key = try BackupKey.read()
            while pendingSync, let snapshot = garden {
                pendingSync = false
                let sentRevision = revision
                let version = try await client.save(BackupEnvelope(version: state.version, garden: snapshot), key: key)
                state.version = version
                state.lastBackup = Date()
                persist()
                if revision != sentRevision { pendingSync = true }
            }
            notice = L("已安全备份到云端。")
        } catch { pendingSync = false; self.error = error.localizedDescription }
    }
    func restore(key: String) async {
        guard !isSyncing, canWrite else { return }
        guard (try? AccountVault.read()) == nil else { error = L("已登录账号时无需导入匿名钥匙；请退出账号后恢复游客备份。"); return }
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard key.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { error = L("请填写完整的 64 位备份钥匙。"); return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await client.load(key: key)
            try BackupKey.write(key)
            state = SavedState(garden: result.garden, version: result.version, cloudEnabled: true, lastBackup: Date())
            revision += 1
            persist()
            notice = L("纪念花园已恢复。")
        } catch { self.error = error.localizedDescription }
    }
    func restoreAccountBackup() async {
        guard !isSyncing,canWrite else { return }
        do {
            guard let session=try AccountVault.read() else { throw MemorialError(message:L("请先登录账号")) }
            isSyncing=true;defer { isSyncing=false }
            let result=try await client.load(key:BackupKey.read())
            state=SavedState(accountId:session.userId,garden:result.garden,version:result.version,cloudEnabled:true,lastBackup:Date())
            revision+=1;pendingSync=false;persist();notice=L("账号云备份已恢复")
        } catch { self.error=error.localizedDescription }
    }
    func deleteGarden() async {
        guard !isSyncing, canWrite else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            if state.garden?.plotIndex != nil { _ = try await ParkClient.request("DELETE") }
            if state.cloudEnabled { _ = try await client.request(method: "DELETE", key: BackupKey.read()) }
            state = SavedState(accountId:state.accountId)
            revision += 1
            persist()
            notice = L("本机纪念资料及已开启的云备份已删除。")
        } catch { self.error = L("删除未完成，资料仍保留。{0}", error.localizedDescription) }
    }
    func activateAccount(_ session: AccountSession, adoptGuest: Bool) async throws {
        guard !isSyncing,canWrite else { throw MemorialError(message:L("正在保存资料，请稍后重试")) }
        isSyncing=true; defer { isSyncing=false }
        let directory=file.deletingLastPathComponent()
        let nextFile=directory.appendingPathComponent("account-\(session.userId).json")
        var next:SavedState
        if adoptGuest && state.accountId == nil {
            // A previous login may have written an account copy before Keychain failed.
            // The still-active guest copy is authoritative when finishing that adoption.
            next=state
        } else if FileManager.default.fileExists(atPath:nextFile.path) {
            next=try MemorialCoding.decoder.decode(SavedState.self,from:Data(contentsOf:nextFile))
        } else if adoptGuest { next=state }
        else {
            do {
                let bytes=try await client.request(method:"GET",key:BackupKey.read(),accountToken:session.token)
                let envelope=try MemorialCoding.decoder.decode(BackupEnvelope.self,from:bytes)
                next=SavedState(garden:envelope.garden,version:envelope.version,cloudEnabled:true,lastBackup:Date())
            } catch let error as MemorialError where error.status == 404 {
                next=SavedState()

            }
        }
        next.accountId=session.userId
        try MemorialCoding.encoder.encode(next).write(to:nextFile,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        let guestFile=directory.appendingPathComponent("garden.json")
        let originalGuest=try? Data(contentsOf:guestFile)
        if adoptGuest {
            var marker=SavedState();marker.accountId=session.userId
            try MemorialCoding.encoder.encode(marker).write(to:guestFile,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        }
        do { try AccountVault.save(session) }
        catch {
            if adoptGuest,let originalGuest { try? originalGuest.write(to:guestFile,options:.atomic) }
            throw error
        }
        file=nextFile;state=next;revision+=1;pendingSync=false;error=nil
        notice=adoptGuest ? L("已登录，本机纪念资料和碑位已关联账号") : L("已进入账号的纪念花园；游客资料保持独立")
    }
    func deactivateAccount() throws {
        guard !isSyncing,canWrite else { throw MemorialError(message:L("资料正在同步，请稍后退出")) }
        let guestFile=file.deletingLastPathComponent().appendingPathComponent("garden.json")
        var guest=FileManager.default.fileExists(atPath:guestFile.path) ? try MemorialCoding.decoder.decode(SavedState.self,from:Data(contentsOf:guestFile)) : SavedState()
        if guest.accountId != nil {
            // Bound capability keys must never be reused by the logged-out guest.
            let newKey=(UUID().uuidString+UUID().uuidString).replacingOccurrences(of:"-",with:"").lowercased()
            try BackupKey.write(newKey)
            guest=SavedState()
            try MemorialCoding.encoder.encode(guest).write(to:guestFile,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        }
        try AccountVault.clear()
        file=guestFile;state=guest;revision+=1;pendingSync=false;error=nil;notice=L("已退出账号，账号资料仍然保留")
    }
    private func persist() {
        do { try MemorialCoding.encoder.encode(state).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        catch { self.error = L("本机保存失败，请检查设备存储空间后重试。") }
    }
}
