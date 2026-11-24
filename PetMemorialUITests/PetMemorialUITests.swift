import XCTest
final class PetMemorialUITests: XCTestCase {
    func testFirstLaunchLegalConsentAndOfflinePreview() {
        let app=XCUIApplication()
        app.launchArguments=["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsUnreviewed", "-testLegalUnreviewed"]
        app.launch()
        XCTAssertTrue(app.buttons["《隐私政策》"].waitForExistence(timeout:8))
        let welcome=XCTAttachment(screenshot:app.screenshot());welcome.name="First-launch-consent";welcome.lifetime = .keepAlways;add(welcome)
        app.buttons["《隐私政策》"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout:5))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Privacy-document";shot.lifetime = .keepAlways;add(shot)
        app.buttons["完成"].tap()
        app.buttons["暂不同意，基础浏览"].tap()
        XCTAssertTrue(app.buttons["重新阅读协议"].waitForExistence(timeout:5))
        XCTAssertFalse(app.tabBars.buttons["我的"].exists)
        app.buttons["重新阅读协议"].tap()
        app.buttons["同意并进入"].tap()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout:8))
        XCTAssertFalse(app.buttons["同意开启统计"].exists)
        app.terminate();app.launchArguments=["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK"];app.launch()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout:8))
        XCTAssertFalse(app.buttons["同意并进入"].exists)
        XCTAssertFalse(app.buttons["同意开启统计"].exists)
    }
    func testAnalyticsConsentCanBeEnabledAndRevoked() {
        let app=XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"]
        app.launch()
        app.tabBars.buttons["我的"].tap()
        let toggle=app.switches["使用统计"]
        for _ in 0..<4 { if toggle.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout:5))
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        let accept=app.buttons["同意开启统计"]
        if !accept.isHittable { app.swipeUp() }
        XCTAssertTrue(accept.waitForExistence(timeout:5))
        app.buttons["暂不开启，继续使用"].tap()
        XCTAssertEqual(toggle.value as? String,"0")
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        if !accept.isHittable { app.swipeUp() }
        accept.tap()
        XCTAssertEqual(toggle.value as? String,"1")
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        XCTAssertEqual(toggle.value as? String,"0")
    }

    func testForestRoundTripAndInteractions() {
        let app=XCUIApplication();app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        let enter=app.buttons["走进爪印小镇，陪你一会儿"]
        if !enter.isHittable { app.swipeUp() }
        if enter.exists { enter.tap() } else { app.buttons["先逛逛纪念园"].tap() }
        let town=app.otherElements["parkScene"]
        XCTAssertTrue(town.waitForExistence(timeout:10))
        expectation(for:NSPredicate(format:"value BEGINSWITH %@","位置"),evaluatedWith:town);waitForExpectations(timeout:5)
        let position=town.value as? String
        app.buttons["纪念碑地图"].tap()
        app.buttons.containing(.staticText,identifier:"回忆森林").firstMatch.tap()
        XCTAssertTrue(app.otherElements["forestScene"].waitForExistence(timeout:12))
        XCTAssertTrue(app.buttons["森林导览"].exists)
        let overview=XCTAttachment(screenshot:app.screenshot());overview.name="Forest-overview";overview.lifetime = .keepAlways;add(overview)
        for (title,action,heading) in [("纪念树","看看纪念树","纪念树"),("回忆步道","打开回忆相框","回忆相框")] {
            app.buttons["森林导览"].tap()
            app.buttons.containing(.staticText,identifier:title).firstMatch.tap()
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout:5));app.buttons[action].tap()
            XCTAssertTrue(app.navigationBars[heading].waitForExistence(timeout:5))
            app.buttons["回到森林"].tap()
        }
        app.buttons["森林导览"].tap()
        app.buttons.containing(.staticText,identifier:"湖边长椅").firstMatch.tap()
        XCTAssertTrue(app.buttons["在湖边坐一会儿"].waitForExistence(timeout:5));app.buttons["在湖边坐一会儿"].tap()
        XCTAssertTrue(app.buttons["起身继续走走"].waitForExistence(timeout:5))
        let bench=XCTAttachment(screenshot:app.screenshot());bench.name="Forest-bench";bench.lifetime = .keepAlways;add(bench)
        app.buttons["起身继续走走"].tap()
        app.buttons["返回广场"].tap()
        XCTAssertTrue(town.waitForExistence(timeout:12))
        expectation(for:NSPredicate(format:"value == %@",position ?? ""),evaluatedWith:town);waitForExpectations(timeout:5)
        // Repeat the transition to catch stale callbacks or retained scene state.
        app.buttons["纪念碑地图"].tap()
        app.buttons.containing(.staticText,identifier:"回忆森林").firstMatch.tap()
        XCTAssertTrue(app.otherElements["forestScene"].waitForExistence(timeout:12))
        app.buttons["返回广场"].tap()
        XCTAssertTrue(town.waitForExistence(timeout:12))
    }

    func testOrganizedSettingsNavigation() {
        let app=XCUIApplication();app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["人物形象"].exists)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Organized-settings";shot.lifetime = .keepAlways;add(shot)
        let privacy=app.buttons["隐私与使用说明"]
        if !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.waitForExistence(timeout:3));privacy.tap()
        XCTAssertTrue(app.navigationBars["隐私与使用说明"].waitForExistence(timeout:3))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["我的"].exists)
    }

    func testYouthfulAvatarPreview() {
        let app = XCUIApplication()
        app.launchArguments += ["-parkAvatarStyle", "female"]
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        let enter = app.buttons["走进爪印小镇，陪你一会儿"]
        if !enter.isHittable { app.swipeUp() }
        if enter.exists { enter.tap() } else { app.buttons["先逛逛纪念园"].tap() }
        let scene = app.otherElements["parkScene"]
        XCTAssertTrue(scene.waitForExistence(timeout:10))
        scene.pinch(withScale:2,velocity:1)
        let shot = XCTAttachment(screenshot:app.screenshot())
        shot.name = "Youthful-avatar-and-cat"; shot.lifetime = .keepAlways; add(shot)
    }

    func testTownMapAndPrivateRooms() throws {
        let app=XCUIApplication();app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        let enter=app.buttons["走进爪印小镇，陪你一会儿"]
        if !enter.isHittable { app.swipeUp() }
        if enter.exists { enter.tap() } else { app.buttons["先逛逛纪念园"].tap() }
        XCTAssertTrue(app.otherElements["parkScene"].waitForExistence(timeout:10))
        let overview=XCTAttachment(screenshot:app.screenshot());overview.name="Town-plaza";overview.lifetime = .keepAlways;add(overview)
        for title in ["记忆小屋","时光邮局","陪伴草地"] {
            app.buttons["纪念碑地图"].tap()
            let destination=app.buttons.containing(.staticText,identifier:title).firstMatch
            XCTAssertTrue(destination.waitForExistence(timeout:5));destination.tap()
            let entry=app.buttons["进入"+title]
            XCTAssertTrue(entry.waitForExistence(timeout:8));entry.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout:5))
            let shot=XCTAttachment(screenshot:app.screenshot());shot.name=title;shot.lifetime = .keepAlways;add(shot)
            if title == "陪伴草地" && app.buttons["玩一次追球"].exists {
                app.buttons["玩一次追球"].tap()
                XCTAssertTrue(app.staticTexts["去追小球吧，我们在这里等你。"].waitForExistence(timeout:5))
            } else { app.buttons["回到小镇"].tap() }
        }
    }

    func testReminderPermission() {
        let app=XCUIApplication();app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch();app.swipeUp()
        app.buttons.containing(.staticText,identifier:"值得记住的日子").firstMatch.tap()
        let toggle=app.switches["纪念日提醒"]
        XCTAssertTrue(toggle.waitForExistence(timeout:5))
        if toggle.value as? String != "1" {
            toggle.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap()
            let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
            let allow=springboard.buttons["Allow"]
            if allow.waitForExistence(timeout:3) { allow.tap() }
            else if springboard.buttons["允许"].exists { springboard.buttons["允许"].tap() }
            else if app.buttons["Allow"].exists { app.buttons["Allow"].tap() }
        }
        expectation(for:NSPredicate(format:"value == '1'"),evaluatedWith:toggle);waitForExpectations(timeout:8)
    }
    func testFiveMemorialFeatures() throws {
        let app=XCUIApplication();app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        if app.buttons["创建我的纪念花园"].waitForExistence(timeout:5) {
            app.buttons["创建我的纪念花园"].tap()
            let field=app.textFields["宠物名字（最多 30 字）"];field.tap();field.typeText("云朵QA")
            app.switches["记录生日"].tap()
            app.buttons["保存"].tap()
        }
        let enter=app.buttons["走进花园，陪你一会儿"]
        if !enter.isHittable { app.swipeUp() }
        let dates=app.buttons.containing(.staticText,identifier:"值得记住的日子").firstMatch
        if !dates.isHittable { app.swipeUp() }
        dates.tap()
        if !app.staticTexts["它的生日"].waitForExistence(timeout:2) {
            app.buttons["编辑纪念日期"].tap()
            let toggle=app.switches["记录生日"]
            toggle.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap()
            XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout:3))
            app.buttons["保存"].tap()
        }
        XCTAssertTrue(app.staticTexts["它的生日"].waitForExistence(timeout:5))
        let calendar=XCTAttachment(screenshot:app.screenshot());calendar.name="Memorial-dates";calendar.lifetime = .keepAlways;add(calendar)
        app.buttons["完成"].tap()
        if !enter.isHittable { app.swipeDown() };enter.tap()
        XCTAssertTrue(app.buttons["一起散步"].waitForExistence(timeout:10))
        app.buttons["摸摸它"].tap()
        let pet=XCTAttachment(screenshot:app.screenshot());pet.name="Pet-affection";pet.lifetime = .keepAlways;add(pet)
        let before=app.otherElements["parkScene"].value as? String
        app.buttons["一起散步"].tap();Thread.sleep(forTimeInterval:2)
        XCTAssertNotEqual(before,app.otherElements["parkScene"].value as? String)
        app.buttons["停一停"].tap();app.buttons["坐一会儿"].tap();XCTAssertTrue(app.buttons["跟我走"].exists);app.buttons["跟我走"].tap()
        let semaphore=DispatchSemaphore(value:0)
        var freeIndex:Int?
        var request=URLRequest(url:URL(string:"https://www.cjym123.cn:8066/api/petmemorial/park")!)
        request.setValue("Bearer "+String(repeating:"c",count:64),forHTTPHeaderField:"Authorization")
        URLSession.shared.dataTask(with:request) { data,_,_ in
            if let data,let rows=(try? JSONSerialization.jsonObject(with:data)) as? [[String:Any]] {
                let used=Set(rows.compactMap{$0["index"] as? Int});freeIndex=(0..<48).reversed().first{!used.contains($0)}
            };semaphore.signal()
        }.resume()
        XCTAssertEqual(semaphore.wait(timeout:.now()+25),.success)
        let index=try XCTUnwrap(freeIndex)
        app.buttons["纪念碑地图"].tap();app.buttons["碑位地图"].tap()
        let slot=app.buttons["前往\(index+1)号纪念碑"]
        if !slot.isHittable { app.swipeUp() };slot.tap()
        let view=app.buttons["查看 \(index+1) 号碑"]
        XCTAssertTrue(view.waitForExistence(timeout:5));view.tap()
        app.buttons["认领这个纪念碑"].tap();app.buttons["确认公开并认领"].tap()
        XCTAssertTrue(app.buttons["关闭"].waitForNonExistence(timeout:20));view.tap()
        let favorite=app.buttons["communityFavorite"]
        XCTAssertTrue(favorite.waitForExistence(timeout:10));if !favorite.isHittable { app.swipeUp() }
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:favorite)
        waitForExpectations(timeout:25)
        if favorite.label=="收藏伙伴" { favorite.tap() }
        expectation(for:NSPredicate(format:"label == %@", "取消收藏"),evaluatedWith:favorite);waitForExpectations(timeout:20)
        let flower=app.buttons["tribute-flower"];if !flower.isHittable { app.swipeUp() }
        expectation(for:NSPredicate(format:"enabled == true OR label CONTAINS %@", "今日已送出"),evaluatedWith:flower);waitForExpectations(timeout:25)
        if flower.isEnabled { flower.tap();XCTAssertTrue(app.staticTexts["一束花，替你说想念。"].waitForExistence(timeout:15)) }
        else { XCTAssertTrue(flower.label.contains("今日已送出")) }
        let candle=app.buttons["tribute-candle"]
        if !candle.label.contains("今日已送出") { expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:candle);waitForExpectations(timeout:25);candle.tap();XCTAssertTrue(app.staticTexts["一盏灯，温暖这份记忆。"].waitForExistence(timeout:15)) }
        let tribute=XCTAttachment(screenshot:app.screenshot());tribute.name="Tributes-and-visits";tribute.lifetime = .keepAlways;add(tribute)
        let share=app.buttons["分享这份想念"];if !share.isHittable { app.swipeUp() };share.tap()
        XCTAssertTrue(app.buttons["分享纪念卡与链接"].waitForExistence(timeout:5))
        let card=XCTAttachment(screenshot:app.screenshot());card.name="Memorial-share";card.lifetime = .keepAlways;add(card)
        app.buttons["分享纪念卡与链接"].tap();Thread.sleep(forTimeInterval:1)
        let sheet=XCTAttachment(screenshot:app.screenshot());sheet.name="System-sharing";sheet.lifetime = .keepAlways;add(sheet)
        let activityClose=app.buttons["header.closeButton"];XCTAssertTrue(activityClose.waitForExistence(timeout:5));activityClose.tap();XCTAssertTrue(activityClose.waitForNonExistence(timeout:5));Thread.sleep(forTimeInterval:0.5)
        let done=app.buttons["shareDone"];XCTAssertTrue(done.waitForExistence(timeout:5));done.tap();XCTAssertTrue(done.waitForNonExistence(timeout:5));Thread.sleep(forTimeInterval:0.5)
        app.buttons["monumentClose"].tap()
        XCTAssertTrue(app.buttons["monumentClose"].waitForNonExistence(timeout:5));Thread.sleep(forTimeInterval:0.8)
        app.buttons["纪念碑地图"].tap()
        XCTAssertTrue(app.navigationBars["寻找伙伴"].waitForExistence(timeout:8))
        app.segmentedControls.buttons["我的收藏"].tap()
        XCTAssertTrue(app.staticTexts["云朵QA"].waitForExistence(timeout:10))
        let directory=XCTAttachment(screenshot:app.screenshot());directory.name="Favorite-directory";directory.lifetime = .keepAlways;add(directory)
        app.buttons["前往云朵QA的纪念碑"].tap();view.tap()
        let release=app.buttons["释放这个碑位"]
        for _ in 0..<4 { if release.isHittable { break };app.swipeUp() }
        release.tap();app.buttons["确认释放"].tap()
        XCTAssertTrue(app.buttons["关闭"].waitForNonExistence(timeout:15))
    }

    func testLoginModesAndConsentWithoutSendingSMS() {
        let app=XCUIApplication();app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch();app.tabBars.buttons["我的"].tap()
        app.buttons.containing(.staticText,identifier:"登录，让陪伴与你相随").firstMatch.tap()
        XCTAssertTrue(app.textFields["loginPhone"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["获取验证码"].isEnabled)
        app.textFields["loginPhone"].tap();app.textFields["loginPhone"].typeText("13800000000")
        XCTAssertFalse(app.buttons["获取验证码"].isEnabled)
        app.buttons["完成"].tap()
        let code=XCTAttachment(screenshot:app.screenshot());code.name="Login-code";code.lifetime = .keepAlways;add(code)
        app.segmentedControls.buttons["密码登录"].tap()
        XCTAssertTrue(app.secureTextFields["密码（至少 6 位）"].exists)
        let password=XCTAttachment(screenshot:app.screenshot());password.name="Login-password";password.lifetime = .keepAlways;add(password)
        app.swipeUp()
        app.buttons["忘记密码？"].tap()
        XCTAssertTrue(app.secureTextFields["设置新密码（至少 6 位）"].waitForExistence(timeout:3))
        app.buttons["暂不登录"].tap()
        XCTAssertTrue(app.tabBars.buttons["我的"].exists)
    }
    func testCreateGardenWriteLetterAndReopen() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        let create = app.buttons["创建我的纪念花园"]
        if create.waitForExistence(timeout: 8) {
            create.tap()
            let name = app.textFields["宠物名字（最多 30 字）"]
            XCTAssertTrue(name.waitForExistence(timeout: 3))
            name.tap(); name.typeText("团子")
            app.buttons["保存"].tap()
        }
        XCTAssertTrue(app.buttons["走进花园，陪你一会儿"].waitForExistence(timeout: 8))
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "Garden-home"; home.lifetime = .keepAlways; add(home)
        app.tabBars.buttons["信箱"].tap()
        app.buttons["写一封信"].tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap(); editor.typeText("亲爱的团子，今天也很想你。")
        app.buttons["存入信箱"].tap()
        XCTAssertTrue(app.staticTexts["亲爱的团子，今天也很想你。"].firstMatch.waitForExistence(timeout: 3))
        app.terminate(); app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-disableAnalyticsSDK", "-testAnalyticsDeclined", "-testLegalAccepted"];app.launch()
        app.tabBars.buttons["信箱"].tap()
        XCTAssertTrue(app.staticTexts["亲爱的团子，今天也很想你。"].firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["花园"].tap()
        app.buttons["走进花园，陪你一会儿"].tap()
        XCTAssertTrue(app.buttons["纪念碑地图"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@", "48 个碑位 · 已认领")).firstMatch.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 2)
        let scene = XCTAttachment(screenshot: app.screenshot()); scene.name = "Walkable-park"; scene.lifetime = .keepAlways; add(scene)
        let before=app.otherElements["parkScene"].value as? String
        let joystick=app.otherElements["parkJoystick"]
        let center=joystick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        center.press(forDuration:0.1,thenDragTo:joystick.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)),withVelocity:.slow,thenHoldForDuration:1.2)
        XCTAssertNotEqual(before,app.otherElements["parkScene"].value as? String)
        let walked=XCTAttachment(screenshot:app.screenshot());walked.name="After-walking";walked.lifetime = .keepAlways;add(walked)
        app.buttons["返回"].tap()
        app.tabBars.buttons["相册"].tap()
        let album=XCTAttachment(screenshot:app.screenshot());album.name="Album-thumbnails";album.lifetime = .keepAlways;add(album)
    }
}

