import XCTest
@testable import PetMemorial

private final class AccountURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int,Data))?
    override class func canInit(with request:URLRequest)->Bool { true }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        do {
            let (status,data)=try Self.handler!(request)
            client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}
final class AccountTests:XCTestCase {
    private func api(response:String,status:Int=200,check:@escaping(URLRequest)->Void = {_ in})->AccountAPI {
        AccountURLProtocol.handler={ request in check(request);return(status,Data(response.utf8)) }
        let configuration=URLSessionConfiguration.ephemeral;configuration.protocolClasses=[AccountURLProtocol.self]
        return AccountAPI(network:URLSession(configuration:configuration))
    }
    override func tearDown() { AccountURLProtocol.handler=nil;super.tearDown() }
    func testCodeLoginUsesExistingEndpointAndRequiresToken() async throws {
        let result=try await api(response:"{\"code\":0,\"data\":{\"phone\":\"13800000000\",\"accessToken\":\"test-token\"}}",check:{request in
            XCTAssertEqual(request.url?.path,"/im/bot/login-by-code")
        }).login(phone:"13800000000",credential:"123456",passwordMode:false)
        XCTAssertEqual(result.token,"test-token")
    }
    func testPasswordLoginAcceptsLegacyTokenAlias() async throws {
        let result=try await api(response:"{\"code\":\"0\",\"data\":{\"token\":\"legacy\"}}",check:{request in
            XCTAssertEqual(request.url?.path,"/im/bot/login-by-password")
        }).login(phone:"13800000000",credential:"example",passwordMode:true)
        XCTAssertEqual(result.token,"legacy")
    }
    func testMissingTokenCannotCreateFakeLoggedInState() async {
        do { _=try await api(response:"{\"code\":0,\"data\":{}}").login(phone:"13800000000",credential:"123456",passwordMode:false);XCTFail("must reject missing token") }
        catch { XCTAssertTrue(error.localizedDescription.contains("凭证")) }
    }
    func testWrongPasswordResponseIsShown() async {
        do { _=try await api(response:"{\"code\":400,\"msg\":\"密码错误\"}").login(phone:"13800000000",credential:"wrong",passwordMode:true);XCTFail("must reject") }
        catch { XCTAssertEqual(error.localizedDescription,"密码错误") }
    }
    func testPhoneValidation() {
        XCTAssertTrue(AccountAPI.validPhone("13800000000"));XCTAssertFalse(AccountAPI.validPhone("123"));XCTAssertFalse(AccountAPI.validPhone("abcdefghijk"))
    }
    @MainActor func testAdoptionLogoutAndAccountReopenPreservePrivateData() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let originalKey=try BackupKey.read()
        let originalSession=try AccountVault.read()
        defer {
            try? BackupKey.write(originalKey)
            if let session=originalSession { try? AccountVault.save(session) } else { try? AccountVault.clear() }
            try? FileManager.default.removeItem(at:directory)
        }
        let store=GardenStore(fileURL:directory.appendingPathComponent("garden.json"))
        store.setGarden(MemorialGarden(name:"私密伙伴",species:"dog",story:"我的回忆"));store.addLetter("不能让其他账号看到")
        let session=AccountSession(userId:"99123",phone:"13800000000",token:"test-only")
        var interruptedCopy=SavedState();interruptedCopy.garden=MemorialGarden(name:"登录中断前的旧副本",species:"cat",story:"")
        try MemorialCoding.encoder.encode(interruptedCopy).write(to:directory.appendingPathComponent("account-99123.json"))
        try await store.activateAccount(session,adoptGuest:true)
        XCTAssertEqual(store.garden?.letters.count,1)
        try store.deactivateAccount()
        XCTAssertNil(store.garden)
        XCTAssertNil(try AccountVault.read())
        try await store.activateAccount(session,adoptGuest:false)
        XCTAssertEqual(store.garden?.name,"私密伙伴")
        XCTAssertEqual(store.garden?.letters.first?.text,"不能让其他账号看到")
    }
}
