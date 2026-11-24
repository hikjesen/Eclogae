import assert from 'node:assert/strict'
import {
  constants, createCipheriv, createDecipheriv, createHash, publicEncrypt,
} from 'node:crypto'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import { deflateSync } from 'node:zlib'

const filename = new URL('../../assets/lx/music-sdk-bundle.js', import.meta.url)
const bundle = new vm.Script(await readFile(filename, 'utf8'), { filename: filename.pathname })
const decode = text => Buffer.from(text, 'base64')
const hash = algorithm => text => createHash(algorithm).update(text, 'utf8').digest('hex')

function aes(create, data, key, iv, mode, output) {
  const cbc = mode === 'AES/CBC/PKCS7Padding'
  assert.ok(cbc || mode === 'AES', `Unexpected AES mode ${mode}`)
  // Android's bare "AES" transformation uses ECB with padding.
  const cipher = create(cbc ? 'aes-128-cbc' : 'aes-128-ecb', decode(key), cbc ? decode(iv) : null)
  return Buffer.concat([cipher.update(decode(data)), cipher.final()]).toString(output)
}

function createRuntime(transport) {
  const requests = new Map()
  const calls = new Map()
  let nextCall = 0
  const dispatch = (action, payload) => context.__lx_sdk_dispatch__(action, JSON.stringify(payload))
  const context = vm.createContext({
    __lx_sdk_call__(action, jsonData) {
      const data = JSON.parse(jsonData)
      switch (action) {
        case 'request': {
          const { requestKey, url, options } = data
          const controller = new AbortController()
          requests.set(requestKey, controller)
          const respond = fields => {
            if (requests.delete(requestKey)) dispatch('response', { requestKey, ...fields })
          }
          Promise.resolve().then(() => transport(url, options, controller.signal)).then(
            response => respond({ response }),
            error => respond({ error: error.message }),
          )
          break
        }
        case 'cancelRequest':
          requests.get(data).abort()
          requests.delete(data)
          break
        case 'rpcResponse':
          calls.get(data.callId)(data)
          calls.delete(data.callId)
          break
        default:
          throw new Error(`Unexpected native action ${action}`)
      }
    },
    __lx_sdk_set_timeout__(id, delay) {
      setTimeout(() => context.__lx_sdk_on_timeout__(id), delay)
    },
    __lx_sdk_md5__: hash('md5'),
    __lx_sdk_sha1__: hash('sha1'),
    __lx_sdk_aes_encrypt__: (...args) => aes(createCipheriv, ...args, 'base64'),
    __lx_sdk_aes_decrypt__: (...args) => aes(createDecipheriv, ...args, 'utf8'),
    __lx_sdk_rsa_encrypt__(data, key, padding) {
      const options = { key: decode(key), format: 'der', type: 'spki' }
      if (padding === 'RSA/ECB/NoPadding') options.padding = constants.RSA_NO_PADDING
      else {
        assert.equal(padding, 'RSA/ECB/OAEPWithSHA1AndMGF1Padding')
        options.padding = constants.RSA_PKCS1_OAEP_PADDING
        options.oaepHash = 'sha1'
      }
      return publicEncrypt(options, decode(data)).toString('base64')
    },
  })
  bundle.runInContext(context)

  return {
    context,
    rpc(method, params) {
      const callId = ++nextCall
      return new Promise((resolve, reject) => {
        const deadline = setTimeout(() => reject(new Error(`${method} received no RPC response`)), 20000)
        calls.set(callId, response => {
          clearTimeout(deadline)
          assert.equal(typeof response.ok, 'boolean')
          if (!response.ok) {
            assert.equal(typeof response.error, 'string')
            assert.doesNotMatch(response.error, /\bis not defined\b|ReferenceError|SyntaxError/)
          }
          resolve(response)
        })
        dispatch('rpc', { callId, method, params })
      })
    },
  }
}

