import './runtime.js'
import kwSearch from 'lx/musicSdk/kw/musicSearch.js'
import kwLyric from 'lx/musicSdk/kw/lyric.js'
import kwPic from 'lx/musicSdk/kw/pic.js'
import kwTipSearch from 'lx/musicSdk/kw/tipSearch.js'
import kwSongList from 'lx/musicSdk/kw/songList.js'
import kgSearch from 'lx/musicSdk/kg/musicSearch.js'
import kgLyric from 'lx/musicSdk/kg/lyric.js'
import kgPic from 'lx/musicSdk/kg/pic.js'
import kgSongList from 'lx/musicSdk/kg/songList.js'
import txSearch from 'lx/musicSdk/tx/musicSearch.js'
import txLyric from 'lx/musicSdk/tx/lyric.js'
import txSongList from 'lx/musicSdk/tx/songList.js'
import wySearch from 'lx/musicSdk/wy/musicSearch.js'
import wyLyric from 'lx/musicSdk/wy/lyric.js'
import wyMusicInfo from 'lx/musicSdk/wy/musicInfo.js'
import wySongList from 'lx/musicSdk/wy/songList.js'
import mgSearch from 'lx/musicSdk/mg/musicSearch.js'
import mgLyric from 'lx/musicSdk/mg/lyric.js'
import mgPic from 'lx/musicSdk/mg/pic.js'
import mgSongList from 'lx/musicSdk/mg/songList.js'
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
  ['kw', { musicSearch: kwSearch, lyric: kwLyric, pic: kwPic, songList: kwSongList }],
  ['kg', { musicSearch: kgSearch, lyric: kgLyric, pic: kgPic, songList: kgSongList }],
  ['tx', { musicSearch: txSearch, lyric: txLyric, pic: txPic, songList: txSongList }],
  ['wy', { musicSearch: wySearch, lyric: { getLyric: ({ songmid }) => wyLyric(songmid) }, pic: wyPic, songList: wySongList }],
  ['mg', { musicSearch: mgSearch, lyric: mgLyric, pic: mgPic, songList: mgSongList }],
])

async function invoke(method, params) {
  if (method === 'tipSearch') {
    if (typeof params?.keyword !== 'string') throw new Error('tipSearch requires a string keyword')
    const list = await kwTipSearch.search(params.keyword)
    return { list }
  }

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
    case 'searchSonglist': {
      const { keyword } = params
      const page = params.page ?? 1
      const limit = params.limit ?? 20
      if (typeof keyword !== 'string') throw new Error('searchSonglist requires a string keyword')
      const result = await sdk.songList.search(keyword, page, limit)
      return { list: result.list ?? [], total: Number(result.total) || 0, page, limit: Number(result.limit) || limit, source: params.source }
    }
    case 'getSonglistDetail': {
      const id = String(params?.id ?? '')
      const page = params.page ?? 1
      if (!id) throw new Error('getSonglistDetail requires id')
      // QQ uses the second argument as its retry counter.
      const result = params.source === 'tx'
        ? await sdk.songList.getListDetail(id)
        : await sdk.songList.getListDetail(id, page)
      return {
        list: result.list ?? [],
        page: Number(result.page) || page,
        limit: Number(result.limit) || (result.list?.length ?? 0),
        total: Number(result.total) || (result.list?.length ?? 0),
        source: params.source,
        info: {
          name: result.info?.name ?? '',
          img: result.info?.img ?? '',
          desc: result.info?.desc ?? '',
          author: result.info?.author ?? '',
          play_count: result.info?.play_count == null ? '' : String(result.info.play_count),
        },
      }
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
