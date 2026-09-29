package com.hxzk.server.modules.device.controller;

import com.hxzk.server.common.Result;
import com.hxzk.server.modules.device.entity.DeviceGroup;
import com.hxzk.server.modules.device.service.DeviceGroupService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/groups")
public class DeviceGroupController {

    private final DeviceGroupService groupService;

    public DeviceGroupController(DeviceGroupService groupService) {
        this.groupService = groupService;
    }

    @GetMapping
    public Result<List<DeviceGroup>> list() {
        return Result.ok(groupService.lambdaQuery().orderByAsc(DeviceGroup::getId).list());
    }

    @PostMapping
    public Result<DeviceGroup> create(@RequestBody DeviceGroup group) {
        return Result.ok(groupService.create(group));
    }

    @PutMapping("/{id}")
    public Result<DeviceGroup> update(@PathVariable Long id, @RequestBody DeviceGroup group) {
        return Result.ok(groupService.rename(id, group.getName(), group.getRemark(), group.getEnabled()));
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@PathVariable Long id) {
        groupService.removeById(id);
        return Result.ok();
    }
}
