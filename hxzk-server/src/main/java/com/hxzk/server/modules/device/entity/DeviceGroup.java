package com.hxzk.server.modules.device.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("device_group")
public class DeviceGroup {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 分组名（全库唯一，accGroups 精确匹配） */
    private String name;

    private Long parentId;

    private String remark;

    private Boolean enabled;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
