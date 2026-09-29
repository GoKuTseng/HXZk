import request from './request'

export function pageDevices(params) {
  return request.get('/devices', { params })
}

export function createDevice(data) {
  return request.post('/devices', data)
}

export function updateDevice(id, data) {
  return request.put(`/devices/${id}`, data)
}

export function removeDevice(id) {
  return request.delete(`/devices/${id}`)
}

export function listGroups() {
  return request.get('/groups')
}

export function createGroup(data) {
  return request.post('/groups', data)
}

export function updateGroup(id, data) {
  return request.put(`/groups/${id}`, data)
}

export function removeGroup(id) {
  return request.delete(`/groups/${id}`)
}
