package com.hxzk.server.modules.device.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.hxzk.server.common.Result;
import com.hxzk.server.modules.device.entity.Device;
import com.hxzk.server.modules.device.service.DeviceService;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.constraints.Max;
import javax.validation.constraints.Min;

@RestController
@RequestMapping("/api/devices")
public class DeviceController {

    private final DeviceService deviceService;

    public DeviceController(DeviceService deviceService) {
        this.deviceService = deviceService;
    }

    @GetMapping
    public Result<Page<Device>> page(
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(200) long size,
            @RequestParam(required = false) String factory,
            @RequestParam(required = false) String deviceType,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Boolean onlyAbnormal) {
        return Result.ok(deviceService.page(page, size, factory, deviceType, keyword, onlyAbnormal));
    }

    @PostMapping
    public Result<Device> create(@RequestBody Device device) {
        return Result.ok(deviceService.create(device));
    }

    @PutMapping("/{id}")
    public Result<Device> update(@PathVariable Long id, @RequestBody Device device) {
        return Result.ok(deviceService.update(id, device));
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@PathVariable Long id) {
        deviceService.remove(id);
        return Result.ok();
    }
}
