import './runtime.js'
import kwSearch from 'lx/musicSdk/kw/musicSearch.js'
import kwLyric from 'lx/musicSdk/kw/lyric.js'
import kwPic from 'lx/musicSdk/kw/pic.js'
import kgSearch from 'lx/musicSdk/kg/musicSearch.js'
import kgLyric from 'lx/musicSdk/kg/lyric.js'
import kgPic from 'lx/musicSdk/kg/pic.js'
import txSearch from 'lx/musicSdk/tx/musicSearch.js'
import txLyric from 'lx/musicSdk/tx/lyric.js'
import wySearch from 'lx/musicSdk/wy/musicSearch.js'
import wyLyric from 'lx/musicSdk/wy/lyric.js'
import wyMusicInfo from 'lx/musicSdk/wy/musicInfo.js'
import mgSearch from 'lx/musicSdk/mg/musicSearch.js'
import mgLyric from 'lx/musicSdk/mg/lyric.js'
import mgPic from 'lx/musicSdk/mg/pic.js'
import { handleResponse } from './request.js'

// The QQ and NetEase SDKs define these adapters in their platform index modules.
const txPic = {
  async getPic({ albumId }) {
    return `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumId}.jpg`
  },
}
const wyPic = {
  getPic({ songmid }) {
    return wyMusicInfo(songmid).promise.then(info => info.al.picUrl)
  },
}
const platforms = new Map([
  ['kw', { musicSearch: kwSearch, lyric: kwLyric, pic: kwPic }],
  ['kg', { musicSearch: kgSearch, lyric: kgLyric, pic: kgPic }],
  ['tx', { musicSearch: txSearch, lyric: txLyric, pic: txPic }],
  ['wy', { musicSearch: wySearch, lyric: { getLyric: ({ songmid }) => wyLyric(songmid) }, pic: wyPic }],
  ['mg', { musicSearch: mgSearch, lyric: mgLyric, pic: mgPic }],
])

async function invoke(method, params) {
  const sdk = platforms.get(params?.source)
  if (!sdk) throw new Error(`Unsupported source: ${params?.source}`)

  switch (method) {
    case 'search': {
      const { keyword } = params
      const page = params.page ?? 1
      const limit = params.limit ?? 30
      if (typeof keyword !== 'string') throw new Error('search requires a string keyword')
      const result = await sdk.musicSearch.search(keyword, page, limit)
      return { list: result.list, total: result.total, page, limit: result.limit, allPage: result.allPage }
    }
    case 'getLyric': {
      const { lyric, tlyric = '', rlyric = '', lxlyric = '' } = await sdk.lyric.getLyric(params.musicInfo).promise
      if (typeof lyric !== 'string') throw new Error('Get lyric failed')
      return { lyric, tlyric, rlyric, lxlyric }
    }
    case 'getPic': {
      const pic = sdk.pic.getPic(params.musicInfo)
      return { picUrl: await (pic.promise ?? pic) }
    }
    default:
      throw new Error(`Unsupported method: ${method}`)
  }
}

function reply(payload) {
  globalThis.__lx_sdk_call__('rpcResponse', JSON.stringify(payload))
}

globalThis.__lx_sdk_dispatch__ = (action, jsonData) => {
  if (action === 'response') {
    handleResponse(JSON.parse(jsonData))
  } else if (action === 'rpc') {
    const { callId, method, params } = JSON.parse(jsonData)
    invoke(method, params).then(
      result => reply({ callId, ok: true, result }),
      error => reply({ callId, ok: false, error: `${params?.source ?? 'SDK'} ${method}: ${error?.message ?? String(error)}` }),
    )
  }
}
