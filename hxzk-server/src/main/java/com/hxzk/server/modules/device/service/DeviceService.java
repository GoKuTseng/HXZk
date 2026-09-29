package com.hxzk.server.modules.device.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.hxzk.server.common.BizException;
import com.hxzk.server.modules.device.entity.Device;
import com.hxzk.server.modules.device.mapper.DeviceMapper;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class DeviceService extends ServiceImpl<DeviceMapper, Device> {

    public Page<Device> page(long page, long size, String factory, String deviceType,
                             String keyword, Boolean onlyAbnormal) {
        LambdaQueryWrapper<Device> qw = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(factory)) {
            qw.eq(Device::getFactory, factory);
        }
        if (StringUtils.hasText(deviceType)) {
            qw.eq(Device::getDeviceType, deviceType);
        }
        if (StringUtils.hasText(keyword)) {
            qw.and(w -> w.like(Device::getName, keyword)
                    .or().like(Device::getIp, keyword)
                    .or().like(Device::getSn, keyword));
        }
        if (Boolean.TRUE.equals(onlyAbnormal)) {
            qw.and(w -> w.isNotNull(Device::getAbnormalFlag).ne(Device::getAbnormalFlag, "")
                    .or().eq(Device::getNeedsReplace, true));
        }
        qw.orderByAsc(Device::getFactory).orderByAsc(Device::getIp);
        return page(new Page<>(page, size), qw);
    }

    public Device create(Device device) {
        assertUnique(null, device.getSn(), device.getIp(), device.getPort());
        device.setId(null);
        if (device.getPort() == null) {
            device.setPort(4370);
        }
        if (!StringUtils.hasText(device.getRealtimeMode())) {
            device.setRealtimeMode("poll");
        }
        if (!StringUtils.hasText(device.getGatewayInstance())) {
            device.setGatewayInstance("gw-1");
        }
        save(device);
        return device;
    }

    public Device update(Long id, Device patch) {
        Device existing = getById(id);
        if (existing == null) {
            throw new BizException("设备不存在：" + id);
        }
        assertUnique(id, patch.getSn(), patch.getIp(), patch.getPort());
        patch.setId(id);
        // 不开放在线状态/心跳的随意改写，由网关回写
        patch.setOnline(null);
        patch.setLastHeartbeat(null);
        updateById(patch);
        return getById(id);
    }

    public void remove(Long id) {
        if (getById(id) == null) {
            throw new BizException("设备不存在：" + id);
        }
        // 物理删除：M1 台账管理期允许；接入流水后应改停用（流水外键不清）
        removeById(id);
    }

    private void assertUnique(Long excludeId, String sn, String ip, Integer port) {
        if (StringUtils.hasText(sn)) {
            Long cnt = lambdaQuery().eq(Device::getSn, sn)
                    .ne(excludeId != null, Device::getId, excludeId).count();
            if (cnt > 0) {
                throw new BizException("SN 已存在：" + sn);
            }
        }
        if (StringUtils.hasText(ip)) {
            Long cnt = lambdaQuery().eq(Device::getIp, ip)
                    .eq(Device::getPort, port == null ? 4370 : port)
                    .ne(excludeId != null, Device::getId, excludeId).count();
            if (cnt > 0) {
                throw new BizException("IP+端口 已存在：" + ip + ":" + (port == null ? 4370 : port));
            }
        }
    }
}
