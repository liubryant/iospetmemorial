# 友盟统计与首次协议

- iOS Bundle ID：`cn.cjym.petmemorial`；AppKey：`6b0500a8863270068cdcfeb0`；渠道：`App Store`。
- 与 iosagentclaw 一致：UMCommon 7.5.11、UMDevice 3.6.0，使用 CocoaPods 锁定依赖。
- 执行 `pod install` 后使用 **PetMemorial.xcworkspace** 构建，不能继续只构建 xcodeproj。
- 未接受 `2026-11-24` 版协议前不创建账号/业务 Store、不加载云端、不初始化友盟。暂不同意可进入仅本地的场景预览。
- 首次进入不弹出统计授权；新用户统计默认关闭，仅在设置中主动开启时展示说明。未同意统计不初始化 SDK；关闭后调用 SDK 的统计禁用接口并阻断全部自定义事件。
- 不接入 IDFA/ATT、广告、推送或定位模块；没有统计登录 ID、手机号、宠物照片或信件内容。SDK自身处理设备/应用/网络信息。
- SDK 为静态库，随 SDK 分发的 PrivacyInfo.xcprivacy 分别保留在 UMCommonPrivacy.bundle / UMDevicePrivacy.bundle；更新 SDK 时须同步这些文件。
- 固定计数事件：view_garden、view_photos、view_letters、view_settings、enter_town、enter_forest、open_map。不是页面时长统计。友盟控制台若要求先注册事件，按以上 ID 创建计数事件。
- 首次协议版本记录与可选统计选择独立保存；更新政策实质内容时同步修改 LegalPolicy.version 和服务端、客户端 HTML。
- UI/单元测试禁用真实 SDK 上报；DEBUG 测试启动参数不会进入 Release 流程。

## 线上协议

- https://www.cjym123.cn/docs/petmemorial/agreement.html
- https://www.cjym123.cn/docs/petmemorial/privacy.html

服务端源文件：clawboootdo/src/main/resources/static/docs/petmemorial/。
客户端离线副本：PetMemorial/Resources/Legal/。首次声明用离线副本，“查看线上版本”打开上述地址。

## 控制台还需核实

本地接入不需要 App Secret、推送证书或后端统计接口。AppKey 所属友盟应用需要为 iOS，并与上述 Bundle ID 对应；无法仅由 AppKey 推断其控制台配置。上架 App Store Connect 时需按实际 SDK 及功能填写 App 隐私信息。
真机用户同意统计并使用应用后，可在友盟实时/集成测试中确认收数；构建成功不能代替控制台收数验收。本次未登录友盟控制台。
