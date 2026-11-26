# Eclogae（原 Namida「在线曲库 & 悬浮歌词」）项目交接文档（Stage 0 ~ Stage 6.5 完成）

> **更新时间**：2026-11-26
>
> **当前分支**：`main`（已合入 Stage 0 ~ Stage 6.5 全部提交，里程碑 Tag：`v8.6.7-eclogae-stage6.5`）
>
> **当前状态**：✅ **Stage 0 ~ Stage 6.5 全部合并回 `main`**（**Eclogae** 独立身份 `com.wander.eclogae`、作者 `Hiko & Wan`、独立 CI 与翻译内置化均已落地并全绿产出 ARM64 APK）-> 下次会话优先处理 **3 项小修（见 §7.1）** -> **Stage 7（五平台原生评论区适配）** -> 后续阶段（上游插件自主化、吉祥物与图标重塑等，私有化延后至这些阶段之后）。

---

## 1. 项目目标与工作区拓扑

- **项目身份（Stage 6.5 起独立演进，不再跟踪上游 Namida 更新）**：
  - **应用名**：`Eclogae`
  - **作者署名**：`Hiko & Wan`（**严禁使用 `hikjesen` 作为应用内作者名**）
  - **Android `applicationId` / `namespace` / Kotlin 包路径**：`com.wander.eclogae`
  - **Dart 包名**：`eclogae`（全库 `package:eclogae/...`）
  - **原生平台通道**：`eclogae`、`eclogae/storage`、`eclogae/lx_bridge`、`eclogae/lx_events`、`eclogae/floating_lyrics`
- **项目核心能力**：高定制化音乐播放器底座 + 「在线曲库」（多平台聚合/分源歌曲与歌单搜索、关键词联想、第三方 `.js` 自定义音源本地/URL 导入、主播放器原生在线试听含封面/双语歌词/边播边缓/波形条/单曲循环、多音质并发下载校验、内嵌标签封面与完整 `.lrc` 导出、歌单子文件夹归档与外部歌单链接直达导入）+ **Android 原生轻量悬浮歌词**（自由定制配色/描边/RGB与图片吸管取色、翻译/罗马音独立开关、4 键浮层控制、Android 12+ 锁定穿透、媒体通知栏自定义按钮与防锁死静默解锁通知）。
- **本地工作区**：
  - 主开发仓库：`d:\namida项目\namida`（当前分支 `main`，里程碑 Tag `v8.6.7-eclogae-stage6.5`，当前远端 `origin` = `https://github.com/hikjesen/namida.git`；**用户计划后续手动将 GitHub 仓库改名为 `Eclogae`**，若下次会话 push/gh 提示远端地址变更，先核对 `git remote -v` 并按需更新为新 URL）
  - 只读参考仓库：`d:\namida项目\lx-music-mobile`（分支 `feature/android-download-mvp`，远端 `https://github.com/hikjesen/lx-music-mobile.git`）
- **开发与验收约束**：
  - 本机无 Flutter / Dart / Java 环境（仅安装有 `git`、`gh`、`node`、`npm`、`codex`），全程依赖 **GitHub Actions 免费构建**（`dart analyze` + ARM64 Release APK），用户下载 Artifact 到真机测试反馈。
  - **严禁提交任何第三方自定义音源 `.js` 文件、第三方音源链接、Cookie、私密 Token、个人敏感凭据或 APK 二进制文件入库**。
  - **用户可见界面命名规范**：应用品牌统一为 `Eclogae`；在线模块统一使用「在线曲库」「在线曲库设置」「在线试听」「悬浮歌词」等命名（去 "LX" 化）；内部目录 `lib/lx_music/`、`lib/floating_lyrics/` 保持架构隔离。

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

### 4.1 里程碑构建总表