const lrc = '[00:01.000]Smoke test'
const sampleId = '207527604'
const kuwoKey = Buffer.from('yeelion')
const encodedLyric = Buffer.from(lrc)
for (let i = 0; i < encodedLyric.length; i++) encodedLyric[i] ^= kuwoKey[i % kuwoKey.length]
const binaryLyric = Buffer.concat([
  Buffer.from('tp=content\r\n\r\n'),
  deflateSync(encodedLyric.toString('base64')),
]).toString('base64')

let kugouDownloads = 0
let qqLyricRequests = 0
const fixture = createRuntime((url, options) => {
  const { hostname, pathname, searchParams } = new URL(url)
  assert.equal(options.headers.Accept, 'application/json')
  assert.ok(options.headers['User-Agent'])
  switch (hostname) {
    case 'search.kuwo.cn':
      assert.equal(options.method, 'GET')
      assert.equal(searchParams.get('pn'), '0')
      assert.equal(searchParams.get('rn'), '30')
      return { statusCode: 200, body: JSON.stringify({
        TOTAL: '1', SHOW: '1', abslist: [{
          MUSICRID: `MUSIC_${sampleId}`, SONGNAME: 'Smoke &amp; test', ARTIST: 'A&B',
          DURATION: '90', N_MINFO: 'level:p,bitrate:128,format:mp3,size:1mb',
        }],
      }) }
    case 'mlyric.kuwo.cn':
      assert.equal(options.binary, true)
      assert.equal(searchParams.get('rid'), sampleId)
      return { statusCode: 200, binary: true, body: binaryLyric }
    case 'lyrics.kugou.com':
      if (pathname === '/search') {
        return { statusCode: 200, body: { candidates: [{ id: 1, accesskey: 'fixture', krctype: 1 }] } }
      }
      if (++kugouDownloads === 1) return { statusCode: 503 }
      return { statusCode: 200, body: { fmt: 'krc', content: '' } }
    case 'u.y.qq.com':
      assert.equal(options.method, 'POST')
      assert.equal(options.headers['Content-Type'], 'application/json')
      if (pathname.endsWith('/musicu.fcg')) {
        assert.equal(JSON.parse(options.body).req.param.songID, 12)
        qqLyricRequests++
        return { statusCode: 200, body: { code: 1 } }
      }
      assert.equal(JSON.parse(options.body)['music.search.SearchCgiService'].param.query, 'smoke')
      assert.ok(searchParams.get('sign'))
      return { statusCode: 200, body: { code: 0, req: { code: 0, data: { body: { song: { list: [] } }, meta: { sum: 0 } } } } }
    case 'interface3.music.163.com':
      assert.equal(options.method, 'POST')
      assert.equal(options.headers['Content-Type'], 'application/x-www-form-urlencoded')
      assert.match(options.body, /^params=[A-F0-9]+$/)
      return { statusCode: 200, body: { code: 200, lrc: { lyric: lrc } } }
    case 'music.163.com': {
      const form = new URLSearchParams(options.body)
      assert.equal(options.headers['Content-Type'], 'application/x-www-form-urlencoded')
      assert.ok(form.get('params'))
      assert.match(form.get('encSecKey'), /^[0-9a-f]{256}$/)
      return { statusCode: 200, body: { code: 200, songs: [{ al: { picUrl: 'https://example.com/album.jpg' } }] } }
    }
    case 'c.musicapp.migu.cn':
      assert.equal(options.body, 'resourceId=one%20%26%20two')
      return { statusCode: 200, body: { code: '000000', resource: [{
        songId: '12', length: '00:59', albumImgs: [{ img: 'https://example.com/album.jpg' }],
      }] } }
    default:
      throw new Error(`Unexpected fixture request to ${hostname}`)
  }
})

assert.equal(vm.runInContext('typeof __lx_sdk_dispatch__', fixture.context), 'function')
assert.equal(vm.runInContext('Buffer.isBuffer(Buffer.from("f")) && atob(btoa("é")) === "é"', fixture.context), true)
await vm.runInContext(`new Promise(resolve => {
  clearTimeout(setTimeout(() => resolve(false), 0))
  setTimeout(resolve, 0, true)
})`, fixture.context).then(value => assert.equal(value, true))

