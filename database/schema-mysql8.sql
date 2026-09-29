-- ============================================================================
-- HXZk 门禁考勤管理系统 — 主库 DDL（MySQL 8.0）
-- ----------------------------------------------------------------------------
-- 依据：《门禁考勤系统-规划与架构.md》3.3 关键数据模型（V2）+ 设备台账 + 泛微人员接口契约
-- 约定：utf8mb4 / InnoDB；命名 snake_case；工号列统一 emp_no（接口契约中的 pin）
-- 分区策略：punch_log / access_event 按 punch_time/event_time 月分区（RANGE COLUMNS），
--           由例行 Job 每月提前加分区、归档 N 月前数据（见规划 3.4 容量段）。
-- 考勤中间表 attendance_staging 不建在本库——按 2026-09-29 决策直接建在泛微 OA 库，
--           DDL 待泛微提供，本文件仅建出数 Job 幂等水位 staging_watermark。
-- ============================================================================

CREATE DATABASE IF NOT EXISTS hxzk DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE hxzk;

-- ----------------------------------------------------------------------------
-- 设备与分组
-- ----------------------------------------------------------------------------

CREATE TABLE device_group (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(64)  NOT NULL COMMENT '分组名（全库唯一，接口契约 accGroups 精确匹配此列）',
  parent_id   BIGINT UNSIGNED NULL COMMENT '预留：多级分组',
  remark      VARCHAR(255) NULL,
  enabled     TINYINT(1) NOT NULL DEFAULT 1,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_group_name (name)
) ENGINE=InnoDB COMMENT='设备分组（厂别作为顶层分组维度导入，可再自定义）';

CREATE TABLE device (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sn               VARCHAR(64)  NOT NULL COMMENT '设备序列号（去重键 device_sn 用；未知可先填 IP 占位，联调回填）',
  name             VARCHAR(128) NOT NULL COMMENT '台账"考勤名称"',
  factory          VARCHAR(32)  NOT NULL COMMENT '厂别：废水站/老厂/C厂/E厂/集团/新厂',
  location         VARCHAR(128) NULL COMMENT '安装位置备注',
  model            VARCHAR(32)  NOT NULL COMMENT '机型：xFace500/xFace600/XF600/iClock360/TDB08(PRO)',
  device_type      VARCHAR(8)   NOT NULL COMMENT '考勤 / 门禁 —— 仅 考勤 流水进中间表',
  ip               VARCHAR(15)  NOT NULL,
  port             INT          NOT NULL DEFAULT 4370,
  firmware         VARCHAR(64)  NULL COMMENT '设备读回固件串（两套编号体系，以读回为准）',
  realtime_mode    VARCHAR(8)   NOT NULL DEFAULT 'poll' COMMENT 'push | event | poll（M0 终判回填；可实时+轮询并存）',
  gateway_instance VARCHAR(32)  NOT NULL DEFAULT 'gw-1' COMMENT '网关分片归属（单机固定 gw-1，扩机时用）',
  group_id         BIGINT UNSIGNED NULL COMMENT '所属分组（厂别分组或自定义）',
  enabled          TINYINT(1) NOT NULL DEFAULT 1 COMMENT '停用即网关不下发不拉取',
  abnormal_flag    VARCHAR(255) NULL COMMENT '台账异常标记原文：暂无法连接/需更换门禁机/自报IP待核 等',
  needs_replace    TINYINT(1) NOT NULL DEFAULT 0 COMMENT '台账标记"需更换门禁机"',
  caps_json        JSON         NULL COMMENT '能力档案：49B/TFT配对/BIOPHOTO/RegEvent/Push 实测结论（M0 矩阵）',
  online           TINYINT(1) NOT NULL DEFAULT 0,
  last_heartbeat   DATETIME NULL,
  remark           VARCHAR(255) NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_sn (sn),
  UNIQUE KEY uk_ip_port (ip, port),
  KEY idx_factory (factory),
  KEY idx_group (group_id),
  KEY idx_type (device_type)
) ENGINE=InnoDB COMMENT='终端设备档案（由台账导入，CRUD 维护）';

