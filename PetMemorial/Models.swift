import Foundation

struct MemoryPhoto: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var imageBase64: String
    var caption: String
    var createdAt = Date()
}
struct MemoryLetter: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var text: String
    var createdAt = Date()
}
struct MemorialGarden: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var species: String
    var story: String
    var birthday: Date?
    var memorialDate: Date?
    var plotIndex: Int?
    var theme = "sage"
    var flowerCount = 0
    var candleCount = 0
    var createdAt = Date()
    var photos: [MemoryPhoto] = []
    var letters: [MemoryLetter] = []
    var daysTogetherInMemory: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: memorialDate ?? createdAt), to: Calendar.current.startOfDay(for: Date())).day ?? 0)
    }
}
struct BackupEnvelope: Codable {
    var version: Int
    var garden: MemorialGarden
}
struct SavedState: Codable {
    var accountId: String?
    var garden: MemorialGarden?
    var version = 0
    var cloudEnabled = false
    var lastBackup: Date?
}
enum MemorialCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