| 阶段 | 分支 / Commit | CI Run | Artifact 大小 | 验收结论 |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 0** | `feat/lx-stage0-ci` (`fd8c84bc`) | [45391810485](https://github.com/hikjesen/namida/actions/runs/45391810485) (`13m36s`) | `49,867,695 bytes` | ✅ Clean-Room 兼容包 + 共存包名 + 本地播放通过 |
| **Stage 1** | `feat/lx-stage1-bridge` (`c5b1dac2`) | [45412490417](https://github.com/hikjesen/namida/actions/runs/45412490417) (`13m24s`) | `50,634,615 bytes` | ✅ 固定签名生效 + Android 原生 QuickJS 双引擎 + 5 平台搜索/歌词/自定义源直链解析通过 |
| **Stage 2 (MVP)** | `feat/lx-stage2-download` (`e77de574`) | [45422922524](https://github.com/hikjesen/namida/actions/runs/45422922524) (`16m26s`) | `50,732,057 bytes` | ✅ 固定签名覆盖安装 + URL 导入 + 4 阶段下载/魔数校验/标签封面/完整 `.lrc`/即时入库通过 |
| **Stage 3 (美学重构)** | `feat/lx-stage3-polish` (`d3595ca5`) | [45566841964](https://github.com/hikjesen/namida/actions/runs/45566841964) (`15m+`) | ARM64 APK | ✅ 原生美学重构、底栏替换为「在线曲库」、毛玻璃音质窗、记住音质、并发 1-3、防重检测、HEAD 探测 |
| **Stage 4 (在线试听与歌单)** | `feat/lx-stage3-polish` (`a2360084`) | [45606440084](https://github.com/hikjesen/namida/actions/runs/45606440084) (`15m+`) | ARM64 APK | ✅ 搜索状态持久化、聚合全源 + 联想词、主播放器原生试听/稍后播放、五平台歌单搜索与整单下载 |
| **真机反馈打磨 R2** | `feat/lx-stage3-polish` (`d968cf9f`) | [45617854104](https://github.com/hikjesen/namida/actions/runs/45617854104) (`15m+`) | ARM64 APK | ✅ 单行搜索栏、下载管理并入「在线曲库设置」双 Tab、右上角齿轮切换、试听边播边缓与波形条通过 |
| **单曲循环根因修复 R3** | `feat/lx-stage3-polish` (`5f449d3d`) -> `main` (`v8.6.7-lx-stage4`) | [45629267767](https://github.com/hikjesen/namida/actions/runs/45629267767) (`15m28s`) | `50,772,738 bytes` | ✅ 接入原生 `LoopMode.one` / `loop-file=inf` + 安全 EOF 重载兜底，本地与在线试听单曲循环全通过 |
| **Stage 5（歌单体验与缓存修复）** | `feat/lx-stage5-fixes` (`54613a3c`) -> `main` (`v8.6.7-lx-stage5`) | [45757092704](https://github.com/hikjesen/namida/actions/runs/45757092704) (`17m35s`) | `50,781,361 bytes` | ✅ 歌单子文件夹归档、递归防重、音频后缀对齐、封面缓存清理、大歌单分页下载、外部链接直达导入通过 |
| **Stage 6（Android 原生悬浮歌词）** | `feat/lx-stage6-floating-lyrics` (`52faf3be`) | [45799484707](https://github.com/hikjesen/namida/actions/runs/45799484707) (`19m24s`) | `50,821,387 bytes` | ✅ 原生 Kotlin `TYPE_APPLICATION_OVERLAY` 悬浮窗、4 键浮层、Android 12+ 锁定穿透、媒体通知双键与解锁兜底 |
| **Stage 6 R2（横屏/省电/取色/双语拆分）** | `feat/lx-stage6-floating-lyrics` (`a0a82026`) -> `main` (`v8.6.7-lx-stage6`) | [45808913273](https://github.com/hikjesen/namida/actions/runs/45808913273) (`15m22s`) | `50,836,243 bytes` | ✅ 横屏顶部全屏边界、隐身保活减少系统通知重弹、四重省电、8–34 sp / 2–8 行、翻译/罗马音拆分、RGB 与吸管取色全通过 |
| **Stage 6.5（Eclogae 独立化重塑）** | `feat/stage6.5-eclogae-rebrand` (`7f36fd8b`) -> `main` (`v8.6.7-eclogae-stage6.5`) | [45819402466](https://github.com/hikjesen/namida/actions/runs/45819402466) (`15m26s`) | `50,554,751 bytes` (`eclogae-arm64-apk`) | ✅ 独立包名 `com.wander.eclogae`、Dart 包 `eclogae`、作者 `Hiko & Wan`、30 份翻译内置、隐藏在线一起听、独立 CI 全绿并已合入 `main`（3 项细节小修留待下次会话） |

### 4.2 统一固定签名与 CI（已切换至 Eclogae 独立工作流）
- 已配置 GitHub Actions Secrets：`LX_ANDROID_KEYSTORE_B64`、`LX_ANDROID_KEY_PROPERTIES_B64`（PKCS12 Keystore，本地私钥生成后已销毁、永不入库）。
- [.github/workflows/android-eclogae-build.yml](../.github/workflows/android-eclogae-build.yml)（Workflow 名：`Build Eclogae for Android`，产物名：`eclogae-arm64-apk`，APK 名：`eclogae-v<version>-arm64-v8a.apk`）自动解码签名配置并仅初始化 `external/party_relay` 子模块。
- 后续所有 `Eclogae`（`com.wander.eclogae`）ARM64 Release APK **均可直接覆盖安装，保留本地设置与已导入音源**。

---

## 5. 已完成模块全景清单

### 5.1 闭源兼容包与播放引擎（`packages_compat/`）
- `packages_compat/basic_audio_handler`、`playlist_manager`、`youtipie`（离线空壳）、`namico_login_manager`、`namico_subscription_manager`、`flutter_sharing_intent`。
- **原生单曲循环与 EOF 重载修复**（`5f449d3d`）：`AVPlayer.setLoopOne(bool)` + `CustomMpvPlayer.setLoopOne` + `handler.dart` 自动启用原生单曲循环与干净 EOF 重载。

### 5.2 Android 原生双上下文 QuickJS 运行时与 SDK Bundle
- `android/app/src/main/kotlin/com/wander/eclogae/lx/`：
  - `LxCrypto.kt`、`LxUserApiRuntime.kt`、`LxMusicSdkRuntime.kt`、`LxQuickJsBridge.kt`（`MethodChannel("eclogae/lx_bridge")` + `EventChannel("eclogae/lx_events")`）。
  - R8 keep 规则位于 `android/app/proguard-rules.pro`（`com.whl.quickjs.**`、`com.wander.eclogae.lx.**`）。
- `tools/lx_music_sdk/` & `assets/lx/`：
  - `assets/lx/music-sdk-bundle.js`：导出 `kw`/`kg`/`tx`/`wy`/`mg` 五平台的 `musicSearch`、`tipSearch`、`songList`、`lyric`、`pic`，附 `smoke_test.mjs`。
  - `assets/lx/user-api-preload.js`：与 `lx-music-mobile` 协议逐字节一致。

### 5.3 Dart「在线曲库」业务层与原生风格 UI（全部收敛在 `lib/lx_music/`）
- **核心服务与状态**：`lx_models.dart`、`lx_http_proxy.dart`、`lx_user_api_store.dart`、`lx_bridge_service.dart`、`lx_audio_sniffer.dart`、`lx_download_resolver.dart`、`lx_download_manager.dart`、`lx_songlist_link_parser.dart`、`lx_search_controller.dart`、`lx_preview_player.dart`。
- **页面与组件**：`lx_music_page.dart`、`lx_songlist_detail_page.dart`、`lx_settings_page.dart`（双 Tab：`设置 | 下载管理`）、`lx_app_bar_icon.dart`、`widgets/*`。

### 5.4 Stage 6：Android 原生悬浮歌词系统（`lib/floating_lyrics/` & `android/.../com/wander/eclogae/floatinglyrics/`）
- **Android 原生层**：`FloatingLyricsBridge.kt`（`MethodChannel("eclogae/floating_lyrics")`）、`FloatingLyricsManager.kt`（全屏横屏边界 + 1×1 隐身保活态 + Android 12+ 锁定穿透）、`FloatingLyricsOverlayView.kt`（4 键浮层、自定义文字/描边色、2–8 行、~30fps 单次跑马灯）、`FloatingLyricsLockNotification.kt`、`FloatingLyricsActionReceiver.kt`、4 套 24dp 矢量图标。
- **Dart 业务与设置页**：`floating_lyrics_models.dart`、`floating_lyrics_store.dart`、`floating_lyrics_channel.dart`、`floating_lyrics_controller.dart`、`floating_lyrics_settings_page.dart`、`floating_lyrics_eyedropper_dialog.dart`。

### 5.5 Stage 6.5：Eclogae 独立化重塑（档位 A，已合入）
- **包与代码路径**：`pubspec.yaml` 包名改为 `eclogae`，490 个 Dart 文件共 5,800 处 `package:namida/` 迁至 `package:eclogae/`；36 个 Android Kotlin 源码与测试文件从 `com/msob7y/namida` 迁至 `com/wander/eclogae`；全部 5 条平台通道统一前缀 `eclogae`。
- **翻译与上游清理**：移除 `external/language` 与 `external/namida-assets` 子模块，将 30 份最新 `.arb` 内置至 `l10n/translations/`（`l10n.yaml` 指向 `l10n/translations`）并将可见文案中的 `Namida` 替换为 `Eclogae`；删除上游非 Android workflows 及 Issue/PR/Funding 模板；重写 `README.md`。
- **界面去上游化**：`about_page.dart` 改为 **Eclogae / Hiko & Wan** 并移除上游社交/捐赠/开发卡片与头像抓取；`version_controller.dart` 禁用上游 GitHub Release 检查；**在线一起听（Online Party）**入口从侧边栏、资料库标签设置、顶栏、设置建议、YouTube 队列与邀请链接全面隐藏；Manifest 移除 Party/Patreon/Discord 深链过滤。
- **按约定暂保留（留待后续专门阶段改造）**：内置罗马音词典下载包地址（`https://files.namida.app/romanization_v1.zip`）、现有应用图标与吉祥物（Jellyda / Namiween）、`pubspec.yaml` 中上游 Git 插件依赖以及 `external/party_relay` 子模块。

---

## 6. 关键已核验技术备忘（避免踩坑）

1. **Android ExoPlayer 单曲循环切勿在 `STATE_ENDED` 下硬 `seek(0)`**：常规单曲循环走 `AVPlayer.setLoopOne(true)`；需从 `STATE_ENDED` 重播时必须重新加载音频源。
2. **在线试听音频波形与边播边缓**：复用 `http_cache_stream` 落盘到 `AppDirs.APP_CACHE/preview_audio/` 后，下载完成回调即可触发 `WaveformController.inst.generateWaveform(...)`。
3. **Dart 3.13 泛型推断**：Record 或表达式里返回空列表时必须显式写类型（如 `const <VersionReleaseInfo>[]`、`const <LxUserApiMeta>[]`）。
4. **`MSOB7YY/rhttp` 重定向与最终 URL**：`LxHttpProxy` 配置 `RedirectSettings.none()` 并手工跟跳 3xx 后回传最终 `'url'`。
5. **Android 悬浮窗实测避坑（Stage 6 沉淀）**：
   - **Android 12+ 锁定穿透**：`FLAG_NOT_TOUCHABLE` 必须钳位 `alpha <= minOf(userAlpha, 0.8f, inputManager.maximumObscuringOpacityForTouch)`。
   - **横屏顶部自由摆放**：API 30+ 设 `params.fitInsetsTypes = 0` + `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS` + `maximumWindowMetrics.bounds`。
   - **抑制系统悬浮权限通知频繁重弹**：用 1×1 `alpha = 0f` + `FLAG_NOT_TOUCHABLE` 的 `suppressed` 保活态替代 `removeView`/`addView`。
   - **省电四要素**：息屏广播同步停推、200ms 行号短路、单次跑马灯 ~30fps 节流、描边时关闭冗余 `setShadowLayer`。
6. **CI 监控**：代理环境下 `gh run watch` 偶发 `wsarecv` 断开，用 `gh run view --json status,conclusion,jobs` 配合定时检查即可稳定跟踪。

---

## 7. 后续演进路线图与下次会话待办

### 7.1 下次会话优先处理（Stage 6.5 收尾小修，建议合并至一个短分支或并入 Stage 7 前置提交）
1. **修复首次打开建立索引库时默认扫描 `Namida` 文件夹的问题**：排查初始化默认扫描目录 / 索引器默认路径（先核验 `lib/controller/indexer_controller.dart`、`lib/core/app_dirs.dart` / `constants.dart` 及首次引导页代码），避免首次建库仍出现 `namida` 目录并展示旧名称。
2. **移除关于页应用版本旁的「许可（License）」按钮**：清理 `lib/ui/pages/about_page.dart` 中应用版本旁边的开源许可入口（个人自用项目无需展示）。
3. **版本号切换至独立语义版本 `1.0.1`**：将 `pubspec.yaml` 中的 `version` 从 `8.6.7+...` 调整为 `1.0.1+<更高或递增的 versionCode>`（**注意 Android `versionCode` 必须严格大于当前已安装版本的 `versionCode`，否则无法覆盖安装！** 修改前务必先核验 `pubspec.yaml` 与 `android/app/build.gradle.kts` 的 `versionCode` 计算逻辑）。

### 7.2 阶段性规划
- [x] **Stage 0 ~ Stage 6.5 合并回 `main`**：已 fast-forward 合并并打 Tag `v8.6.7-eclogae-stage6.5`。
- [ ] **GitHub 仓库改名（用户手动操作）**：用户计划手动将当前仓库重命名为 `Eclogae` 并删除旧同名仓库。
- [ ] **Stage 6.5 收尾小修（§7.1 三项）**。
- [ ] **Stage 7：五平台原生评论区适配**
  - 复用 `lx-music-mobile` 五平台 `comment.js` 经 `tools/lx_music_sdk/entry.js` 导出评论 RPC，并以原生毛玻璃面板呈现热门/最新评论与分页加载。
- [ ] **Stage 8+（待细化，私有化延后至这些阶段之后）**：
  - 自主化/替换 `pubspec.yaml` 中仍指向 `MSOB7YY` 的上游 Git 插件与 `external/party_relay`、罗马音词典托管；
  - 替换应用图标、启动图标别名与吉祥物（Jellyda / Namiween）；
  - 按需增强：Android 息屏大批量下载前台保活 Service、歌单广场 / 排行榜浏览；
  - 待核心上游解耦与视觉重塑完成后，再将仓库转为私有长期维护（全过程坚持不往 Git 仓库提交 APK）。
