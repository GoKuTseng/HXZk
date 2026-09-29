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
- **M1 地基：待启动** —— 工程骨架（WinSW 服务化、CI 打包）→ 设备 CRUD + 分组 → 1 台终端 Pull 流水入库 → 单个用户（工号/姓名/人脸）下发可查 → Push/RegEvent 实时最小链路 → 人员接收 API 先收数据入库

## 网关读取红线（M0 血泪结论）

新固件（FW "Ver 6.60" 系，实测 11.5 / 12.4）记录为 **49B 格式**，**必须 TFT 配对**：
`ReadTimeGLogData`（窗口）/ `ReadGeneralLogData`（全量）+ `SSR_GetGeneralLogData(String 工号)`。
格式自检判定式：`total_size ÷ records == 49.00`。旧配对 `GetGeneralLogDataStr(Int32)` 一律禁止用于新固件。
