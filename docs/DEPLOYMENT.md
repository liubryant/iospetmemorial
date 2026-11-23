# 2026-11-20 首版部署记录

- 服务器：39.108.144.196。应用目录：/home/repo/bootdo/target。
- 本机编译 Java 8；服务器无编译、无新增 Java 服务、无新常驻进程。
- 补丁 10,359 bytes，仅新增 PetMemorialController 及其内部类、更新 ShiroConfig 专用匿名路由。该路由由控制器自行验证能力钥匙。
- 旧 ShiroConfig 与本机编译产物的反汇编在忽略常量池编号后相同。
- 原有 jar 每一个未修改条目的 CRC 与长度均已校验一致，未覆盖配置和依赖。
- 原包备份：/home/repo/bootdo/target/bootdo-1.7.0.jar.pre-petmemorial-20261120-205620。
- 新 PID（部署当时）：3588220。
- 保留参数：-Xms128m -Xmx700m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=200m -XX:+UseSerialGC。
- 单进程顺序重启，健康检查失败脚本自动回滚；本次启动成功，没有触发回滚。
- 重启后 available 约 883 MB；部署前约 734 MB，无 swap，未启动第二份 Java。
- /login、/im/bot/navi/vip/products、/api/sounds、官网、宠物 health 均返回 200。
- 线上合成照片和信件读写 / 版本冲突 / 隔离 / 删除测试通过，测试行已删除。

## 接口

Base URL: https://www.cjym123.cn:8066/api/petmemorial

- GET /health：模块与数据库状态。
- GET /garden：读取当前钥匙的花园，未创建返回 404。
- PUT /garden：正文 `{ "version": 0, "garden": ... }`；首次 version=0；后续使用上次返回版本。成功返回新 version，冲突返回 409。
- DELETE /garden：删除当前钥匙的花园，幂等。
- 三个 garden 操作需要 `Authorization: Bearer <64位小写十六进制钥匙>`。
- 最大请求体 1.6 MB，照片最多 6 张，信件最多 100 封；每 IP 每分钟最多 60 次 garden 操作。

## 回滚注意

先确认当前部署未被后续版本替换，再停止当前 bootdo PID，恢复上述备份，使用原 JVM 参数从 target 目录启动。
不要并行启动第二份 Java，不要在服务器执行 Maven。回滚代码不会删除新增表。
`ops/` 脚本保留发布实现供审阅，重复执行前应核对候选包、当前 PID 和备份路径。

## 客户端最终验证

- 真机 Debug 签名构建通过并已安装到连接的 iPhone。启动时设备锁屏，未能远程打开；解锁后手动打开“爪印花园”。
- 3 项单元测试通过，1 项端到端 UI 测试通过。
- 最终截图在 docs/screenshots；全屏场景在献花、点灯后仍正常渲染。
- 未提交 App Store，也未创建商店条目。

## 2026-11-20 共享纪念园增量

- 新增 ParkController，复用已有 /api/petmemorial/** 路由放行；仅更新这个新类。
- 新表 pet_memorial_plot，plot_id 主键、owner_hash 唯一索引，48 个位置，单身份一座。
- 公开字段为 name/story/photo；不查询私密备份 payload。
- 最终部署备份：/home/repo/bootdo/target/bootdo-1.7.0.jar.pre-petmemorial-20261120-213045。
- 首次增量前备份（撤回整个共享接口用）：/home/repo/bootdo/target/bootdo-1.7.0.jar.pre-petmemorial-20261120-212337。
- 启动 PID 3680111；沿用 Xmx700m、SerialGC。启动后可用内存 868 MB，后续检查 856 MB。
- 线上双钥匙并发认领、迁移、失败迁移保留原碑位、重新认领和释放均通过；临时数据已清理。
- login、VIP products、sounds、petmemorial health 均 HTTP 200。
- 迁移并发检查发现现有 Druid 在 duplicate key 后复用已关闭 PreparedStatement；新接口写操作独立创建/关闭语句修复，不更改其他业务连接池行为。

- 客户端最终验证：6 项单元测试 + 1 项 UI 流程通过。UI 覆盖已认领详情、献花、点灯、释放、摇杆实际坐标变化、横图/竖图完整边框显示。
- 截图：docs/screenshots/park.png、album.png。
- 真机 Debug 构建通过，已安装至已连接 iPhone（cn.cjym.petmemorial）。

## 2026-11-20 账号登录与游客关联

- 复用原有手机号登录接口和 AppAccessTokenService / AppUserDao；未修改原有认证控制器。
- 新增 MemorialAccountController、MemorialIdentityService，独立表 pet_memorial_account。
- 私密备份及碑位接口可通过 X-App-Token 解析后台用户 ID；匿名流程保留，已绑定钥匙匿名访问返回 401，令牌失效不会回退匿名权限。
- 账号已有映射时不覆盖；跨设备通过同一用户 ID 取原归属。用户注销后校验用户不存在，旧令牌无权读取。
- 回滚包：/home/repo/bootdo/target/bootdo-1.7.0.jar.pre-petmemorial-20261120-215401。上线 PID 3742025，启动后可用内存 865 MB，后续 847 MB。
- 服务端 15 项测试通过，客户端 12 项单元测试和登录 UI 测试通过。真机 Debug 构建通过。
- 线上使用临时合成用户及短期令牌验证绑定、私密隔离、跨设备归属、重复登录不覆盖；所有临时用户、令牌和业务数据已删除。
- 原匿名并发认领、迁移和释放复测通过。登录页面、会员商品、声音、纪念园健康检查均 HTTP 200。
- 验证码/密码请求通过 URLProtocol 测试验证接口和响应解析；未向真实手机号发送短信，实际短信运营商送达未做验证。
- 私密备份未开启时，登录不自动上传相册或信件；更换设备需事先主动开启云备份。

## 2026-11-23 Community and companion features

- Implemented pet follow/pet/sit/walk, flower/candle visits, search/favorites/navigation, share card/public page, annual local reminders.
- Deployed only MemorialCommunityController and ParkController; three independent tables. Existing login, membership and AI handlers unchanged.
- Local compilation, incremental deployment, one JVM Xmx700m; startup 47 seconds, available memory after verification 843 MB.
- Rollback: /home/repo/bootdo/target/bootdo-1.7.0.jar.pre-petmemorial-20261123-101853.
- Passed 20 backend tests, 15 client unit tests, end-to-end five-feature UI test and notification permission UI test. Actual pending notification creation/cancellation verified.
- Live checks passed for concurrent tribute deduplication, owner-only visit logs, favorites isolation, stable moved links, released link revocation and new-occupant isolation. Temporary QA monuments and interactions cleaned up.
- Existing login, VIP products, sounds and memorial health endpoints returned HTTP 200.
- Public page only exposes published name/photo/story and counts; private letters remain private. Safari rendering inspected.
- Annual reminders opt-in, local 09:00, Feb 29 observed Feb 28; logout cancels pending reminders.
- Final device build succeeded and installed on connected iPhone without uninstalling or deleting existing data.
- Screenshots: docs/screenshots/{favorites,share-card,tributes,pet-companion,anniversaries}.png.
