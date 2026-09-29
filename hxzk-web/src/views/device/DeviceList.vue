<template>
  <div>
    <el-card shadow="never">
      <div class="toolbar">
        <el-select v-model="query.factory" placeholder="厂别" clearable style="width: 120px" @change="load">
          <el-option v-for="f in factories" :key="f" :label="f" :value="f" />
        </el-select>
        <el-select v-model="query.deviceType" placeholder="用途" clearable style="width: 110px" @change="load">
          <el-option label="考勤" value="考勤" />
          <el-option label="门禁" value="门禁" />
        </el-select>
        <el-input v-model="query.keyword" placeholder="名称 / IP / SN" clearable style="width: 200px" @keyup.enter="load" />
        <el-checkbox v-model="query.onlyAbnormal" @change="load">仅看异常</el-checkbox>
        <el-button type="primary" @click="load">查询</el-button>
        <el-button @click="reset">重置</el-button>
        <div class="spacer" />
        <el-button @click="groupDialog = true">分组管理</el-button>
        <el-button type="primary" @click="openEdit(null)">新增设备</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" border stripe style="margin-top: 12px"
                :row-class-name="rowClass">
        <el-table-column prop="factory" label="厂别" width="90" />
        <el-table-column prop="name" label="名称" min-width="180" show-overflow-tooltip />
        <el-table-column prop="ip" label="IP" width="130" />
        <el-table-column prop="port" label="端口" width="70" />
        <el-table-column prop="model" label="机型" width="100" />
        <el-table-column label="用途" width="70">
          <template #default="{ row }">
            <el-tag :type="row.deviceType === '考勤' ? 'success' : 'warning'" size="small">{{ row.deviceType }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag v-if="row.needsReplace" type="danger" size="small">需更换</el-tag>
            <el-tag v-else-if="row.abnormalFlag" type="warning" size="small">异常</el-tag>
            <el-tag v-else type="info" size="small">正常</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="在线" width="70">
          <template #default="{ row }">
            <span :class="row.online ? 'dot ok' : 'dot off'" />
          </template>
        </el-table-column>
        <el-table-column prop="remark" label="备注" min-width="140" show-overflow-tooltip />
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }">
            <el-button size="small" link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-popconfirm title="确认删除该设备？" @confirm="onDelete(row)">
              <template #reference>
                <el-button size="small" link type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination style="margin-top: 12px; justify-content: flex-end"
                     background layout="total, prev, pager, next, sizes"
                     :total="total" v-model:current-page="query.page" v-model:page-size="query.size"
                     :page-sizes="[20, 50, 100]"
                     @current-change="load" @size-change="load" />
    </el-card>

    <!-- 新增/编辑设备 -->
    <el-dialog v-model="editDialog" :title="form.id ? '编辑设备' : '新增设备'" width="560px">
      <el-form :model="form" label-width="90px">
        <el-form-item label="名称" required><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="厂别" required>
          <el-select v-model="form.factory" style="width: 100%">
            <el-option v-for="f in factories" :key="f" :label="f" :value="f" />
          </el-select>
        </el-form-item>
        <el-form-item label="IP" required><el-input v-model="form.ip" /></el-form-item>
        <el-form-item label="端口"><el-input-number v-model="form.port" :min="1" :max="65535" /></el-form-item>
        <el-form-item label="机型">
          <el-select v-model="form.model" filterable allow-create style="width: 100%">
            <el-option v-for="m in models" :key="m" :label="m" :value="m" />
          </el-select>
        </el-form-item>
        <el-form-item label="用途">
          <el-radio-group v-model="form.deviceType">
            <el-radio value="考勤">考勤</el-radio>
            <el-radio value="门禁">门禁</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="SN">
          <el-input v-model="form.sn" placeholder="未知可留空，自动以 IP-xxx 占位" />
        </el-form-item>
        <el-form-item label="分组">
          <el-select v-model="form.groupId" clearable style="width: 100%">
            <el-option v-for="g in groups" :key="g.id" :label="g.name" :value="g.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注"><el-input v-model="form.remark" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="onSave">保存</el-button>
      </template>
    </el-dialog>

    <!-- 分组管理 -->
    <el-dialog v-model="groupDialog" title="分组管理" width="480px">
      <div style="margin-bottom: 10px">
        <el-input v-model="newGroupName" placeholder="新分组名" style="width: 260px" @keyup.enter="onAddGroup" />
        <el-button type="primary" style="margin-left: 8px" @click="onAddGroup">添加</el-button>
      </div>
      <el-table :data="groups" size="small" border>
        <el-table-column prop="name" label="分组名" />
        <el-table-column prop="remark" label="备注" />
        <el-table-column label="操作" width="80">
          <template #default="{ row }">
            <el-popconfirm title="确认删除该分组？" @confirm="onDeleteGroup(row)">
              <template #reference>
                <el-button size="small" link type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { pageDevices, createDevice, updateDevice, removeDevice, listGroups, createGroup, removeGroup } from '../../api/device'

const factories = ['废水站', '老厂', 'C厂', 'E厂', '集团', '新厂']
const models = ['XF500', 'XF600', 'iClock360', 'TDB08 PRO']

const loading = ref(false)
const rows = ref([])
const total = ref(0)
const groups = ref([])
const query = reactive({ page: 1, size: 20, factory: '', deviceType: '', keyword: '', onlyAbnormal: false })

const editDialog = ref(false)
const saving = ref(false)
const emptyForm = () => ({ id: null, name: '', factory: '新厂', ip: '', port: 4370, model: 'XF500', deviceType: '考勤', sn: '', groupId: null, remark: '' })
const form = reactive(emptyForm())

const groupDialog = ref(false)
const newGroupName = ref('')

function rowClass({ row }) {
  return row.needsReplace ? 'row-danger' : row.abnormalFlag ? 'row-warn' : ''
}

async function load() {
  loading.value = true
  try {
    const res = await pageDevices({ ...query })
    rows.value = res.data.records
    total.value = res.data.total
  } finally {
    loading.value = false
  }
}

function reset() {
  Object.assign(query, { page: 1, factory: '', deviceType: '', keyword: '', onlyAbnormal: false })
  load()
}

async function loadGroups() {
  const res = await listGroups()
  groups.value = res.data
}

function openEdit(row) {
  Object.assign(form, emptyForm(), row ? { ...row } : {})
  editDialog.value = true
}

async function onSave() {
  if (!form.name || !form.ip) {
    ElMessage.warning('名称与 IP 必填')
    return
  }
  saving.value = true
  try {
    if (form.id) {
      await updateDevice(form.id, { ...form })
    } else {
      await createDevice({ ...form, id: undefined })
    }
    ElMessage.success('已保存')
    editDialog.value = false
    load()
  } finally {
    saving.value = false
  }
}

async function onDelete(row) {
  await removeDevice(row.id)
  ElMessage.success('已删除')
  load()
}

async function onAddGroup() {
  if (!newGroupName.value.trim()) return
  await createGroup({ name: newGroupName.value.trim() })
  newGroupName.value = ''
  loadGroups()
  ElMessage.success('已添加')
}

async function onDeleteGroup(row) {
  await removeGroup(row.id)
  loadGroups()
  ElMessage.success('已删除')
}

onMounted(() => {
  load()
  loadGroups()
})
</script>

<style scoped>
.toolbar { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.spacer { flex: 1; }
.dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; }
.dot.ok { background: #67c23a; }
.dot.off { background: #c0c4cc; }
:deep(.row-danger) { background: #fef0f0 !important; }
:deep(.row-warn) { background: #fdf6ec !important; }
</style>
