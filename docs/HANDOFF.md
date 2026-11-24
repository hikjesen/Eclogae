# Namida LX 集成项目交接文档（Stage 2 -> Stage 3）

> **更新时间**：2026-11-24  
> **当前分支**：`feat/lx-stage2-download`（线性基于 `feat/lx-stage1-bridge` -> `feat/lx-stage0-ci` -> `hikjesen/namida` `main`）  
> **当前阶段**：✅ **Stage 0 / Stage 1 / Stage 2（完整功能 MVP）全部完成并通过真机验收** -> 准备进入 **Stage 3（贴合 Namida 原生美学的 UI 美化、交互打磨与真机回归）**

---

## 1. 项目目标与工作区拓扑

- **项目目标**：在个人 Fork [`hikjesen/namida`](https://github.com/hikjesen/namida) 中集成 LX Music 的多平台音乐搜索、用户自导入（本地 / 在线 URL）第三方 `.js` 自定义音源解析、音频下载校验、内嵌标签封面与完整 `.lrc` 导出、以及自动入库与播放的一体化体验。
- **本地工作区**：
  - 主开发仓库：`d:\namida项目\namida`（当前分支 `feat/lx-stage2-download`，远端 `origin` = `https://github.com/hikjesen/namida.git`）
  - 只读参考仓库：`d:\namida项目\lx-music-mobile`（分支 `feature/android-download-mvp`，远端 `https://github.com/hikjesen/lx-music-mobile.git`）
- **开发与验收约束**：
  - 本机无 Flutter / Dart / Java 环境（仅安装有 `git`、`gh`、`node`、`npm`、`codex`），全程依赖 **GitHub Actions 免费构建**出 Android ARM64 Release APK，用户下载 Artifact 到真机测试反馈。
  - **严禁提交任何第三方自定义音源 `.js` 文件、第三方音源链接、Cookie、私密 Token 或个人敏感凭据**。

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
  '@ | & $codex exec --ephemeral -m gpt-6.2-sol -c model_reasoning_effort=high -s workspace-write -C "d:\namida项目\namida" -
  ```
- **注意事项**：
  - 推理强度仅用 `high` / `xhigh` / `max`；保持默认 `service_tier = "default"`（严禁开启 `fast`）。
  - 并行派发多个 Codex 任务时，务必保证每个任务的修改目录/文件集合严格互不重叠。
  - 本机 `gh` 已登录账号 `hikjesen`（具 `repo`、`workflow` 权限）；仅修改文档时请在 commit message 末尾加 `[skip ci]` 避免空耗 Android 构建。

---

## 4. Stage 0 ~ Stage 2 已落地基线与真机验收

### 4.1 里程碑构建记录（全部全绿 + 真机通过）

| 阶段 | 分支 / Commit | CI Run | Artifact 大小 | 验收结论 |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 0** | `feat/lx-stage0-ci` (`fd8c84bc`) | [45391810485](https://github.com/hikjesen/namida/actions/runs/45391810485) (`13m36s`) | `49,867,695 bytes` | ✅ Clean-Room 兼容包 + 共存包名 `com.msob7y.namida.lx` + 本地播放通过 |
| **Stage 1** | `feat/lx-stage1-bridge` (`c5b1dac2`) | [45412490417](https://github.com/hikjesen/namida/actions/runs/45412490417) (`13m24s`) | `50,634,615 bytes` | ✅ 固定签名生效 + Android 原生 QuickJS 双引擎 + 5 平台搜索/歌词/自定义源直链解析通过 |
| **Stage 2 (MVP)** | `feat/lx-stage2-download` (`e77de574`) | [45422922524](https://github.com/hikjesen/namida/actions/runs/45422922524) (`16m26s`) | `50,732,057 bytes` | ✅ 固定签名直接覆盖安装 + URL 在线导入 + 4 阶段下载/魔数校验/标签封面/完整 `.lrc`/即时入库/顶栏与侧边栏入口全部通过 |

### 4.2 统一固定签名与 CI（已落地）
- 已在 `hikjesen/namida` 仓库配置 GitHub Actions Secrets：`LX_ANDROID_KEYSTORE_B64`、`LX_ANDROID_KEY_PROPERTIES_B64`（PKCS12 Keystore，本地私钥生成后已销毁、永不入库）。
- [.github/workflows/android-lx-build.yml](../.github/workflows/android-lx-build.yml) 自动解码写入 `android/app/keystore.jks` 与 `android/key.properties`（两者均在 `.gitignore` 中）；后续任意分支打出的 ARM64 Release APK **均可直接覆盖安装，保留本地设置与已导入音源**。

### 4.3 已完成模块清单（高度隔离）

1. **Stage 0 闭源兼容包（`packages_compat/`）**：
   - `basic_audio_handler`、`playlist_manager`、`youtipie`（编译期离线空壳）、`namico_login_manager`、`namico_subscription_manager`、`flutter_sharing_intent`。
2. **Android 原生双上下文 QuickJS 运行时（`android/app/src/main/kotlin/com/msob7y/namida/lx/`）**：
   - 依赖：`wang.harlon.quickjs:wrapper-android:2.4.0`；R8 keep 规则已加在 `android/app/proguard-rules.pro`（`com.whl.quickjs.**`、`com.msob7y.namida.lx.**`）。
   - `LxCrypto.kt`：AES CBC/ECB（保持 `AES` 默认行为与 `lx-music-mobile` 一致）、RSA、MD5、SHA-1、Base64。
   - `LxUserApiRuntime.kt`：独立 `HandlerThread`，1:1 协议级运行 `assets/lx/user-api-preload.js` 与用户第三方 `.js` 音源。
   - `LxMusicSdkRuntime.kt`：独立 `HandlerThread`，运行 `assets/lx/music-sdk-bundle.js`。
   - `LxQuickJsBridge.kt`：`MethodChannel("namida/lx_bridge")` + `EventChannel("namida/lx_events")`，仅在 `NamidaAppChannels.kt` 中 1 行注册；`Console` 覆写已兼容可空 `String?`。
3. **`musicSdk` Bundle 与构建工具**：
   - `assets/lx/music-sdk-bundle.js`（225 KB，覆盖 `kw`/`kg`/`tx`/`wy`/`mg` 搜索、歌词、封面，已通过 QuickJS WASM 夹具与宿主机 5 平台真网搜索+歌词解码测试）。
   - `assets/lx/user-api-preload.js`（与 `lx-music-mobile` 逐字节一致）。
   - `tools/lx_music_sdk/`：可复现 `esbuild` 构建脚本与 `smoke_test.mjs`（`tools/lx_music_sdk/node_modules/` 已写入 `.gitignore`）。
4. **Dart 业务层与功能 UI（全部收敛在 `lib/lx_music/`）**：
   - `lx_models.dart`：`LxPlatform`、`LxTrack`（完整保留 `rawMusicInfo`）、`LxSearchResult`、`LxLyricResult`、`LxUserApiMeta`、`LxUserApiState`、`LxDownloadSettings`、`LxDownloadStage`、`LxDownloadTask`、`LxLogEntry`。
   - `lx_http_proxy.dart`：统一走 Namida 现有 `rhttp`（`ClientSettings(proxySettings: ..., throwOnStatusCode: false)`），自动跟随代理变更、支持二进制 base64 透传与取消。
   - `lx_user_api_store.dart`：私有目录持久化（`<appSupport>/lx_music/`）、原子写入 `manifest.json` 与 `settings.json`、自动剥离 UTF-8 BOM。
   - `lx_bridge_service.dart`：通道管理、本地 `.js` 与在线 URL（`importScriptFromUrl`，限制 2 MB UTF-8）导入、搜索/直链/歌词/封面/二进制下载、200 条环形诊断日志。
   - `lx_audio_sniffer.dart`：音频魔数校验（FLAC/MP3/M4A/OGG/WAV/APE，拦截 `<1024B` 或 HTML 错误页）与封面图片头校验（JPEG/PNG/WebP）。
   - `lx_download_resolver.dart`：渐进音质降级（`flac24bit` -> `flac` -> `320k` -> `128k`）+ 可选跨平台自动换源匹配，记录每步失败原因。
   - `lx_download_manager.dart`：串行 4 阶段队列（`解析直链` -> `网络下载` -> `文件头校验` -> `标签与入库`），复用 Namida `FilesDownloadManager`、`NamidaTaggerController.writeTagsRaw`、`Indexer.inst.convertPathToTracksAndAddToListsSingle`、`NamidaChannel.inst.scanMediaFilesTry`，支持双语/罗马音 `.lrc` 时间戳交错合并导出、取消与断点阶段重试。
   - `lx_music_page.dart`：3 Tab 界面（搜索下载 / 下载管理 / 音源与日志），支持单曲与多选批量下载、完整滚动歌词查看（原文/翻译/罗马音切换）、下载目录与偏好设置、已完成曲目一键 `Player.inst.playKeepingQueue` 播放。
   - `lx_app_bar_icon.dart`：顶栏快捷入口（含活跃下载角标）。
5. **Namida 原生代码最小挂钩（仅 3 处）**：
   - `lib/ui/pages/main_page.dart`：顶栏新增 `const LxMusicAppBarIcon(),`。
   - `lib/main_page_wrapper.dart`：左侧抽屉新增 `LX Music` 项。
   - `lib/ui/pages/settings_page.dart`：设置页（展开与折叠双布局）保留 `LX Music 音源与下载` 入口直达 Tab 2。

---

## 5. 关键已核验技术备忘（阶段 3 避免踩坑）

- **Dart 泛型推断**：Record 里返回空列表时必须显式写类型（如 `const <LxUserApiMeta>[]`），否则 Dart 3.13 `dart analyze` 会报 `return_of_invalid_type`。
- **`FilesDownloadManager.inst.download`**：`downloadingStream` 回调传入的是 `bytesDelta`（增量字节，断线重置时可能为负），目前已做下限 0 钳位；若阶段 3 要显示精确百分比进度，可在下载前发一次轻量 `HEAD`（或从响应头）获取 `Content-Length` 传给 `totalBytes`。
- **Android 后台保活现状**：`NamidaChannel.inst.setKeepRunningInBackground` 在 Namida 上游仅 iOS 有实现，Android 侧为空实现；若阶段 3 需要息屏大批量下载不断流，可评估复用前台通知/WorkManager 或轻量前台 Service。
- **Namida 原生主题体系**：Namida 拥有自研 `NTheme` / `NBuilder` / `NColors` / `NamidaText` / `BackgroundWrapper` / `NamidaMascotBackground` / `CustomListTile` / `CustomBlurryDialog` / `SuperSmoothListView` 与自定义圆角倍率（`.multipliedRadius`）、字体（`LexendDeca`）和图标库（`Broken.*`），阶段 3 美化应优先对齐这些原生视觉语言，而不是停留在朴素默认 Material 3 卡片。

---

## 6. 下一对话直接启动的任务清单（阶段 3：UI 美化与体验打磨）

> 建议从当前分支 `feat/lx-stage2-download` 切出 `feat/lx-stage3-polish` 推进。

### 6.1 贴合 Namida 原生主题的视觉升级（核心重点）
- [ ] **融入 Namida 主题体系**：用 Namida 的 `BackgroundWrapper`、渐变背景、`NTheme`/`NBuilder`/`NColors`、`NamidaText`、`Broken.*` 图标、圆角倍率（`.multipliedRadius`）和 `SuperSmoothListView` 重塑 `LxMusicPage` 三个 Tab 的视觉质感，保持亮/暗色、莫奈取色、自定义强调色与 Namida 主界面浑然一体。
- [ ] **搜索结果卡片美化**：为搜索列表接入封面缩略图（懒加载 + 圆角占位图 + 内存缓存）、更精致的音质徽章（区分无损 `Hi-Res`/`SQ`/`HQ` 配色）、单曲操作微交互（已入队/下载中/已完成状态直接在搜索结果项上反馈，避免重复点击）。
- [ ] **沉浸式歌词浮层 / BottomSheet**：将展开面板里的歌词查看器升级为更舒适的底部弹窗或独立卡片，支持更清晰的排版、搜索/复制与原文+翻译双语同屏预览。
- [ ] **下载任务卡片美化**：展示封面缩略图、清晰的分阶段状态步骤条/颜色徽章、精确百分比进度（可选通过 `HEAD` 探测 `Content-Length` + 实时下载速度显示）、批量操作与一键定位到曲库/立即播放。
- [ ] **音源管理与弹窗美化**：使用 Namida 风格的毛玻璃弹窗（如 `CustomBlurryDialog`）承载「在线 URL 导入」和音源详情（展示作者、版本、描述、主页链接与支持平台矩阵），并支持第三方音源发出的 `showUpdateAlert` 提示事件。

### 6.2 交互与稳定性细节打磨
- [ ] **防重复下载与去重提示**：下载目录已存在同名歌曲或队列已有相同曲目时给出明确提示/状态标识。
- [ ] **并发数可配置**：在下载设置中增加 `并发数（1 / 2 / 3）` 选项（默认仍为 1 保稳）。
- [ ] **搜索体验增强**：支持保留/清空最近搜索历史、切换平台自动保留关键词并可一键重搜、支持搜索框一键清除。
- [ ] **分支收尾与合并**：阶段 3 真机验收通过后，由用户确认是否将特性分支合并回 `hikjesen/namida` 的 `main` 分支。
