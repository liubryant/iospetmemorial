import SwiftUI

struct PublicMonument: Decodable, Identifiable {
    let index: Int
    let name: String
    let story: String
    let photo: String
    let isMine: Bool
    var publicId: String?
    var flowers: Int?
    var candles: Int?
    var id: Int { index }
    var memoryPhoto: MemoryPhoto? { photo.isEmpty ? nil : MemoryPhoto(id:"public-\(index)-\(photo.hashValue)",imageBase64:photo,caption:name) }
}
struct ParkClient {
    static func request(_ method: String, body: Data? = nil, key: String? = nil, accountToken: String? = nil, path: String = "park") async throws -> Data {
        var request = URLRequest(url:URL(string:"https://www.cjym123.cn:8066/api/petmemorial/\(path)")!)
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 25
        request.setValue("Bearer \(try key ?? BackupKey.read())",forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let token = try accountToken ?? AccountVault.read()?.token { request.setValue(token,forHTTPHeaderField:"X-App-Token") }
        let (data,response) = try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else { throw MemorialError(message:"纪念园连接失败") }
        guard (200...299).contains(http.statusCode) else {
            let message=(try? JSONSerialization.jsonObject(with:data) as? [String:Any])?["message"] as? String
            throw MemorialError(message:message ?? "纪念园暂不可用（\(http.statusCode)）")
        }
        return data
    }
    static func publication(_ garden: MemorialGarden, index: Int) throws -> Data {
        var photo = ""
        if let first=garden.photos.first, let bytes=Data(base64Encoded:first.imageBase64), let image=UIImage(data:bytes) {
            let ratio=min(1,320/max(image.size.width,image.size.height))
            let size=CGSize(width:image.size.width*ratio,height:image.size.height*ratio)
            let format=UIGraphicsImageRendererFormat(); format.scale=1
            let thumbnail=UIGraphicsImageRenderer(size:size,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:size)) }
            for quality in [0.7,0.5,0.3,0.1] {
                if let data=thumbnail.jpegData(compressionQuality:quality), data.count<=45000 { photo=data.base64EncodedString(); break }
            }
            guard !photo.isEmpty else { throw MemorialError(message:"公开照片过大，请换一张图片") }
        }
        return try JSONSerialization.data(withJSONObject:["index":index,"name":garden.name,"story":garden.story,"photo":photo])
    }
}
@MainActor final class ParkStore: ObservableObject {
    @Published var plots: [PublicMonument] = []
    @Published var busy = false
    @Published var loaded = false
    @Published var error: String?
    var mine: PublicMonument? { plots.first { $0.isMine } }
    func refresh() async {
        guard !busy else { return }; busy=true; defer { busy=false }
        do { plots=try JSONDecoder().decode([PublicMonument].self,from:await ParkClient.request("GET")); loaded=true; error=nil }
        catch { self.error=error.localizedDescription; loaded=false }
    }
    func claim(_ index: Int, garden: MemorialGarden) async -> Bool {
        guard !busy,loaded else { return false }; busy=true; defer { busy=false }
        do {
            _=try await ParkClient.request("PUT",body:ParkClient.publication(garden,index:index))
            plots=try JSONDecoder().decode([PublicMonument].self,from:await ParkClient.request("GET")); error=nil; return true
        } catch { self.error=error.localizedDescription; loaded=false; return false }
    }
    func release() async -> Bool {
        guard !busy else { return false }; busy=true; defer { busy=false }
        do { _=try await ParkClient.request("DELETE"); plots.removeAll { $0.isMine }; error=nil; return true }
        catch { self.error=error.localizedDescription; return false }
    }
}
