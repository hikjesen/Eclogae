# LX Music SDK bundle

The bundle uses the LX Music Mobile source at revision `5442fc53fcd3c2d9480ce0c5505d1e074fd2364b`. Keep that checkout next to Namida as `lx-music-mobile`, or set `LX_MUSIC_MOBILE_DIR` to its path. Build from this directory with Node.js 20.3+.

```sh
npm ci
node build.mjs
node smoke_test.mjs
```

The build reads the checkout and writes the two assets under `assets/lx`. The smoke test uses local fixtures and probes Kuwo search and lyrics through Node fetch. It reports live RPC errors separately, so a provider outage or blocked network can be distinguished from a bundle failure.

The LX Music Mobile source and upstream preload are distributed under the [Apache License 2.0](LICENSE.lx-music-mobile).
