# Namida LX 集成项目交接文档（Stage 0 -> Stage 1）

> **更新时间**：2026-11-24  
> **当前分支**：`feat/lx-stage0-ci`（基于 `hikjesen/namida` `main`）  
> **当前阶段**：✅ **Stage 0 完成并已通过真机验收** -> 准备进入 **Stage 1（前置固定签名 + QuickJS 桥接与搜索/自定义源原型）**

---

## 1. 项目目标与工作区拓扑

- **项目目标**：在个人 Fork [`hikjesen/namida`](https://github.com/hikjesen/namida) 中集成 LX Music 的多平台音乐搜索、用户自导入第三方 `.js` 自定义音源解析、音频下载校验、内嵌标签封面与 LRC 导出、以及自动刷新本地曲库的一体化体验。
- **本地工作区**：
  - 主开发仓库：`d:\namida项目\namida`（分支 `feat/lx-stage0-ci`，远端 `origin` = `https://github.com/hikjesen/namida.git`）
  - 只读参考仓库：`d:\namida项目\lx-music-mobile`（分支 `feature/android-download-mvp`，远端 `https://github.com/hikjesen/lx-music-mobile.git`）
- **开发与验收约束**：
  - 本机无 Flutter / Dart / Java 环境（仅安装有 `git`、`gh`、`node`、`npm`、`codex`），全程依赖 **GitHub Actions 免费构建**出 Android ARM64 Release APK，用户下载 Artifact 到真机测试反馈。
  - **严禁提交任何第三方自定义音源 `.js` 文件、Cookie、私密 Token 或个人敏感凭据**。

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
  - 若需要验证 `gh` 操作：本机 `gh` 已登录账号 `hikjesen`（具 `repo`、`workflow` 权限）。

---

## 4. Stage 0 已落地基线与实测验收

### 4.1 上游 Namida 闭源依赖勘测与解决

上游 `namidaco/namida` 有 7 个私有闭源仓库（见 `README.md:373` 与上游 issue `#37`），已全部通过 `packages_compat/` 本地 Clean-Room 兼容包与公开源回退解决，**Namida 原生 `lib/` 代码保持 0 侵入改动**：

| 原私有依赖 | 处理方式 | 实现位置 / 状态 |
| :--- | :--- | :--- |
| `namidaco/basic_audio_handler` | Clean-Room 实做（`just_audio` + `audio_service` + `audio_session` + `nampack`） | `packages_compat/basic_audio_handler/`（支持队列、播放控制、通知栏、音频焦点、洗牌/重排、EQ/配置接口；暂未实现 gapless、重叠 crossfade、Android 外部字幕） |
| `namidaco/playlist_manager` | Clean-Room 实做（JSON 持久化 + M3U/备份/同步钩子） | `packages_compat/playlist_manager/`（支持创建/改名/排序/收藏/标签心情等） |
| `namidaco/youtipie` | 编译期离线空壳 Stub（启动完成双 Completer，网络拉取返回空） | `packages_compat/youtipie/`（86 文件覆盖全部 84 处导入 URI） |
| `namidaco/namico_login_manager` | 最小无登录空壳 | `packages_compat/namico_login_manager/` |
| `namidaco/namico_subscription_manager` | 最小免费状态空壳 | `packages_compat/namico_subscription_manager/` |
| `MSOB7YY/flutter_sharing_intent` | 最小空流空壳 | `packages_compat/flutter_sharing_intent/` |
| `MSOB7YY/ffmpeg_build`（子模块） | 移除 `pubspec.yaml` 中 `hooks.user_defines.ffmpeg_kit_extended_flutter` 本地路径覆盖 | 构建时自动下载 `ffmpeg_kit_extended_flutter` 公开 LGPL Android 二进制；CI 仅初始化 3 个公开子模块（`--remote`） |

### 4.2 共存包名与 GitHub Actions CI

- **共存配置**：
  - `android/app/build.gradle.kts`：保留 `namespace = "com.msob7y.namida"`，修改 `applicationId = "com.msob7y.namida.lx"`；通过 `ORG_GRADLE_PROJECT_namidaLxArm64=true` 输出单一 ARM64 APK。
  - `android/app/src/main/AndroidManifest.xml` & `strings.xml`：应用名、快捷磁贴与小组件标签改为 `Namida LX` / `Namida LX Shuffle`；所有 `authorities` 已使用 `${applicationId}`。
- **CI 工作流**：`.github/workflows/android-lx-build.yml`
  - 流程：拉取 3 个公开子模块（带 `--remote` 拉齐 `external/language` 最新翻译）-> 清理磁盘 -> Java 17 + Flutter `3.47.8` -> `flutter pub get` -> `flutter gen-l10n` -> `dart analyze --no-fatal-warnings lib packages_compat` -> `flutter build apk --target-platform android-arm64 --release` -> 上传 Artifact `namida-lx-arm64-apk`。
- **最新全绿构建与真机反馈**：
  - Run `45391810485`（commit `fd8c84bc`，耗时 `13m36s`）：https://github.com/hikjesen/namida/actions/runs/45391810485
  - Artifact：`namida-lx-arm64-apk`（`49,867,695 bytes` / ~47.6 MB）
  - **用户真机实测结论**：✅ **可与官方 Namida 共存安装，初步启动与本地播放均无问题。**

---

## 5. 已拍板的最终 LX 集成技术方案

用户已确认同意以下最终架构（相比前期简报，关键升级为 **Android 原生 QuickJS 替代 `HeadlessInAppWebView`**）：

1. **自定义 `.js` 音源运行时（Android 原生 QuickJS）**：
   - 直接移植 `d:\namida项目\lx-music-mobile` 在 Android 端已验证成熟的方案：
     - 依赖：`wang.harlon.quickjs:wrapper-android:2.4.0`
     - 参考源码：`lx-music-mobile/android/app/src/main/java/cn/toside/music/mobile/userApi/{QuickJS,JavaScriptThread,Console,HandlerWhat}.java`、`crypto/{AES,RSA}.java`、`assets/script/user-api-preload.js`
   - 落在 Namida 独立目录 `android/app/src/main/kotlin/com/msob7y/namida/lx/`，通过 Flutter `MethodChannel` / `EventChannel` 与 Dart 层 `lib/lx_music/` 通信。
   - **HTTP 代理统一走 Dart 侧 `rhttp`**：QuickJS 发起的 `lx.request(...)` 转发至 Dart 侧使用 Namida 现有 `rhttp` 代发（无 CORS 限制、自动复用 Namida 代理设置、带阶段诊断日志）。
   - **优势**：100% 协议级兼容所有现有 LX 第三方 `.js` 音源，无 WebView 后台/息屏被杀问题，内存与稳定性远优于 `HeadlessInAppWebView`。
2. **多平台搜索与歌词层（`musicSdk`: `kw`/`kg`/`tx`/`wy`/`mg`）**：
   - 使用本机 `node`（可配 `esbuild`）将精简版 `lx-music-mobile/src/utils/musicSdk` 打包为独立 JS Bundle 放入 `assets/lx/`，在独立 QuickJS Context 中执行并复用同一条 `rhttp` HTTP 代理通道。
3. **下载、校验、标签封面与自动入库流水线**：
   - 移植 `lx-music-mobile/src/core/download/resolver.ts` 的渐进音质降级与自动换源策略（`flac24bit` / `flac` / `320k` / `128k`），记录每步失败原因。
   - 复用 Namida 原生模块：
     - `lib/controller/files_download_manager.dart`（独立 Isolate 可恢复下载）
     - `NamidaChannel.inst.setKeepRunningInBackground(true/false)`（Android 后台保活）
     - `lib/controller/tagger_controller.dart`（`NamidaTaggerController` 写入标题/歌手/专辑与内嵌封面）
     - `lib/controller/indexer_controller.dart`（增量刷新本地曲库）
   - 移植 `lx-music-mobile/android/app/src/main/java/cn/toside/music/mobile/utils/AudioDownloadHelper.java` 的**音频文件头魔数校验**（MP3/FLAC/M4A/OGG/WAV/APE），拦截假无损或 HTML 错误页并修正真实后缀。
   - 同步导出同名 `.lrc` 歌词（含翻译/罗马音），保留分阶段诊断错误（`解析直链` / `网络下载` / `文件头校验` / `标签与入库`）。
4. **架构隔离原则**：
   - 新增 Dart 业务全部收敛在 `lib/lx_music/`，新增 Android 原生代码收敛在 `android/app/src/main/kotlin/com/msob7y/namida/lx/`，对 Namida 原有代码仅留极少量清晰入口挂钩。

---

## 6. 下一对话直接启动的任务清单

### 阶段 1 前置（快速收尾，用户已同意）
- [ ] **统一固定测试签名**：
  - 当前 `android/app/build.gradle.kts` 在无 `android/key.properties` 时会回落使用 Runner 每次随机生成的 `debug.keystore`，导致每次装新测试 APK 都必须先卸载旧包（丢失本地设置与音源）。
  - 方案（二选一，建议首选方案 A）：
    - **方案 A（推荐，最安全干净）**：在 CI 或一次性脚本生成一份个人固定 keystore，将其 base64 与 `key.properties` base64 通过 `gh secret set` 写入 `hikjesen/namida` 的 Actions Secrets（如 `LX_ANDROID_KEYSTORE_B64`、`LX_ANDROID_KEY_PROPERTIES_B64`），并在 `.github/workflows/android-lx-build.yml` 中按 Secret 存在与否自动解码写入 `android/app/keystore.jks` 与 `android/key.properties`（因为本机无 `keytool`，也可在一次短 CI job 里生成或用 `node` crypto 配合一次 workflow 导出，或在公开开发期像 `lx-music-mobile` 一样明确标注一份公开测试签名）。
    - **方案 B（最省事）**：仓库内附带一份明确声明“仅公开个人测试用、非正式发布签名”的固定测试 keystore（与用户之前 `hikjesen/lx-music-mobile` 做法一致），零 Secret 依赖，任何分支自动统一签名覆盖安装。

### 阶段 1：LX 搜索与自定义源桥接原型（优先派 Codex 攻坚）
- [ ] 在 `android/app/build.gradle.kts` 接入 `wang.harlon.quickjs:wrapper-android:2.4.0`。
- [ ] 移植 Android 原生 QuickJS 运行时（`HandlerThread` + `user-api-preload.js` + AES/RSA/MD5/Base64/setTimeout 桥接 + Flutter `MethodChannel`/`EventChannel`），落在 `android/app/src/main/kotlin/com/msob7y/namida/lx/`。
- [ ] 在 `lib/lx_music/` 实现 `LxBridgeService`：
  - 支持从本地文件导入用户第三方 `.js` 自定义音源、持久化保存到应用私有目录、加载并回报初始化状态与支持平台/音质列表；
  - 将 QuickJS 的 HTTP 请求通过 Namida 现有 `rhttp` 代发并回传响应/错误；
  - 使用本地 `node` 打包精简版 `musicSdk`（`kw`/`kg`/`tx`/`wy`/`mg`）JS Bundle 到 `assets/lx/`，打通 `search(keyword, source, page)`、`getMusicUrl(track, quality)`、`getLyric(track)`。
- [ ] 挂载一个最小入口（设置页或侧边栏）进入 **LX 原型诊断页**：支持导入 `.js` 音源、查看初始化状态/日志、输入关键词搜索并点选单曲测试“解析直链 + 拉取歌词”，推 CI 出 APK 给用户真机实测。

### 阶段 2：下载、校验、标签封面写入与自动入库
- [ ] 移植 `resolver.ts` 音质降级与自动换源策略。
- [ ] 对接 `FilesDownloadManager` + 后台保活 + 音频魔数校验与后缀修正。
- [ ] 对接 `NamidaTaggerController` 写入元数据与内嵌封面、保存同名 `.lrc` 歌词、调用 `Indexer` 刷新曲库。
- [ ] 完整保留分阶段失败诊断信息，出包真机验收。

### 阶段 3：贴合 Namida 主题的正式 UI 与真机回归
- [ ] 音源管理设置页（导入/切换/删除 `.js`、初始化状态与日志）。
- [ ] LX 搜索页（平台切换、关键词搜索、单曲/多选下载、音质选择）。
- [ ] 下载任务管理页（进度、并发/串行控制、失败阶段诊断、重试、一键定位/播放已入库曲目）。