CREATE TABLE device_group_member (
  id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  device_id BIGINT UNSIGNED NOT NULL,
  group_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_member (device_id, group_id),
  CONSTRAINT fk_dgm_device FOREIGN KEY (device_id) REFERENCES device (id) ON DELETE CASCADE,
  CONSTRAINT fk_dgm_group  FOREIGN KEY (group_id)  REFERENCES device_group (id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='设备-分组多对多';

-- ----------------------------------------------------------------------------
-- 人员（泛微为主来源；接口契约见 HXZk/docs/人员接口文档提取.txt）
-- ----------------------------------------------------------------------------

CREATE TABLE hr_employee_raw (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  emp_no        VARCHAR(32)  NOT NULL COMMENT 'pin 工号',
  payload_json  JSON         NOT NULL COMMENT '入站原文（不可变留痕）',
  source_batch  VARCHAR(64)  NOT NULL COMMENT '来源批次（requestId 或我方 batchNo）',
  event_type    VARCHAR(16)  NOT NULL COMMENT 'sync | remove',
  received_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_raw_emp (emp_no),
  KEY idx_raw_batch (source_batch)
) ENGINE=InnoDB COMMENT='泛微推送入站留痕，不可变';

CREATE TABLE employee (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  emp_no       VARCHAR(32) NOT NULL COMMENT 'pin，平台唯一键（也是设备用户号）',
  name         VARCHAR(64) NOT NULL,
  oa_user_id   VARCHAR(64) NULL COMMENT '泛微用户唯一 ID（建唯一索引映射）',
  dept         VARCHAR(128) NULL COMMENT '部门（中文直传）',
  position     VARCHAR(128) NULL COMMENT '岗位（中文直传；契约暂缺字段，预留）',
  card_no      VARCHAR(32) NULL COMMENT '卡号（本期不使用，契约字段保留）',
  status       VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE 在职 / RESIGNED 离职（离职=清组+设备端禁用）',
  pri          INT NOT NULL DEFAULT 0 COMMENT '设备用户权限：0=普通',
  photo_path   VARCHAR(255) NULL COMMENT '人脸注册照平台存储路径（契约 photo Base64 JPG≤500KB，不合规丢弃不拦入库）',
  photo_ver    INT NOT NULL DEFAULT 0 COMMENT '照片版本，下发比对用',
  source_ver   VARCHAR(32) NULL COMMENT '来源版本戳（重推比对，可选）',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_emp_no (emp_no),
  UNIQUE KEY uk_oa_user (oa_user_id)
) ENGINE=InnoDB COMMENT='人员平台投影（pin 幂等 upsert）';

CREATE TABLE biometric_face (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  emp_no      VARCHAR(32) NOT NULL,
  ref         VARCHAR(255) NOT NULL COMMENT '模板或照片引用（文件服务 URL / 模板存储路径）',
  gen_route   VARCHAR(16) NOT NULL COMMENT 'ADMS照片(BIOPHOTO) / 引擎模板',
  version     INT NOT NULL DEFAULT 1,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_face_emp (emp_no)
) ENGINE=InnoDB COMMENT='人脸模板/照片多版本存档；BIOPHOTO 真机窗口裁决后启用';

-- ----------------------------------------------------------------------------
-- 下发任务中心（M1-10 起用；时段验证类 type 为 M2）
-- ----------------------------------------------------------------------------

CREATE TABLE sync_task (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  type          VARCHAR(16) NOT NULL COMMENT 'user_add/user_upd/user_del/face/rungroup/verifygroup/time',
  device_id     BIGINT UNSIGNED NOT NULL,
  emp_no        VARCHAR(32) NULL COMMENT '人员类任务必填',
  payload_json  JSON NULL,
  state         VARCHAR(16) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/SENT/OK/FAILED/DEAD',
  retry_cnt     INT NOT NULL DEFAULT 0,
  next_retry_at DATETIME NULL COMMENT '指数退避下次重试时间',
  err           TEXT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_task_state (state, next_retry_at),
  KEY idx_task_emp (emp_no, device_id),
  KEY idx_task_device (device_id, state)
) ENGINE=InnoDB COMMENT='统一下发队列：状态机+退避重试+死信人工处理';

CREATE TABLE sync_device_state (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  emp_no      VARCHAR(32) NOT NULL,
  device_id   BIGINT UNSIGNED NOT NULL,
  state       VARCHAR(16) NOT NULL DEFAULT 'PENDING' COMMENT '该人在该终端的最新下发态：PENDING/OK/FAILED',
  last_ok_at  DATETIME NULL,
  err         TEXT NULL,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_emp_device (emp_no, device_id)
) ENGINE=InnoDB COMMENT='派生表：sync_task 完成时回写，供 /api/persons/sync-status 快速查询';

-- ----------------------------------------------------------------------------
-- 采集水位与流水（去重键 device_sn+emp_no+punch_time+verify_mode；source 标记通道）
-- ----------------------------------------------------------------------------

CREATE TABLE device_watermark (
  device_id       BIGINT UNSIGNED NOT NULL,
  last_punch_sn   BIGINT UNSIGNED NULL COMMENT '终端流水号水位（Push 报文携带时优先）',
  last_punch_time DATETIME NULL COMMENT '增量拉取水位',
  last_event_sn   BIGINT UNSIGNED NULL,
  last_sync_at    DATETIME NULL COMMENT '上次成功对账/拉取时间',
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (device_id)
) ENGINE=InnoDB COMMENT='每设备增量水位（断连窗口补拉 + 轮询对账用）';

CREATE TABLE punch_log (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  device_sn   VARCHAR(64) NOT NULL,
  device_id   BIGINT UNSIGNED NULL COMMENT '冗余 device.id（sn 为主键维度，id 便于关联；设备删档不清流水）',
  emp_no      VARCHAR(32) NOT NULL COMMENT '工号（SSR_GetGeneralLogData 读出的工号）',
  punch_time  DATETIME NOT NULL,
  verify_mode TINYINT UNSIGNED NULL COMMENT '验证方式原始码（人脸/指纹/密码…）',
  in_out      TINYINT UNSIGNED NULL COMMENT '进出标志原始码（如终端提供）',
  record_sn   BIGINT UNSIGNED NULL COMMENT '终端流水号（去重优先键；无则退唯一键）',
  source      VARCHAR(8) NOT NULL COMMENT 'push | event | pull —— 双通道同源只落一条，此列供对账统计',
  raw_json    JSON NULL COMMENT '原始报文（通道差异对账用）',
  received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id, punch_time),
  UNIQUE KEY uk_dedup (device_sn, emp_no, punch_time, verify_mode),
  KEY idx_emp_time (emp_no, punch_time),
  KEY idx_device_time (device_sn, punch_time),
  KEY idx_received (received_at)
) ENGINE=InnoDB COMMENT='打卡流水（考勤+门禁的通行记录），按月分区'
PARTITION BY RANGE COLUMNS(punch_time) (
  PARTITION p202609 VALUES LESS THAN ('2026-10-01'),
  PARTITION p202610 VALUES LESS THAN ('2026-11-01'),
  PARTITION p202611 VALUES LESS THAN ('2026-12-01'),
  PARTITION p202612 VALUES LESS THAN ('2027-01-01'),
  PARTITION pmax    VALUES LESS THAN (MAXVALUE)
);

CREATE TABLE access_event (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  device_sn   VARCHAR(64) NOT NULL,
  device_id   BIGINT UNSIGNED NULL,
  emp_no      VARCHAR(32) NULL COMMENT '门禁事件可能无用户（门磁/报警）',
  event_time  DATETIME NOT NULL,
  event_code  INT UNSIGNED NULL COMMENT '事件码原始值',
  status      TINYINT NULL COMMENT '门状态/结果原始值',
  photo       VARCHAR(255) NULL COMMENT '终端回传抓拍图引用（若有）',
  source      VARCHAR(8) NOT NULL,
  raw_json    JSON NULL,
  received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id, event_time),
  KEY idx_ae_device_time (device_sn, event_time),
  KEY idx_ae_emp (emp_no, event_time)
) ENGINE=InnoDB COMMENT='门禁事件（按天分区粒度同 punch_log，月分区便于同一 Job 维护）'
PARTITION BY RANGE COLUMNS(event_time) (
  PARTITION p202609 VALUES LESS THAN ('2026-10-01'),
  PARTITION p202610 VALUES LESS THAN ('2026-11-01'),
  PARTITION p202611 VALUES LESS THAN ('2026-12-01'),
  PARTITION p202612 VALUES LESS THAN ('2027-01-01'),
  PARTITION pmax    VALUES LESS THAN (MAXVALUE)
);

