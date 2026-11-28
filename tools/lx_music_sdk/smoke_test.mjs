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
let qqDetailRequests = 0
const neteaseDetailCookies = []
let kuwoNodeRequests = 0
let kuwoDigest5Requests = 0
let miguDetailRequests = 0
let miguInfoRequests = 0
const playlistId = 2858093057
const cover = 'https://example.com/playlist.jpg'
const kuwoPlaylistTrack = {
  id: sampleId, name: 'Smoke &amp; test', artist: 'A&B', duration: '90',
  N_MINFO: 'level:p,bitrate:128,format:mp3,size:1mb',
}
const fixture = createRuntime((url, options) => {
  const { hostname, pathname, searchParams } = new URL(url)
  assert.equal(options.headers.Accept, 'application/json')
  assert.ok(options.headers['User-Agent'])
  switch (hostname) {
    case 'tips.kuwo.cn':
      assert.equal(options.method, 'GET')
      assert.equal(options.headers.Referer, 'http://www.kuwo.cn/')
      assert.equal(searchParams.get('w'), 'smoke & test')
      return { statusCode: 200, body: { WORDITEMS: [{ RELWORD: 'smoke' }, { RELWORD: 'smoke test' }] } }
    case 'search.kuwo.cn':
      assert.equal(options.method, 'GET')
      if (searchParams.get('ft') === 'playlist') {
        assert.equal(searchParams.get('all'), 'smoke')
        assert.equal(searchParams.get('pn'), '0')
        assert.equal(searchParams.get('rn'), '20')
        return { statusCode: 200, body: JSON.stringify({
          TOTAL: '42', abslist: [{
            playlistid: playlistId, playcnt: 13200, nickname: 'A&amp;B',
            name: 'Smoke &amp; test', songnum: 1, pic: cover, intro: 'Kuwo playlist',
          }],
        }) }
      }
      if (searchParams.get('stype') === 'albuminfo') {
        assert.equal(searchParams.get('albumid'), '13')
        return { statusCode: 200, body: "{'albumid':'13','name':'Smoke Album','songnum':'0','musiclist':[]}" }
      }
      assert.equal(searchParams.get('pn'), '0')
      assert.equal(searchParams.get('rn'), '30')
      return { statusCode: 200, body: JSON.stringify({
        TOTAL: '1', SHOW: '1', abslist: [{
          MUSICRID: `MUSIC_${sampleId}`, SONGNAME: 'Smoke &amp; test', ARTIST: 'A&B',
          DURATION: '90', N_MINFO: 'level:p,bitrate:128,format:mp3,size:1mb',
        }],
      }) }
    case 'qukudata.kuwo.cn':
      assert.equal(searchParams.get('node'), '5')
      if (++kuwoNodeRequests === 1) return { statusCode: 503, body: {} }
      return { statusCode: 200, body: { child: [{ sourceid: playlistId }] } }
    case 'nplserver.kuwo.cn':
      assert.equal(searchParams.get('pid'), String(playlistId))
      assert.equal(searchParams.get('pn'), '1')
      assert.equal(searchParams.get('rn'), '1000')
      if (searchParams.get('encode') === 'utf-8' && ++kuwoDigest5Requests === 1) {
        return { statusCode: 200, body: { result: 'failed' } }
      }
      return { statusCode: 200, body: {
        result: 'ok', musiclist: [kuwoPlaylistTrack], title: 'Kuwo playlist',
        pic: cover, info: 'Playlist description', uname: 'Kuwo author', playnum: 900,
      } }
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
    case 'c.y.qq.com':
      assert.equal(options.method, 'GET')
      if (pathname.endsWith('/client_music_search_songlist')) {
        assert.equal(searchParams.get('query'), 'smoke')
        assert.equal(searchParams.get('page_no'), '1')
        assert.equal(searchParams.get('num_per_page'), '6')
        return { statusCode: 200, body: { code: 0, data: { sum: '30', list: [{
          listennum: 15000, dissid: 22, creator: { name: 'QQ author' }, dissname: 'QQ playlist',
          createtime: '2025-01-02 12:34:56', imgurl: cover, song_count: 1, introduction: 'One&lt;br&gt;Two',
        }] } } }
      }
      assert.equal(pathname, '/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg')
      assert.equal(searchParams.get('disstid'), '22')
      if (++qqDetailRequests < 3) return { statusCode: 200, body: { code: 1 } }
      return { statusCode: 200, body: { code: 0, subcode: 0, cdlist: [{
        dissname: 'QQ playlist', logo: cover, desc: 'One<br>Two', nickname: 'QQ author', visitnum: 15000,
        songlist: [{
          id: 12, mid: 'qq-track', title: 'QQ track', interval: 61,
          singer: [{ name: 'QQ singer' }], album: { name: 'QQ album', mid: 'qq-album' },
          file: { media_mid: 'qq-media', size_128mp3: 1024, size_320mp3: 0, size_flac: 0, size_hires: 0 },
        }],
      }] } }
    case 'msearchretry.kugou.com':
      assert.equal(pathname, '/api/v3/search/special')
      assert.equal(searchParams.get('keyword'), 'smoke')
      return { statusCode: 200, body: { errcode: 0, data: { total: '1', info: [{
        specialid: 44, specialname: 'Kugou playlist', playcount: 25000, nickname: 'Kugou author',
      }] } } }
    case 'www2.kugou.kugou.com':
      assert.equal(pathname, '/yueku/v9/special/single/44-5-9999.html')
      return { statusCode: 200, body: `global.data = [];\nglobal = { name: "Kugou playlist", pic: "${cover}" };` }
    case 'interface.music.163.com': {
      assert.equal(pathname, '/eapi/batch')
      assert.equal(options.method, 'POST')
      assert.equal(options.headers['Content-Type'], 'application/x-www-form-urlencoded')
      assert.match(options.body, /^params=[A-F0-9]+$/)
      const params = new URLSearchParams(options.body).get('params')
      const decipher = createDecipheriv('aes-128-ecb', 'e82ckenh8dichen8', null)
      const plaintext = decipher.update(params, 'hex', 'utf8') + decipher.final('utf8')
      const [apiPath, payload] = plaintext.split('-36cd479b6b5-')
      const headers = new Headers(options.headers)
      if (apiPath === '/api/cloudsearch/pc') {
        assert.equal(headers.has('cookie'), false)
        return { statusCode: 200, body: { code: 200, result: { playlistCount: '50', playlists: [{
          id: 33, creator: { nickname: 'NetEase author' }, name: 'NetEase playlist',
          playCount: 125000000, coverImgUrl: cover, trackCount: 1, description: 'NetEase description',
        }] } } }
      }
      assert.equal(apiPath, '/api/v3/playlist/detail')
      assert.deepEqual(JSON.parse(payload), { id: '33', n: 100000, s: 8 })
      neteaseDetailCookies.push(headers.get('cookie'))
      return { statusCode: 200, body: { code: 200, playlist: {
        trackIds: [{ id: 24 }],
        tracks: [{ id: 24, name: 'NetEase track', ar: [{ name: 'NetEase singer' }], dt: 70000 }],
        playCount: 125000000, name: 'NetEase playlist', coverImgUrl: cover,
        creator: { nickname: 'NetEase author' }, description: null,
      }, privileges: [{ id: 24, maxbr: 128000 }] } }
    }
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
    case 'jadeite.migu.cn':
      assert.equal(searchParams.get('text'), 'smoke')
      assert.equal(JSON.parse(searchParams.get('searchSwitch')).songlist, 1)
      assert.match(options.headers.sign, /^[a-f0-9]{32}$/i)
      assert.match(options.headers.timestamp, /^\d+$/)
      assert.ok(options.headers.deviceId)
      return { statusCode: 200, body: { code: '000000', data: { songListResultData: {
        totalCount: '1', result: [{ id: '55', name: 'Migu playlist', playNum: '10000' }],
      } } } }
    case 'app.c.nf.migu.cn':
      assert.equal(pathname, '/MIGUM3.0/resource/playlist/song/v2.0')
      assert.equal(searchParams.get('playlistId'), '55')
      assert.equal(searchParams.get('pageNo'), '2')
      miguDetailRequests++
      return { statusCode: 200, body: { code: '000000', data: { songList: [], totalCount: '45' } } }
    case 'c.musicapp.migu.cn':
      if (pathname === '/MIGUM3.0/resource/playlist/v2.0') {
        assert.equal(searchParams.get('playlistId'), '55')
        if (++miguInfoRequests === 1) return { statusCode: 200, body: { code: 'retry' } }
        return { statusCode: 200, body: { code: '000000', data: {
          title: 'Migu playlist', imgItem: { img: cover }, ownerName: 'Migu author', opNumItem: { playNum: 10000 },
        } } }
      }
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

const tips = resultOf(await fixture.rpc('tipSearch', { keyword: 'smoke & test' }))
assert.deepEqual(tips, { list: ['smoke', 'smoke test'] })
assert.match((await fixture.rpc('tipSearch', { keyword: 42 })).error, /tipSearch requires a string keyword/)
assert.match((await fixture.rpc('searchSonglist', { source: 'kw' })).error, /searchSonglist requires a string keyword/)
assert.match((await fixture.rpc('searchSonglist', { source: 'bd', keyword: 'smoke' })).error, /Unsupported source/)
assert.match((await fixture.rpc('getSonglistDetail', { source: 'kw' })).error, /getSonglistDetail requires id/)

const songlistSearches = [
  ['kw', {}, 42, playlistId, 'Smoke & test', '1.3万'],
  ['tx', { page: 2, limit: 6 }, 30, '22', 'QQ playlist', '1.5万'],
  ['wy', {}, 50, '33', 'NetEase playlist', '1.2亿'],
  ['kg', {}, 1, 'id_44', 'Kugou playlist', '2.5万'],
  ['mg', {}, 1, '55', 'Migu playlist', '10000'],
]
for (const [source, params, total, id, name, playCount] of songlistSearches) {
  const result = resultOf(await fixture.rpc('searchSonglist', { source, keyword: 'smoke', ...params }))
  assert.deepEqual({ ...result, list: undefined }, {
    list: undefined, total, page: params.page ?? 1, limit: params.limit ?? 20, source,
  })
  assert.equal(result.list.length, 1)
  const [item] = result.list
  assert.deepEqual([item.id, item.name, item.play_count, item.source], [id, name, playCount, source])
  if (source === 'tx') {
    assert.equal(item.time, '2025-01-02')
    assert.equal(item.desc, 'One\nTwo')
  }
}

const kuwoDetail = resultOf(await fixture.rpc('getSonglistDetail', { source: 'kw', id: playlistId, page: 2 }))
assert.deepEqual({ ...kuwoDetail, list: undefined }, {
  list: undefined, page: 2, limit: 1, total: 1, source: 'kw',
  info: { name: 'Kuwo playlist', img: cover, desc: 'Playlist description', author: 'Kuwo author', play_count: '900' },
})
assert.equal(kuwoDetail.list.length, 1)
assert.equal(kuwoDetail.list[0].songmid, sampleId)
assert.equal(kuwoDetail.list[0].name, 'Smoke & test')
assert.equal(kuwoDetail.list[0].interval, '01:30')
assert.deepEqual(
  resultOf(await fixture.rpc('getSonglistDetail', { source: 'kw', id: 'digest-5__5', page: 2 })),
  kuwoDetail,
)
assert.equal(kuwoNodeRequests, 2)
assert.equal(kuwoDigest5Requests, 2)
const kuwoAlbum = resultOf(await fixture.rpc('getSonglistDetail', { source: 'kw', id: 'digest-13__13' }))
assert.deepEqual(kuwoAlbum, {
  list: [], page: 1, limit: 1000, total: 0, source: 'kw',
  info: { name: 'Smoke Album', img: '', desc: '', author: '', play_count: '' },
})

const qqDetail = resultOf(await fixture.rpc('getSonglistDetail', { source: 'tx', id: 22, page: 2 }))
assert.equal(qqDetailRequests, 3)
assert.deepEqual({ ...qqDetail, list: undefined }, {
  list: undefined, page: 1, limit: 2, total: 1, source: 'tx',
  info: { name: 'QQ playlist', img: cover, desc: 'One\nTwo', author: 'QQ author', play_count: '1.5万' },
})
assert.equal(qqDetail.list[0].songmid, 'qq-track')
assert.equal(qqDetail.list[0]._types['128k'].size, '1.00 KiB')

const neteaseDetail = resultOf(await fixture.rpc('getSonglistDetail', { source: 'wy', id: 33 }))
assert.deepEqual({ ...neteaseDetail, list: undefined }, {
  list: undefined, page: 1, limit: 1000, total: 1, source: 'wy',
  info: { name: 'NetEase playlist', img: cover, desc: '', author: 'NetEase author', play_count: '1.2亿' },
})
assert.equal(neteaseDetail.list[0].songmid, 24)
assert.deepEqual(resultOf(await fixture.rpc('getSonglistDetail', { source: 'wy', id: '33###test-token' })), neteaseDetail)
assert.deepEqual(neteaseDetailCookies, ['MUSIC_U=', 'MUSIC_U=test-token'])

assert.deepEqual(resultOf(await fixture.rpc('getSonglistDetail', { source: 'kg', id: 'id_44' })), {
  list: [], page: 1, limit: 10000, total: 0, source: 'kg',
  info: { name: 'Kugou playlist', img: cover, desc: '', author: '', play_count: '' },
})
assert.deepEqual(resultOf(await fixture.rpc('getSonglistDetail', { source: 'mg', id: 55, page: 2 })), {
  list: [], page: 2, limit: 30, total: 45, source: 'mg',
  info: { name: 'Migu playlist', img: cover, desc: '', author: 'Migu author', play_count: '10000' },
})
assert.equal(miguDetailRequests, 1)
assert.equal(miguInfoRequests, 2)
console.log('Fixtures passed (keyword suggestions and songlist search and detail on all five sources).')

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
const [liveTips, liveSonglistSearch] = await Promise.all([
  live.rpc('tipSearch', { keyword: '周杰伦' }),
  live.rpc('searchSonglist', { source, keyword: '周杰伦' }),
])
const liveSonglistDetail = await live.rpc('getSonglistDetail', {
  source, id: liveSonglistSearch.result?.list[0]?.id ?? playlistId,
})
for (const [method, response] of [
  ['tipSearch', liveTips],
  ['searchSonglist', liveSonglistSearch],
  ['getSonglistDetail', liveSonglistDetail],
]) {
  if (response.ok) {
    assert.ok(Array.isArray(response.result.list))
    if (method === 'tipSearch') assert.ok(response.result.list.every(item => typeof item === 'string'))
    if (method === 'getSonglistDetail') assert.equal(typeof response.result.info.name, 'string')
  }
  console.log(`Live ${method} ${JSON.stringify(response.ok ? { callId: response.callId, ok: true } : response)}`)
}
console.log('Bundle evaluated with only the seven native mocks. No missing globals or syntax errors were observed.')
