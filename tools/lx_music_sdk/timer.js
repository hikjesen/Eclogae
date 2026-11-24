const callbacks = new Map()
let nextId = 0

export function setTimeout(callback, delay = 0, ...args) {
  const id = ++nextId
  callbacks.set(id, () => callback(...args))
  globalThis.__lx_sdk_set_timeout__(id, Math.max(0, Number(delay) || 0))
  return id
}

export function clearTimeout(id) {
  callbacks.delete(id)
}

export function onTimeout(id) {
  const callback = callbacks.get(id)
  callbacks.delete(id)
  callback?.()
}

export default { setTimeout, clearTimeout }
