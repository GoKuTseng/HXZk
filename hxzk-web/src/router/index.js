import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    component: () => import('../layout/MainLayout.vue'),
    redirect: '/device',
    children: [
      { path: 'device', name: 'DeviceManage', component: () => import('../views/device/DeviceList.vue'), meta: { title: '设备管理' } },
      { path: 'punch', name: 'PunchQuery', component: () => import('../views/punch/PunchQuery.vue'), meta: { title: '打卡记录' } }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.afterEach((to) => {
  document.title = (to.meta.title ? to.meta.title + ' - ' : '') + '华新门禁考勤管理平台'
})

export default router