-- ----------------------------------------------------------------------------
-- 考勤中间表出数 Job 幂等水位（中间表本体建在泛微库，DDL 待泛微提供）
-- ----------------------------------------------------------------------------

CREATE TABLE staging_watermark (
  job_name   VARCHAR(64) NOT NULL COMMENT '如 attendance_staging',
  last_log_id BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '已出数到的 punch_log.id 水位',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (job_name)
) ENGINE=InnoDB COMMENT='出数 Job 幂等：重跑不重插';

-- ----------------------------------------------------------------------------
-- 回执与审计（delivery_receipt M4 回执方式 B 启用；op_audit 平台操作留痕）
-- ----------------------------------------------------------------------------

CREATE TABLE delivery_receipt (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id      VARCHAR(64) NOT NULL COMMENT '泛微批次号（幂等键）',
  emp_no        VARCHAR(32) NOT NULL,
  device_id     BIGINT UNSIGNED NOT NULL,
  state         VARCHAR(16) NOT NULL COMMENT 'OK / FAILED',
  fail_reason   TEXT NULL COMMENT '回执必须到人到终端+具体报错',
  callback_state VARCHAR(16) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/OK/FAILED —— 主动回调泛微接收接口',
  retry_cnt     INT NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_batch_emp_dev (batch_id, emp_no, device_id),
  KEY idx_receipt_callback (callback_state)
) ENGINE=InnoDB COMMENT='泛微下发终态回执（方式 B：我方主动回调）';

CREATE TABLE op_audit (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  operator         VARCHAR(64) NOT NULL,
  action           VARCHAR(64) NOT NULL,
  target           VARCHAR(128) NULL,
  before_after_json JSON NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_time (created_at)
) ENGINE=InnoDB COMMENT='平台操作审计';
