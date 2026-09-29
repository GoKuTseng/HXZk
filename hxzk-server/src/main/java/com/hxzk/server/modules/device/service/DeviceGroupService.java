package com.hxzk.server.modules.device.service;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.hxzk.server.common.BizException;
import com.hxzk.server.modules.device.entity.DeviceGroup;
import com.hxzk.server.modules.device.mapper.DeviceGroupMapper;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class DeviceGroupService extends ServiceImpl<DeviceGroupMapper, DeviceGroup> {

    public DeviceGroup create(DeviceGroup group) {
        if (!StringUtils.hasText(group.getName())) {
            throw new BizException("分组名不能为空");
        }
        if (lambdaQuery().eq(DeviceGroup::getName, group.getName()).count() > 0) {
            throw new BizException("分组名已存在：" + group.getName());
        }
        group.setId(null);
        save(group);
        return group;
    }

    public DeviceGroup rename(Long id, String name, String remark, Boolean enabled) {
        DeviceGroup existing = getById(id);
        if (existing == null) {
            throw new BizException("分组不存在：" + id);
        }
        if (StringUtils.hasText(name) && !name.equals(existing.getName())
                && lambdaQuery().eq(DeviceGroup::getName, name).count() > 0) {
            throw new BizException("分组名已存在：" + name);
        }
        if (StringUtils.hasText(name)) {
            existing.setName(name);
        }
        if (remark != null) {
            existing.setRemark(remark);
        }
        if (enabled != null) {
            existing.setEnabled(enabled);
        }
        updateById(existing);
        return existing;
    }
}