function resultOf(response) {
  assert.equal(response.ok, true, response.error)
  return response.result
}

const search = resultOf(await fixture.rpc('search', { source: 'kw', keyword: 'smoke' }))
assert.deepEqual({ ...search, list: undefined }, { list: undefined, total: 1, page: 1, limit: 30, allPage: 1 })
assert.equal(search.list[0].name, 'Smoke & test')
assert.equal(search.list[0].singer, 'A、B')
assert.equal(search.list[0]._types['128k'].size, '1MB')
assert.deepEqual(search.list[0].typeUrl, {})
const lyrics = await Promise.all([
  fixture.rpc('getLyric', { source: 'kw', musicInfo: search.list[0] }),
  fixture.rpc('getLyric', { source: 'wy', musicInfo: { songmid: 1 } }),
])
for (const reply of lyrics) {
  const lyric = resultOf(reply)
  assert.deepEqual(Object.keys(lyric), ['lyric', 'tlyric', 'rlyric', 'lxlyric'])
  assert.ok(lyric.lyric.includes(lrc))
}
const pic = resultOf(await fixture.rpc('getPic', { source: 'tx', musicInfo: { albumId: 'sample' } }))
assert.match(pic.picUrl, /T002R500x500M000sample\.jpg$/)
const miguPic = resultOf(await fixture.rpc('getPic', { source: 'mg', musicInfo: { songmid: 'one & two' } }))
assert.equal(miguPic.picUrl, 'https://example.com/album.jpg')
const neteasePic = resultOf(await fixture.rpc('getPic', { source: 'wy', musicInfo: { songmid: 12 } }))
assert.equal(neteasePic.picUrl, 'https://example.com/album.jpg')
assert.deepEqual(resultOf(await fixture.rpc('search', { source: 'tx', keyword: 'smoke' })).list, [])
const emptyKrc = await fixture.rpc('getLyric', { source: 'kg', musicInfo: { name: 'smoke', hash: 'fixture', _interval: 1000 } })
assert.equal(emptyKrc.ok, false)
assert.match(emptyKrc.error, /Empty KRC lyric/)
assert.equal(kugouDownloads, 2)
const qqLyric = await fixture.rpc('getLyric', { source: 'tx', musicInfo: { songId: 12 } })
assert.equal(qqLyric.ok, false)
assert.match(qqLyric.error, /Get lyric failed/)
assert.equal(qqLyricRequests, 4)
assert.match((await fixture.rpc('search', { source: 'bd', keyword: 'smoke' })).error, /Unsupported source/)
console.log('Fixtures passed (search, binary and encrypted lyric requests, artwork, timers, RPC errors).')

const live = createRuntime(async (url, { method, headers, body, timeout, binary }, signal) => {
  const response = await fetch(url, {
    method, headers, body, signal: AbortSignal.any([signal, AbortSignal.timeout(timeout)]),
  }).catch(error => {
    throw new Error(`${new URL(url).hostname}: ${error.cause?.code ?? error.name}`)
  })
  if (!response.ok) throw new Error(`${new URL(url).hostname}: HTTP ${response.status}`)
  return {
    statusCode: response.status, statusMessage: response.statusText, url: response.url,
    headers: Object.fromEntries(response.headers), ok: response.ok, binary,
    body: binary ? Buffer.from(await response.arrayBuffer()).toString('base64') : await response.text(),
  }
})

const source = 'kw'
const liveSearch = await live.rpc('search', { source, keyword: '周杰伦 晴天' })
const liveLyric = await live.rpc('getLyric', {
  source, musicInfo: liveSearch.result?.list[0] ?? { songmid: sampleId },
})
for (const [method, response] of [['search', liveSearch], ['getLyric', liveLyric]]) {
  if (response.ok) {
    if (method === 'search') assert.ok(Array.isArray(response.result.list))
    else assert.ok(response.result.lyric.length)
  }
  console.log(`Live ${method} ${JSON.stringify(response.ok ? { callId: response.callId, ok: true } : response)}`)
}
console.log('Bundle evaluated with only the seven native mocks. No missing globals or syntax errors were observed.')
