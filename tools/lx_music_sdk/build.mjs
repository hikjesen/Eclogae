import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { dirname, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const here = dirname(fileURLToPath(import.meta.url))
const upstream = resolve(process.env.LX_MUSIC_MOBILE_DIR ?? resolve(here, '../../../lx-music-mobile'))
const utils = resolve(upstream, 'src/utils')
const assets = resolve(here, '../../assets/lx')
const require = createRequire(import.meta.url)
const licenses = await Promise.all([
  'LICENSE.lx-music-mobile',
  'node_modules/buffer/LICENSE',
  'node_modules/base64-js/LICENSE',
  'node_modules/ieee754/LICENSE',
  'node_modules/he/LICENSE-MIT.txt',
  'node_modules/pako/LICENSE',
].map(async path => (await readFile(resolve(here, path), 'utf8')).replace(/\r\n/g, '\n').trim()))
const pakoSource = await readFile(resolve(here, 'node_modules/pako/dist/pako.esm.mjs'), 'utf8')
const zlibNotice = pakoSource.match(/^\/\/ \(C\) 1995-2013[^\r\n]*(?:\r?\n\/\/[^\r\n]*)*/m)[0].replace(/\r\n/g, '\n')
const sourceEdits = {
  // The bridge forwards request headers from options.headers and decodes JSON responses.
  'musicSdk/kw/tipSearch.js': [["Referer: 'http://www.kuwo.cn/',", "headers: { Referer: 'http://www.kuwo.cn/' },"]],
  'musicSdk/kw/util.js': [['\nexport const objStr2JSON = str => {', "\nexport const objStr2JSON = str => {\n  if (typeof str !== 'string') return str"]],
  // Keep the node lookup and playlist fetch retries on their respective endpoints.
  'musicSdk/kw/songList.js': [
    ['if (statusCode != 200 || !body.child) return this.getListDetail(id, ++tryNum)', 'if (statusCode != 200 || !body.child?.length) return this.getListDetailDigest5Info(id, ++tryNum)'],
    ['return body.child.length ? body.child[0].sourceid : null', 'return body.child[0].sourceid'],
    ['pn=${page - 1}}', 'pn=${page - 1}'],
    ["// console.log(body)\n      if (body.result !== 'ok') return this.getListDetail(id, page, ++tryNum)", "// console.log(body)\n      if (body.result !== 'ok') return this.getListDetailDigest5Music(id, page, ++tryNum)"],
  ],
  // A metadata retry must return metadata and advance its own retry counter.
  'musicSdk/mg/songList.js': [['return this.getListDetail(id, ++tryNum)', 'return this.getListDetailInfo(id, ++tryNum)']],
  // An empty Kugou playlist embeds an empty array in its detail page.
  'musicSdk/kg/songList.js': [[String.raw`listData: /global\.data = (\[.+\]);/`, String.raw`listData: /global\.data = (\[.*\]);/`]],
  // QuickJS omits the legacy RegExp.$1 constructor property.
  'musicSdk/kw/lyric.js': [['let time = RegExp.$1', 'let time = result[1]']],
  'musicSdk/mg/musicInfo.js': [
    ['const intervalTest = /(\\d\\d:\\d\\d)$/.test(item.length)', 'const interval = /(\\d\\d:\\d\\d)$/.exec(item.length)?.[1] ?? null'],
    ['interval: intervalTest ? RegExp.$1 : null,', 'interval,'],
    // createGetMusicInfosTask already returns Promise.all(tasks).
    ['await Promise.all(createGetMusicInfosTask(copyrightIds)).then(data => data.flat())', '(await createGetMusicInfosTask(copyrightIds)).flat()'],
  ],
  // An empty KRC response must reject instead of leaving the RPC pending.
  'musicSdk/kg/util.js': [["if (!str.length) return", "if (!str.length) return reject(new Error('Empty KRC lyric'))"]],
  'musicSdk/kg/lyric.js': [['this.getLyric(id, accessKey, fmt, ++tryNum)', 'this.getLyricDownload(id, accessKey, fmt, ++tryNum)']],
  'musicSdk/tx/lyric.js': [
    ["return Promise.reject(new Error('Get lyric failed'))", "return { promise: Promise.reject(new Error('Get lyric failed')) }"],
    ['return this.getLyric(songId, ++retryNum)', 'return this.getLyric({ songId }, retryNum + 1).promise'],
  ],
  // A short decimal representation otherwise produces an invalid AES-128 key.
  'musicSdk/wy/utils/crypto.js': [['String(Math.random()).substring(2, 18)', 'Math.random().toFixed(16).slice(2)']],
}

const result = await build({
  absWorkingDir: here,
  entryPoints: ['entry.js'],
  outfile: resolve(assets, 'music-sdk-bundle.js'),
  bundle: true,
  format: 'iife',
  platform: 'browser',
  target: 'es2020',
  tsconfigRaw: {},
  minify: true,
  drop: ['console'],
  legalComments: 'eof',
  banner: { js: '/*! Built with tools/lx_music_sdk/build.mjs. LX Music Mobile source: Apache-2.0. */' },
  footer: { js: `/*\n${licenses.join('\n\n')}\n*/\n${zlibNotice}` },
  metafile: true,
  plugins: [{
    name: 'lx-quickjs',
    setup(builder) {
      builder.onLoad({ filter: /[/\\]musicSdk[/\\].*\.js$/ }, async ({ path }) => {
        const edits = sourceEdits[relative(utils, path).split(sep).join('/')]
        if (!edits) return
        let contents = (await readFile(path, 'utf8')).replace(/\r\n/g, '\n')
        for (const [before, after] of edits) {
          if (!contents.includes(before)) throw new Error(`LX Music source changed: ${path} (${before})`)
          contents = contents.replace(before, after)
        }
        return { contents, resolveDir: dirname(path) }
      })
      builder.onResolve({ filter: /^lx\// }, args => ({
        path: resolve(utils, args.path.slice(3)),
      }))
      builder.onResolve({ filter: /^(?:\.\.\/)+(?:request|index)$/ }, args => {
        const target = resolve(args.resolveDir, args.path)
        if (target === resolve(utils, 'request')) return { path: resolve(here, 'request.js') }
        if (target === resolve(utils, 'index')) return { path: resolve(here, 'utility.js') }
      })
      builder.onResolve({ filter: /^@\/utils\/request$/ }, () => ({ path: resolve(here, 'request.js') }))
      builder.onResolve({ filter: /^@\/utils\/nativeModules\/crypto$/ }, () => ({ path: resolve(here, 'crypto.js') }))
      builder.onResolve({ filter: /^react-native-quick-md5$/ }, () => ({ path: resolve(here, 'md5.js') }))
      builder.onResolve({ filter: /^react-native-quick-base64$/ }, () => ({ path: resolve(here, 'base64.js') }))
      builder.onResolve({ filter: /^react-native-background-timer$/ }, () => ({ path: resolve(here, 'timer.js') }))
      builder.onResolve({ filter: /^buffer$/ }, () => ({ path: require.resolve('buffer/') }))
      builder.onResolve({ filter: /^(he|pako)$/ }, args => {
        if (args.resolveDir === here) return
        return builder.resolve(args.path, { kind: 'import-statement', resolveDir: here })
      })
    },
  }],
  write: false,
})

const excluded = /[/\\]musicSdk[/\\](?:(?:bd|xm)[/\\]|.*[/\\](?:leaderboard|comment|hotSearch|singer)\.js$|(?!kw[/\\]album\.js$).*[/\\]album\.js$|api-source\.js$)/
const extra = Object.keys(result.metafile.inputs).filter(path => excluded.test(path))
if (extra.length) throw new Error(`Unexpected LX Music modules: ${extra.join(', ')}`)

await mkdir(assets, { recursive: true })
const preloadPath = resolve(assets, 'user-api-preload.js')
const preload = await readFile(resolve(upstream, 'android/app/src/main/assets/script/user-api-preload.js'))
const existingPreload = await readFile(preloadPath).catch(error => {
  if (error.code !== 'ENOENT') throw error
})
if (!existingPreload?.equals(preload)) await writeFile(preloadPath, preload)
const [bundle] = result.outputFiles
await writeFile(bundle.path, bundle.contents)
console.log(`Built ${bundle.contents.byteLength} bytes`)
