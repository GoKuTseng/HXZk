# HXZk — 中控门禁考勤终端管理系统

> 规划与架构唯一事实源：`../门禁考勤系统-规划与架构.md`（选型决策、里程碑 M0~M4、许可证纪律均在其中）
> 真机探测记录：`../m0-probe/`（M0 已完成：6 台实机、四种型号全覆盖）

## 技术栈（已定）

- **hxzk-server**（业务平台）：Java 8 + Spring Boot 2.7 + MyBatis-Plus，内嵌 Tomcat
- **hxzk-gateway**（设备网关）：.NET 8 Worker —— zh9 COM Interop（Pull/事件）+ iclock/ADMS HTTP 端点（Push）双驱动；Windows x64；COM 实例与 worker 1:1
- **hxzk-web**（前端）：Vue 3 + Element Plus
- 存储/中间件：MySQL + Memurai（Redis 协议）+ RabbitMQ；Windows Server 2019 单机部署，WinSW 服务化

## 目录

- `hxzk-server/` — Java 业务平台（设备 CRUD/分组、人员、策略、记录、OpenAPI、泛微对接）
- `hxzk-gateway/` — .NET 设备网关（设备连接池、双驱动采集、下发、协议适配、数据净化）
- `hxzk-web/` — 前端
- `deploy/` — WinSW 服务化、CI 打包、安装脚本
- `database/` — DDL 与迁移脚本
- `docs/` — 设计文档与里程碑记录

## 当前状态

- **M0 真机可行性验证：✅ 完成**（2026-09-29，6 台实机/四种型号全覆盖；当晚根因修订：读取 API 配对错误坐实，详见 `../m0-probe/M0-实时通道探测记录.md`）
- **M1 地基：进行中**（2026-09-29 启动，本机开发、可视化优先）

M1 进度：

- [x] M1-2 主库 DDL（`database/schema-mysql8.sql`，MySQL 8.0，打卡/门禁月分区）
- [x] M1-3 hxzk-server 骨架（Boot 2.7.18 + MyBatis-Plus 3.5.7，统一返回体/异常/分页，编译通过）
- [x] M1-4 hxzk-web 骨架（Vite + Vue3 + Element Plus，构建通过）
- [x] M1-5 设备台账导入种子（`database/seed-device.sql`，43 台幂等 UPSERT）+ 设备/分组 CRUD API（编译通过，待 MySQL 连通后冒烟）
- [x] M1-6 设备管理页（第一屏：筛选/异常高亮/CRUD 对话框/分组管理，构建通过）
- [ ] M1-7 网关骨架 + TFT 配对读取（待 .NET 8 SDK）
- [ ] M1-8 单台 Pull 流水入库 + 记录查询页
- [ ] M1-9 人员接收 API（契约已定）+ M1-10 单用户下发 + M1-11 实时最小链路

本地运行：

- 数据库：先执行 `database/schema-mysql8.sql` 再执行 `database/seed-device.sql`
- 服务端：`hxzk-server/`，`mvn spring-boot:run`，默认 8080；真实口令放 `application-local.yml`（已 gitignore，模板见 `application-local.yml.example`）
- 前端：`hxzk-web/`，`npm install && npm run dev`，5173 端口已配 `/api` 代理到 8080

## 网关读取红线（M0 血泪结论）

新固件（FW "Ver 6.60" 系，实测 11.5 / 12.4）记录为 **49B 格式**，**必须 TFT 配对**：
`ReadTimeGLogData`（窗口）/ `ReadGeneralLogData`（全量）+ `SSR_GetGeneralLogData(String 工号)`。
格式自检判定式：`total_size ÷ records == 49.00`。旧配对 `GetGeneralLogDataStr(Int32)` 一律禁止用于新固件。
