<template>
  <el-container style="height: 100%">
    <el-aside width="220px">
      <el-menu :default-active="$route.path" router style="height: 100%">
        <div class="logo">华新门禁考勤</div>
        <el-menu-item index="/device">
          <el-icon><Monitor /></el-icon>
          <span>设备管理</span>
        </el-menu-item>
        <el-menu-item index="/punch">
          <el-icon><Clock /></el-icon>
          <span>打卡记录</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <span>{{ $route.meta.title || '' }}</span>
      </el-header>
      <el-main>
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
</script>

<style scoped>
.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  color: #303133;
  border-bottom: 1px solid #e4e7ed;
}
.header {
  display: flex;
  align-items: center;
  font-size: 16px;
  font-weight: 600;
  border-bottom: 1px solid #e4e7ed;
}
</style>
