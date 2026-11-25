# Namida「在线曲库」集成项目交接文档（Stage 0 ~ Stage 4 完成）

> **更新时间**：2026-11-25  
> **当前分支**：`feat/lx-stage3-polish`（线性基于 `feat/lx-stage2-download` -> `feat/lx-stage1-bridge` -> `feat/lx-stage0-ci` -> `hikjesen/namida` `main`）  
> **当前状态**：✅ **Stage 0 / Stage 1 / Stage 2 / Stage 3（原生美学重构）/ Stage 4 核心功能（在线试听、波形缓存、歌单搜索与整单下载、原生单曲循环修复）全部落地并通过真机验收** -> 待决定 **合并回 `main`** 及是否按需推进后续可选增强项。

---

## 1. 项目目标与工作区拓扑

- **项目目标**：在个人 Fork [`hikjesen/namida`](https://github.com/hikjesen/namida) 中无缝融入「在线曲库」（底层基于 LX Music 协议与 SDK），实现多平台聚合/分源歌曲与歌单搜索、关键词联想、用户自导入（本地 / 在线 URL）第三方 `.js` 自定义音源解析、主播放器原生在线试听（含封面/双语歌词/边播边缓/波形条/单曲循环）、多音质并发下载校验、内嵌标签封面与完整 `.lrc` 导出、以及自动入库的一体化体验。
- **本地工作区**：
  - 主开发仓库：`d:\namida项目\namida`（当前分支 `feat/lx-stage3-polish`，远端 `origin` = `https://github.com/hikjesen/namida.git`）
  - 只读参考仓库：`d:\namida项目\lx-music-mobile`（分支 `feature/android-download-mvp`，远端 `https://github.com/hikjesen/lx-music-mobile.git`）
- **开发与验收约束**：
  - 本机无 Flutter / Dart / Java 环境（仅安装有 `git`、`gh`、`node`、`npm`、`codex`），全程依赖 **GitHub Actions 免费构建**（`dart analyze` + ARM64 Release APK），用户下载 Artifact 到真机测试反馈。
  - **严禁提交任何第三方自定义音源 `.js` 文件、第三方音源链接、Cookie、私密 Token 或个人敏感凭据**。
  - **用户可见界面全面去 "LX" 化**：UI 统一使用「在线曲库」「在线曲库设置」「在线试听」等命名；内部目录 `lib/lx_music/`、通道名与持久化路径保持不变以确保向后兼容。

---

## 2. 强制治理与协作规则（必读 `agent.md`）

请新会话的主控 Agent 开局先完整阅读 [`agent.md`](../agent.md) 与 [`AGENTS.md`](../AGENTS.md)，核心红线摘要如下：

1. **主控 Agent 统筹，Codex CLI 负责编码**：不要由主控 Agent 亲自写完所有代码，将编码任务拆解为边界清晰的子任务交给 Codex CLI（`gpt-6.2-sol`），主控负责架构、任务规格、Diff 审查与 CI 验收。
2. **绝对单向调用（严禁回调）**：绝对禁止 Codex 对主控 Agent（Antigravity / 反重力）进行任何形式的回调或反向触发。
3. **先核验再行动**：用户的根因猜测可能是错误的，任何修改前必须先通过源码、依赖或日志验证真实问题。
4. **严格约束 GPT 防御性编程**：下发 Codex 任务时必须显式禁止无意义判空、套娃 `try/catch`、静默吞错、冗余 fallback、过度抽象，并在回收 Diff 时逐行把关。
5. **额度耗尽必须停下来问用户**：如果 GPT / Codex 额度用尽或触发配额限制，**必须立即停止并询问用户**（换账号 / 切非官方模型 / 其他方案），**严禁擅自切换模型或通道**。
6. **禁止快速模式（Fast Mode）**：始终保持 `service_tier = "default"`；推理强度按任务复杂度在 `high` / `xhigh` / `max` 间灵活选用，**禁止使用过低档位（如 `low`）**。
7. **外部 PR Agent 约束**：仓库后续可能有其他 Agent 提交 PR，主控地位不变，外部 PR 须遵守 `agent.md` 与 `AGENTS.md`。

---

## 3. Codex CLI 已验证调用方式（Windows）

- **必须使用的二进制（重要）**：
  - 系统 `PATH` 中的旧版 `codex.exe`（`v0.153.4`）在 ChatGPT 认证下调用 `gpt-6.2-sol` 会返回 HTTP 400。
  - 必须显式调用 VS Code 扩展内置新版（`v0.171.0-alpha.13`）：
    ```
    C:\Users\HiKJeSen\.vscode\extensions\openai.chatgpt-26.1117.41037-win32-x64\bin\windows-x86_64\codex.exe
    ```
- **非交互调用模板**（非 TTY 下必须通过 stdin + 末尾 `-` 传参，避免挂起等待 stdin EOF）：
  ```powershell
  $codex = "C:\Users\HiKJeSen\.vscode\extensions\openai.chatgpt-26.1117.41037-win32-x64\bin\windows-x86_64\codex.exe"
  @'
  Read AGENTS.md and agent.md first. Strictly one-way execution; do NOT run git commit or git push.
  STRICT SCOPE: <明确文件/目录白名单>
  <清晰规格 + 反防御性编程约束>
  '@ | & $codex exec --ephemeral -m gpt-6.2-sol -c model_reasoning_effort=high -c service_tier=default -s workspace-write -C "d:\namida项目\namida" -
  ```
- **注意事项**：
  - 推理强度仅用 `high` / `xhigh` / `max`；显式保持 `service_tier=default`（严禁开启 `fast`）。
  - Windows PowerShell 5.1 不支持 `&&`，串行命令请使用 `; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }`。
  - 并行派发多个 Codex 任务时，务必保证每个任务的修改目录/文件集合严格互不重叠。
  - 本机 `gh` 已登录账号 `hikjesen`（具 `repo`、`workflow` 权限）；仅修改文档时请在 commit message 末尾加 `[skip ci]` 避免空耗 Android 构建。

---

## 4. 全阶段里程碑构建与真机验收记录

### 4.1 里程碑构建总表（全部全绿 + 真机验收通过）

| 阶段 | 分支 / Commit | CI Run | Artifact 大小 | 验收结论 |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 0** | `feat/lx-stage0-ci` (`fd8c84bc`) | [45391810485](https://github.com/hikjesen/namida/actions/runs/45391810485) (`13m36s`) | `49,867,695 bytes` | ✅ Clean-Room 兼容包 + 共存包名 `com.msob7y.namida.lx` + 本地播放通过 |
| **Stage 1** | `feat/lx-stage1-bridge` (`c5b1dac2`) | [45412490417](https://github.com/hikjesen/namida/actions/runs/45412490417) (`13m24s`) | `50,634,615 bytes` | ✅ 固定签名生效 + Android 原生 QuickJS 双引擎 + 5 平台搜索/歌词/自定义源直链解析通过 |
| **Stage 2 (MVP)** | `feat/lx-stage2-download` (`e77de574`) | [45422922524](https://github.com/hikjesen/namida/actions/runs/45422922524) (`16m26s`) | `50,732,057 bytes` | ✅ 固定签名直接覆盖安装 + URL 在线导入 + 4 阶段下载/魔数校验/标签封面/完整 `.lrc`/即时入库通过 |
| **Stage 3 (美学重构)** | `feat/lx-stage3-polish` (`d3595ca5`) | [45566841964](https://github.com/hikjesen/namida/actions/runs/45566841964) (`15m+`) | ARM64 APK | ✅ Namida 原生美学重构、底栏 YouTube 替换为「在线曲库」、毛玻璃音质窗、记住上次音质、并发 1-3、防重检测、HEAD 进度探测 |
| **Stage 4 (在线试听与歌单)** | `feat/lx-stage3-polish` (`a2360084`) | [45606440084](https://github.com/hikjesen/namida/actions/runs/45606440084) (`15m+`) | ARM64 APK | ✅ 搜索状态持久化、聚合全源 + 关键词联想、主播放器原生在线试听/稍后播放、五平台歌单搜索网格与整单下载 |
| **真机反馈打磨 R2** | `feat/lx-stage3-polish` (`d968cf9f`) | [45617854104](https://github.com/hikjesen/namida/actions/runs/45617854104) (`15m+`) | ARM64 APK | ✅ 顶部精简为单行搜索栏、下载管理并入「在线曲库设置」双 Tab、右上角齿轮上下文切换、试听边播边缓存与波形条渲染通过 |
| **单曲循环根因修复 R3** | `feat/lx-stage3-polish` (`5f449d3d`) | [45629267767](https://github.com/hikjesen/namida/actions/runs/45629267767) (`15m28s`) | `50,772,738 bytes` | ✅ 接入原生 `LoopMode.one` / `loop-file=inf` + 安全 EOF 重载兜底，本地与在线试听单曲循环真机全通过 |

### 4.2 统一固定签名与 CI（已落地）
- 已在 `hikjesen/namida` 仓库配置 GitHub Actions Secrets：`LX_ANDROID_KEYSTORE_B64`、`LX_ANDROID_KEY_PROPERTIES_B64`（PKCS12 Keystore，本地私钥生成后已销毁、永不入库）。
- [.github/workflows/android-lx-build.yml](../.github/workflows/android-lx-build.yml) 自动解码写入 `android/app/keystore.jks` 与 `android/key.properties`（两者均在 `.gitignore` 中）；任意分支打出的 ARM64 Release APK **均可直接覆盖安装，保留本地设置与已导入音源**。

---

## 5. 已完成模块全景清单

### 5.1 闭源兼容包与播放引擎（`packages_compat/`）
- `packages_compat/basic_audio_handler`、`playlist_manager`、`youtipie`（离线空壳）、`namico_login_manager`、`namico_subscription_manager`、`flutter_sharing_intent`。
- **原生单曲循环与 EOF 重载修复**（`5f449d3d`）：
  - `packages_compat/basic_audio_handler/lib/src/av_player.dart`：`AVPlayer` 新增 `setLoopOne(bool enabled)`，`CustomAudioPlayer` 通过 `just_audio` 直接设置 `LoopMode.one`（Android `ExoPlayer.REPEAT_MODE_ONE`），并在 `setSource` 时自动重申状态。
  - `lib/class/custom_mpv_player.dart`：同步实现 `setLoopOne`（`_setMpvProperty('loop-file', enabled ? 'inf' : 'no')`）。
  - `packages_compat/basic_audio_handler/lib/src/handler.dart`：在 `PlayerRepeatMode.one`（以及单曲队列的 `PlayerRepeatMode.all`）且无按曲数睡眠定时 / 无自定义起止书签时自动启用原生单曲循环；需要从 `ProcessingState.completed` 重启的场景（`forNtimes`、书签、睡眠定时、播完后点播放）改为干净重载（本地/缓存文件轻量 `setAudioSource(file)`，非文件源走 `_playQueueIndex`）。

### 5.2 Android 原生双上下文 QuickJS 运行时与 SDK Bundle
- `android/app/src/main/kotlin/com/msob7y/namida/lx/`：
  - `LxCrypto.kt`（AES CBC/ECB、RSA、MD5、SHA-1、Base64）、`LxUserApiRuntime.kt`、`LxMusicSdkRuntime.kt`、`LxQuickJsBridge.kt`（`MethodChannel("namida/lx_bridge")` + `EventChannel("namida/lx_events")`）。
  - R8 keep 规则位于 `android/app/proguard-rules.pro`（`com.whl.quickjs.**`、`com.msob7y.namida.lx.**`）。
- `tools/lx_music_sdk/` & `assets/lx/`：
  - `assets/lx/music-sdk-bundle.js`：由 `tools/lx_music_sdk/entry.js` + `build.mjs` 打包，完整导出 `kw`/`kg`/`tx`/`wy`/`mg` 五平台的 `musicSearch`、`tipSearch`（关键词联想）、`songList`（`search` + `getListDetail`）、`lyric`、`pic`，附可复现 `smoke_test.mjs`。
  - `assets/lx/user-api-preload.js`：与 `lx-music-mobile` 协议逐字节一致。

### 5.3 Dart「在线曲库」业务层与原生风格 UI（全部收敛在 `lib/lx_music/`）
- **核心服务与状态**：
  - `lx_models.dart`：曲目/歌单/搜索/歌词/音源/下载设置（含 `rememberLastQuality`、`lastSelectedQuality`、翻译/罗马音细粒度开关、并发数 1–3）与任务模型。
  - `lx_http_proxy.dart`：复用 Namida `rhttp`，跟随全局代理配置、支持二进制透传与取消。
  - `lx_user_api_store.dart`：私有目录 `<appSupport>/lx_music/` 原子持久化 `manifest.json` / `settings.json`，自动剥离 UTF-8 BOM。
  - `lx_bridge_service.dart`：QuickJS 通道、本地/URL 音源导入（限制 2 MB UTF-8）、单源与聚合搜索、`tipSearch`、歌单搜索与详情、歌词/封面/直链解析、200 条诊断日志。
  - `lx_audio_sniffer.dart` / `lx_download_resolver.dart`：音频魔数 & 封面头校验、渐进音质降级（`flac24bit -> flac -> 320k -> 128k`）与跨平台自动换源。
  - `lx_download_manager.dart`：可配置并发数（1–3）的 4 阶段下载队列、下载前轻量 `HEAD` 探测 `Content-Length`、队列与目录防重检测、标签/封面写入、双语+罗马音 `.lrc` 合并导出与即时入库。
  - `lx_search_controller.dart`：全局单例持久化搜索词、所选来源（含 `all` 聚合）、歌曲/歌单模式、分页结果、滚动位置、防抖关键词联想与搜索历史。
  - `lx_preview_player.dart`：原生主播放器在线试听引擎，支持点击标题即刻试听、稍后播放、本地已下载曲目直连复用、封面/双语歌词实时同步、`http_cache_stream` 边播边缓存至 `APP_CACHE/preview_audio/`（200 MB LRU 淘汰并保护当前在播文件）、缓存体积统计与清理，以及联动 `WaveformController` 生成播放进度波形条。
- **页面与组件**：
  - `lx_music_page.dart`：「在线曲库」主界面——顶部收敛为**单行紧凑搜索栏**（`[来源下拉 + 搜索输入框]` + 右侧 `[歌曲 | 歌单]` 切换），条件式多选操作栏，支持聚合/单源搜索、联想浮层、分页加载与三列歌单网格。
  - `lx_songlist_detail_page.dart`：歌单详情页（封面、描述、播放量、曲目分页列表、`下载整张歌单` 批量入队）。
  - `lx_settings_page.dart`：**双 Tab 结构（`设置 | 下载管理`）**，提供 `LxSettingsPage.openDownloads()` 直达下载管理；收口音源导入/切换/详情/`showUpdateAlert`、下载目录、默认音质与「记住上次选择」、并发数、「在线试听缓存」大小查看与一键清理、诊断日志。
  - `lx_app_bar_icon.dart`：在在线曲库与设置页自动隐藏，在其他页面仅当存在活跃下载时显示带数量角标的快捷图标并直达下载管理。
  - `widgets/`：`lx_track_tile.dart`、`lx_songlist_card.dart`、`lx_cover_thumb.dart`、`lx_download_quality_dialog.dart`（`CustomBlurryDialog` 毛玻璃音质窗）、`lx_download_actions.dart`、`lx_download_task_card.dart`、`lx_lyrics_sheet.dart`、`lx_source_dialogs.dart`。

### 5.4 Namida 主干最小挂钩清单
- `lib/core/namida_converter_ext.dart` & `lib/controller/scroll_search_controller.dart`：将 `LibraryTab.youtube` 槽位替换为「在线曲库」；在 `YOUTUBE_HOME` / `YOUTUBE_HOME_SECTION` 页面上，右上角设置齿轮上下文直达「在线曲库设置」（带活跃下载小红点提示）。
- `lib/base/audio_handler.dart` & `lib/class/track.dart` & `lib/core/enums.dart` & `lib/controller/lyrics_controller.dart` & `lib/controller/indexer_controller.dart` & `lib/controller/indexer_artwork_extract_strategies.dart` & `lib/packages/miniplayer.dart`：为虚拟在线试听 `Track` 提供主播放器、波形（`http_cache_stream` 缓存文件）、封面、双语歌词与 MiniPlayer 兼容支持，并与本地曲库/索引隔离。
- `lib/ui/pages/settings_page.dart`：保留「在线曲库设置」入口（原生 `Broken.*` 图标）。
- `lib/main_page_wrapper.dart`：清理了 Stage 2 的临时抽屉项，复用了原 YouTube 抽屉槽位。

---

## 6. 关键已核验技术备忘（避免踩坑）

1. **Android ExoPlayer 单曲循环切勿在 `STATE_ENDED` 下硬 `seek(0)`**：
   - `MSOB7YY/just_audio`（`ref: video`）基于 Media3 ExoPlayer，在 `ProcessingState.completed`（`STATE_ENDED`）状态下执行 `pause -> seek(0) -> play` 会触发超时挂起并退回暂停态。
   - 正确做法：常规单曲循环与单曲列表循环直接走 `AVPlayer.setLoopOne(true)`（ExoPlayer `REPEAT_MODE_ONE` / mpv `loop-file=inf`）；确实需在 `STATE_ENDED` 后重播时必须重新加载音频源。
2. **在线试听音频波形与边播边缓**：
   - 远端流媒体本身无法直接给 `WaveformController` 解码；复用 Namida 自身的 `http_cache_stream`（`_buildCacheableAVSource`）落盘到 `AppDirs.APP_CACHE/preview_audio/` 后，下载/缓存完成回调即可触发 `WaveformController.inst.generateWaveform(...)` 渲染与本地一致的动态波形条。
3. **Dart 3.13 泛型推断**：Record 里返回空列表时必须显式写类型（如 `const <LxUserApiMeta>[]`），否则 `dart analyze` 会报 `return_of_invalid_type`。
4. **`FilesDownloadManager.inst.download`**：`downloadingStream` 传入的是 `bytesDelta`（增量字节，断线重连时可能为负），已做下限 0 钳位并通过前置 `HEAD` 获取 `Content-Length`。
5. **CI 日志/状态监控**：代理环境下 `gh run watch` 偶尔发生 `wsarecv` 断开，用 `gh run view --json status,conclusion` 带 `try/catch` 轮询即可稳定跟踪。

---

## 7. 待办收尾与后续可选演进（Stage 4+）

### 7.1 工程收尾（推荐优先确认）
- [ ] **特性分支合并回 `main`**：由用户确认是否将 `feat/lx-stage3-polish` 合并回 `hikjesen/namida` 的 `main` 分支（并按需打 Release Tag / 清理旧阶段分支）。

### 7.2 可选进阶增强（原计划标为“按需”，视实际使用反馈决定）
- [ ] **Android 息屏大批量下载保活**：Namida 上游 `setKeepRunningInBackground` 在 Android 侧为空实现；若经常整张下载上百首歌单且需锁屏/切后台持续下载，可补齐 Android 前台通知 Service（带进度通知）。
- [ ] **歌单广场 / 排行榜 / 外部歌单链接导入**：在 `tools/lx_music_sdk/entry.js` 中补导出排行榜（`leaderboard`）与热门歌单（`songList.getList`）及外链解析，支持逛榜单或直接粘贴网易云/QQ 歌单分享链接导入。
- [ ] **播放器页一键下载当前试听曲目**：在全屏播放页菜单中为在线试听曲目补一个直达下载/音质选择的快捷动作。
- [ ] **上游 Namida 版本同步**：后续上游 `Namida` 发布新版本时，基于隔离良好的 `lib/lx_music/` 与最小主干挂钩执行 `merge` / `rebase` 维护。
