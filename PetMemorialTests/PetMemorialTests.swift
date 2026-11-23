import XCTest
import UIKit
import simd
import UserNotifications
@testable import PetMemorial

final class PetMemorialTests: XCTestCase {
    func testTownEntrancesAndExistingPlotsStayWalkable() {
        for place in TownPlace.allCases { XCTAssertTrue(ParkLayout.isWalkable(place.arrival), place.title) }
        XCTAssertFalse(ParkLayout.isWalkable(TownPlace.memories.center))
        XCTAssertFalse(ParkLayout.isWalkable(TownPlace.post.center))
        XCTAssertFalse(ParkLayout.isWalkable(TownPlace.plaza.center))
        for i in 0..<48 { XCTAssertTrue(ParkLayout.isWalkable(ParkLayout.arrival(i)));XCTAssertFalse(ParkLayout.isWalkable(ParkLayout.position(i))) }
        for z in 12...28 { XCTAssertTrue(ParkLayout.isWalkable([11,0,Float(z)])) }
    }

    @MainActor func testAuthorizedNotificationsScheduleAndCancelOnLogout() async throws {
        let center=UNUserNotificationCenter.current()
        let status=await center.notificationSettings().authorizationStatus
        guard status == .authorized else { throw XCTSkip("Run the reminder permission UI test first on this dedicated simulator") }
        var garden=MemorialGarden(name:"通知验收QA",species:"cat",story:"")
        garden.birthday=Date();garden.memorialDate=Date()
        let key=MemorialReminders.preferenceKey(garden,account:"qa-account")
        UserDefaults.standard.set(true,forKey:key)
        defer { UserDefaults.standard.removeObject(forKey:key) }
        let failure=await MemorialReminders.sync(garden,account:"qa-account");XCTAssertNil(failure)
        let pending=await center.pendingNotificationRequests().filter{$0.identifier.hasPrefix("petmemorial.")}
        XCTAssertEqual(pending.count,2)
        XCTAssertTrue(pending.allSatisfy{($0.trigger as? UNCalendarNotificationTrigger)?.repeats==true})
        XCTAssertTrue(pending.allSatisfy{$0.content.body.contains("通知验收QA")})
        await MemorialReminders.sync(nil,account:nil)
        let after=await center.pendingNotificationRequests().filter{$0.identifier.hasPrefix("petmemorial.")}
        XCTAssertTrue(after.isEmpty)
    }
    @MainActor func testAnnualRemindersAndAccountIsolation() {
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let leap=calendar.date(from:DateComponents(year:2024,month:2,day:29))!
        let c=MemorialReminders.components(leap,calendar:calendar)
        XCTAssertEqual(c.month,2);XCTAssertEqual(c.day,28);XCTAssertEqual(c.hour,9);XCTAssertNil(c.year)
        let now=calendar.date(from:DateComponents(year:2026,month:3,day:1))!
        let next=MemorialReminders.next(leap,now:now,calendar:calendar)!
        XCTAssertEqual(calendar.component(.year,from:next),2027)
        let garden=MemorialGarden(name:"团子",species:"cat",story:"")
        XCTAssertNotEqual(MemorialReminders.preferenceKey(garden,account:"1"),MemorialReminders.preferenceKey(garden,account:"2"))
        XCTAssertNotEqual(MemorialReminders.preferenceKey(garden,account:nil),MemorialReminders.preferenceKey(garden,account:"1"))
    }
    func testOlderParkResponsesRemainCompatible() throws {
        let data=Data("[{\"index\":0,\"name\":\"团子\",\"story\":\"\",\"photo\":\"\",\"isMine\":false}]".utf8)
        let cards=try JSONDecoder().decode([PublicMonument].self,from:data)
        XCTAssertNil(cards.first?.publicId);XCTAssertNil(cards.first?.flowers)
    }
    func testBackupRoundTripPreservesChineseLettersPhotosAndDates() throws {
        var garden = MemorialGarden(name: "团子", species: "cat", story: "一起看过的每一次日落。")
        garden.memorialDate = Date(timeIntervalSince1970: 1_700_000_000)
        garden.photos = [MemoryPhoto(imageBase64: "test", caption: "回家的那一天")]
        garden.letters = [MemoryLetter(text: "想你了。\n愿你每天都有小鱼干。")]
        garden.flowerCount = 5
        let original = BackupEnvelope(version: 3, garden: garden)
        let data = try MemorialCoding.encoder.encode(original)
        let decoded = try MemorialCoding.decoder.decode(BackupEnvelope.self, from: data)
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.garden.name, garden.name)
        XCTAssertEqual(decoded.garden.photos[0].imageBase64, garden.photos[0].imageBase64)
        XCTAssertEqual(decoded.garden.photos[0].caption, garden.photos[0].caption)
        XCTAssertEqual(decoded.garden.photos[0].createdAt.timeIntervalSince1970, garden.photos[0].createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.garden.letters[0].text, garden.letters[0].text)
        XCTAssertEqual(decoded.garden.memorialDate, garden.memorialDate)
        XCTAssertEqual(decoded.garden.flowerCount, 5)
    }
    @MainActor
    func testLocalPhotoLetterPersistenceAndDeletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("garden.json")
        let store = GardenStore(fileURL: url)
        store.setGarden(MemorialGarden(name: "测试伙伴", species: "cat", story: "我们的故事"))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let data = try XCTUnwrap(image.pngData())
        for _ in 0..<6 { try store.addPhoto(data: data, caption: "记忆") }
        XCTAssertThrowsError(try store.addPhoto(data: data, caption: "不能超过六张"))
        store.addLetter("我很想你。")
        store.offerFlower(); store.lightCandle()
        let reopened = GardenStore(fileURL: url)
        XCTAssertEqual(reopened.garden?.photos.count, 6)
        XCTAssertEqual(reopened.garden?.letters.first?.text, "我很想你。")
        XCTAssertEqual(reopened.garden?.flowerCount, 1)
        let compressed = try XCTUnwrap(Data(base64Encoded: reopened.garden!.photos[0].imageBase64))
        XCTAssertNotNil(UIImage(data: compressed))
        XCTAssertLessThanOrEqual(compressed.count, 145000)
        await reopened.deleteGarden()
        XCTAssertNil(GardenStore(fileURL: url).garden)
    }

    func testParkPathsAndMemorialCollisions() {
        XCTAssertTrue(ParkLayout.isWalkable([0,0,8]))
        XCTAssertTrue(ParkLayout.isWalkable([0,0,-15]))
        for index in 0..<ParkLayout.count {
            let arrival=ParkLayout.arrival(index)
            XCTAssertTrue(ParkLayout.isWalkable(arrival))
            let nearest=(0..<ParkLayout.count).min { simd_distance(arrival,ParkLayout.position($0)) < simd_distance(arrival,ParkLayout.position($1)) }
            XCTAssertEqual(nearest,index)
            XCTAssertFalse(ParkLayout.isWalkable(ParkLayout.position(index)))
            XCTAssertTrue(ParkLayout.isWalkable(ParkLayout.position(index) + [0,0,1.5]))
        }
        XCTAssertFalse(ParkLayout.isWalkable([13,0,0]))
        XCTAssertFalse(ParkLayout.isWalkable([0,0,-20]))
    }
    func testPublicPayloadExcludesLettersAndOtherPhotos() throws {
        var garden = MemorialGarden(name:"团子",species:"cat",story:"回忆")
        garden.letters=[MemoryLetter(text:"绝不能公开的私信")]
        let payload=try ParkClient.publication(garden,index:2)
        let json=try XCTUnwrap(JSONSerialization.jsonObject(with:payload) as? [String:Any])
        XCTAssertEqual(Set(json.keys),Set(["index","name","story","photo"]))
        XCTAssertFalse(String(decoding:payload,as:UTF8.self).contains("私信"))
    }
    func testOldBackupWithoutPlotStillDecodes() throws {
        let data=try MemorialCoding.encoder.encode(MemorialGarden(name:"旧资料",species:"cat",story:""))
        let decoded=try MemorialCoding.decoder.decode(MemorialGarden.self,from:data)
        XCTAssertNil(decoded.plotIndex)
    }

    func testFutureDateNeverShowsNegativeMemorialDays() {
        var garden = MemorialGarden(name: "豆豆", species: "dog", story: "")
        garden.memorialDate = Date().addingTimeInterval(86400 * 10)
        XCTAssertEqual(garden.daysTogetherInMemory, 0)
    }
}
