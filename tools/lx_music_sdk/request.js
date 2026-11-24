import { Buffer } from 'buffer'

const pending = new Map()
let nextKey = 0
const defaultHeaders = {
  Accept: 'application/json',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
}
const headerNames = new Map([
  ['accept', 'Accept'],
  ['user-agent', 'User-Agent'],
  ['content-type', 'Content-Type'],
])

export function httpFetch(url, {
  method = 'GET', headers = {}, body, form, formData, timeout = 15000, binary = false,
} = {}) {
  const merged = { ...defaultHeaders }
  for (const [key, value] of Object.entries(headers)) {
    merged[headerNames.get(key.toLowerCase()) ?? key] = value
  }
  headers = merged
  method = method.toUpperCase()
  if (form != null) {
    headers['Content-Type'] ??= 'application/x-www-form-urlencoded'
    body = Object.entries(form).map(([key, value]) => (
      `${encodeURIComponent(key)}=${encodeURIComponent(value)}`
    )).join('&')
  } else if (formData == null && (method === 'POST' || body != null)) {
    headers['Content-Type'] ??= 'application/json'
    if (/^application\/json(?:\s*;|$)/i.test(headers['Content-Type']) && body != null && typeof body !== 'string') {
      body = JSON.stringify(body)
    }
  }

  const requestKey = String(++nextKey)
  const promise = new Promise((resolve, reject) => {
    const data = JSON.stringify({ requestKey, url, options: { method, headers, body, formData, timeout, binary } })
    pending.set(requestKey, { resolve, reject })
    try {
      globalThis.__lx_sdk_call__('request', data)
    } catch (error) {
      pending.delete(requestKey)
      reject(error)
    }
  })
  return {
    promise,
    cancelHttp() {
      const request = pending.get(requestKey)
      if (!request) return
      pending.delete(requestKey)
      request.reject(new Error('Request cancelled'))
      globalThis.__lx_sdk_call__('cancelRequest', JSON.stringify(requestKey))
    },
  }
}

export function httpGet(url, options, callback) {
  if (typeof options === 'function') {
    callback = options
    options = {}
  }
  const { promise, cancelHttp } = httpFetch(url, { ...options, method: 'GET' })
  promise.then(response => callback(null, response, response.body), error => callback(error, null, null))
  return cancelHttp
}

function parseText(body) {
  try {
    return JSON.parse(body)
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error
    // Several upstream endpoints return plain text even with Accept: application/json.
    return body
  }
}

export function handleResponse({ requestKey, error, response }) {
  const request = pending.get(requestKey)
  if (!request) return // A cancelled request can still receive a native response.
  pending.delete(requestKey)
  if (error != null || !response) {
    request.reject(new Error(error ?? 'Missing HTTP response'))
    return
  }
  if (typeof response.body === 'string') {
    response.body = response.binary === true ? Buffer.from(response.body, 'base64') : parseText(response.body)
  }
  request.resolve(response)
}