final class LocalizationUITests: XCTestCase {
    private let languages: [[String]] = [
["zh-Hans", "同意并进入", "花园", "相册", "信箱", "我的", "密码登录", "暂不登录", "用户协议与隐私保护", "纪念碑地图", "回忆森林", "森林导览", "返回广场", "返回小镇"],
["en", "Agree and enter", "Garden", "Photos", "Letters", "Me", "Password", "Not now", "Terms and privacy", "Memorial map", "Memory Forest", "Forest guide", "Back to plaza", "Back to town"],
["ja", "同意して進む", "庭園", "アルバム", "手紙", "マイページ", "パスワード", "今はログインしない", "利用規約とプライバシー", "記念マップ", "思い出の森", "森のガイド", "広場に戻る", "街に戻る"],
["de", "Zustimmen und weiter", "Garten", "Fotos", "Briefe", "Profil", "Passwort", "Nicht jetzt", "Bedingungen und Datenschutz", "Gedenkkarte", "Erinnerungswald", "Waldführer", "Zurück zum Platz", "Zurück in die Stadt"],
["fr", "Accepter et continuer", "Jardin", "Photos", "Lettres", "Profil", "Mot de passe", "Pas maintenant", "Conditions et confidentialité", "Carte commémorative", "Forêt des souvenirs", "Guide forestier", "Retour à la place", "Retour en ville"],
["es", "Aceptar y continuar", "Jardín", "Fotos", "Cartas", "Perfil", "Contraseña", "Ahora no", "Condiciones y privacidad", "Mapa conmemorativo", "Bosque de recuerdos", "guía forestal", "volver a la plaza", "De regreso a la ciudad"],
["zh-Hant-HK", "同意並進入", "花園", "相簿", "信箱", "我的", "密碼登入", "暫不登入", "用戶協議與私隱", "紀念碑地圖", "回憶森林", "森林導覽", "返回廣場", "返回小鎮"],
["ko", "동의하고 시작", "정원", "사진첩", "편지함", "내 정보", "비밀번호", "나중에 로그인", "이용약관 및 개인정보", "기념 지도", "추억의 숲", "숲속 가이드", "광장으로 돌아가기", "마을로 돌아가기"],
["ar", "الموافقة والمتابعة", "الحديقة", "الصور", "الرسائل", "حسابي", "كلمة المرور", "ليس الآن", "الشروط والخصوصية", "خريطة تذكارية", "غابة الذكريات", "دليل الغابات", "العودة إلى الساحة", "العودة إلى المدينة"]
    ]
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name=name;shot.lifetime = .keepAlways;add(shot)
    }
    func testNineLanguagesConsentHomeAndLogin() {
        continueAfterFailure=false
        for words in languages {
            let app=XCUIApplication()
            app.launchArguments=["-AppleLanguages","(\(words[0]))","-AppleLocale",words[0],"-disableAnalyticsSDK","-testAnalyticsDeclined","-testLegalUnreviewed"]
            app.launch()
            XCTAssertTrue(app.buttons["legalAccept"].waitForExistence(timeout:10),words[0])
            XCTAssertEqual(app.buttons["legalAccept"].label,words[1])
            XCTAssertTrue(app.staticTexts[words[8]].exists,words[0])
            XCTAssertTrue(app.buttons["legalAccept"].isHittable)
            XCTAssertTrue(app.buttons["legalAgreement"].isHittable)
            XCTAssertTrue(app.buttons["legalPrivacy"].isHittable)
            capture(app,words[0]+"-consent")
            app.buttons["legalAccept"].tap()
            XCTAssertTrue(app.tabBars.buttons[words[2]].waitForExistence(timeout:10),words[0])
            capture(app,words[0]+"-home")
            if words[0]=="ar" {
                XCTAssertGreaterThan(app.tabBars.buttons[words[2]].frame.midX,app.tabBars.buttons[words[5]].frame.midX)
            }
            app.tabBars.buttons[words[3]].tap();capture(app,words[0]+"-photos")
            app.tabBars.buttons[words[4]].tap();capture(app,words[0]+"-letters")
            app.tabBars.buttons[words[5]].tap();capture(app,words[0]+"-settings")
            let login=app.buttons["openLogin"]
            XCTAssertTrue(login.waitForExistence(timeout:5));login.tap()
            XCTAssertTrue(app.textFields["loginPhone"].waitForExistence(timeout:5))
            capture(app,words[0]+"-sms-login")
            app.segmentedControls.buttons[words[6]].tap()
            XCTAssertTrue(app.secureTextFields.firstMatch.exists)
            capture(app,words[0]+"-password-login")
            app.buttons[words[7]].tap();app.terminate()
        }
    }
    func testTownAndForestInEnglishGermanAndArabic() {
        continueAfterFailure=false
        for words in languages where ["en","de","ar"].contains(words[0]) {
            let app=XCUIApplication()
            app.launchArguments=["-AppleLanguages","(\(words[0]))","-AppleLocale",words[0],"-disableAnalyticsSDK","-testAnalyticsDeclined","-testLegalAccepted"]
            app.launch()
            let enter=app.buttons["enterTown"]
            XCTAssertTrue(enter.waitForExistence(timeout:10))
            if !enter.isHittable { app.swipeUp() };enter.tap()
            XCTAssertTrue(app.otherElements["parkScene"].waitForExistence(timeout:12))
            capture(app,words[0]+"-town")
            app.buttons[words[9]].tap()
            XCTAssertTrue(app.buttons.containing(.staticText,identifier:words[10]).firstMatch.waitForExistence(timeout:5))
            capture(app,words[0]+"-map")
            app.buttons.containing(.staticText,identifier:words[10]).firstMatch.tap()
            XCTAssertTrue(app.otherElements["forestScene"].waitForExistence(timeout:12))
            capture(app,words[0]+"-forest")
            app.buttons[words[11]].tap();capture(app,words[0]+"-forest-guide")
            app.terminate()
        }
    }
}
