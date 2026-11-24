import Foundation
import Security

struct MemorialError: LocalizedError {
    let message: String
    var status: Int? = nil
    var errorDescription: String? { message }
}
enum BackupKey {
    private static let service = "cn.cjym.petmemorial.backup"
    static func read() throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "private-garden",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) { return key }
        guard status == errSecItemNotFound else { throw MemorialError(message: L("无法读取备份钥匙，请解锁设备后重试。")) }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw MemorialError(message: L("无法创建安全备份钥匙。")) }
        let key = bytes.map { String(format: "%02x", $0) }.joined()
        try write(key)
        return key
    }
    static func write(_ key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "private-garden"]
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw MemorialError(message: L("无法保存备份钥匙。")) }
        } else if status != errSecSuccess { throw MemorialError(message: L("无法保存备份钥匙。")) }
    }
}
struct BackupClient {
    private let endpoint = URL(string: "https://www.cjym123.cn:8066/api/petmemorial/garden")!
    func request(method: String, key: String, body: Data? = nil, accountToken: String? = nil) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if let token = try accountToken ?? AccountVault.read()?.token { request.setValue(token, forHTTPHeaderField: "X-App-Token") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MemorialError(message: L("服务器未响应，请稍后重试。")) }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw MemorialError(message: AppLocalization.serverMessage(message, fallback:L("备份失败（{0}），本机资料仍然保留。", http.statusCode)), status: http.statusCode)
        }
        return data
    }
    func save(_ envelope: BackupEnvelope, key: String) async throws -> Int {
        let body = try MemorialCoding.encoder.encode(envelope)
        guard body.count <= 1_600_000 else { throw MemorialError(message: L("备份太大，请减少照片后重试。")) }
        let data = try await request(method: "PUT", key: key, body: body)
        struct Version: Decodable { let version: Int }
        return try JSONDecoder().decode(Version.self, from: data).version
    }
    func load(key: String) async throws -> BackupEnvelope {
        try MemorialCoding.decoder.decode(BackupEnvelope.self, from: await request(method: "GET", key: key))
    }
}
