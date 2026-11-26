# Eclogae

> Personal Android music player built by **Hiko & Wan**, combining a polished local media library, multi-platform online library with user-imported `.js` music sources, native online preview & concurrent download tagging, and a lightweight native Android floating lyrics engine.

## Highlights

- **Local Music Player**: High-performance local audio library, dynamic album artwork palettes, synced/bilingual/romanized lyrics, waveform seekbar, gapless & native single-track looping, customizable media notification controls, equalizer, and smart playlists.
- **Online Library**:
  - Multi-platform song & playlist search (`all` aggregate + per-platform) with live keyword suggestions and external playlist link direct import.
  - Native QuickJS runtime for user-imported `.js` custom music sources (local file or URL; **no third-party scripts or credentials are bundled in this repository**).
  - Native main-player online preview with streaming cache, dynamic waveform generation, album artwork, and synced bilingual lyrics.
  - Configurable concurrent downloads (1–3) with progressive quality fallback, magic-byte audio/cover verification, tag & artwork embedding, `.lrc` export, playlist subfolder archiving, and recursive deduplication.
- **Android Native Floating Lyrics**:
  - Lightweight native Kotlin `WindowManager` overlay (`TYPE_APPLICATION_OVERLAY`) reusing the main background lyrics pipeline.
  - Independent translation & romanization toggles, 8–34 sp font size, 2–8 lines or single-line 30fps marquee, custom RGB & image-eyedropper text/outline colors, dynamic album accent sync, full-screen landscape positioning, compact 4-button floating toolbar, Android 12+ touch-passthrough lock, media notification controls, and fallback silent unlock notification.

## Android Build

- Application ID: `com.wander.eclogae`
- CI workflow: [`.github/workflows/android-eclogae-build.yml`](.github/workflows/android-eclogae-build.yml) (runs `flutter gen-l10n`, `dart analyze`, and builds the signed `arm64-v8a` release APK as a GitHub Actions artifact; APK binaries are never committed to Git).
- Project handoff & architecture notes: [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Authors

**Hiko & Wan**
