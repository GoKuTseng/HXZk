package com.hxzk.server.modules.device.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("device")
public class Device {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 设备序列号（去重键；未知时以 IP 占位，联调回填） */
    private String sn;

    /** 台账"考勤名称" */
    private String name;

    /** 厂别：废水站/老厂/C厂/E厂/集团/新厂 */
    private String factory;

    private String location;

    private String model;

    /** 考勤 / 门禁 */
    private String deviceType;

    private String ip;

    private Integer port;

    /** 设备读回固件串 */
    private String firmware;

    /** push | event | poll */
    private String realtimeMode;

    private String gatewayInstance;

    private Long groupId;

    private Boolean enabled;

    /** 台账异常标记原文 */
    private String abnormalFlag;

    private Boolean needsReplace;

    /** 能力档案（M0 矩阵实测结论） */
    private String capsJson;

    private Boolean online;

    private LocalDateTime lastHeartbeat;

    private String remark;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
