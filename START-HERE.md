# 路慢慢：换电脑接手入口

打包日期：2026-09-10。源码版本：0.9.1+10。Android 包名：com.lumanman.app。

## 先读这些

1. `HANDOFF.md`：功能、数据结构、语音问题、社区计划和验证边界。
2. `AGENTS.md`：协作约束。
3. `work/design-spec/UI-DESIGN-DECISIONS.md` 与 `IMPLEMENTATION-LOCK.md`：已确认设计和禁止事项。
4. `work/design-spec/approved/`：锁定视觉与宠物素材；`implementation/`：实际渲染截图及历史验收。

## 换电脑开发

建议把整个 lumanman 文件夹解压到短路径，例如 Windows `D:\Projects\lumanman`，macOS `~/Projects/lumanman`。用编辑器或 AI 编程工具打开整个 lumanman 根目录；Flutter 命令在里面的 app 目录执行。

原电脑实测工具链：Flutter 3.47.1 stable（revision 6655482ec0）、Dart 3.13.1、Java 17.0.20.1。Android 编译 SDK 36；包的最低 Android API 24、目标 API 36。项目锁定 Gradle 9.3.1、Android Gradle Plugin 9.1.0、Kotlin plugin 2.4.0。先复现这一组合，不要一开始批量升级依赖。

安装 Flutter SDK、Android Studio/Android SDK、JDK 17，将 flutter 加入 PATH，然后执行：

```sh
flutter doctor -v
flutter doctor --android-licenses
cd app
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

成功产物：`app/build/app/outputs/flutter-apk/app-debug.apk`。连接开启 USB 调试的 Android 手机后，可在 app 目录执行 `flutter devices` 和 `flutter run -d <设备ID>`。仅安装 SDK 或在 IDE 中打开文件不等于已经能编译，以 doctor 和实际构建结果为准。

本包已把原来的 C 盘本地 Gradle 下载地址替换为官方 HTTPS 地址，版本和 SHA-256 不变。首次构建需要联网下载 Gradle、插件、Dart 依赖及缺少的 Android 工具。包不是离线开发环境，不含 Flutter/JDK/SDK 安装器。

`local.properties`、构建缓存和 IDE 配置故意未打包。请通过 Flutter 命令生成适合新电脑的配置；若 doctor 报 SDK/JDK 路径问题，使用 `flutter config --android-sdk <新SDK路径>` 或 `flutter config --jdk-dir <新JDK路径>` 后重试。不要照搬旧电脑路径。

## 旧手机覆盖安装

最新现成 APK 位于 `release/lumanman-v0.9.1-speech-fix.apk`。源码包不含签名私钥。随附独立的 `lumanman-private-signing-2026-09-10.zip`，只交给可信开发者，按其中说明在新项目内配置。

新电脑默认生成另一把调试密钥，生成的 APK 可能无法覆盖原应用。不要用卸载旧应用来解决：现有数据保存在手机应用私有目录中，卸载存在丢失数据的风险。先确认旧数据备份，再处理签名或更换正式签名。

## 给另一位 AI 的接手提示词

> 这是“路慢慢”Flutter 项目的迁移包。先完整阅读 START-HERE.md、HANDOFF.md、AGENTS.md 和 work/design-spec/ 下两份设计约束，核对当前源码与已确认素材。Flutter 工程在 app/，当前 Android 版本 0.9.1+10。遵守原有视觉确认流程，不重做受保护页面，不把参考截图中的测试记录写成真实数据。语音转文字仍未完成用户真机验收，先定位而非假定已修好。社区、账号、云同步和 iOS 都是未实现方向。请先复现环境、跑检查和测试，再按我这次指定的任务修改；说明哪些结果已验证、哪些仍待真机确认。手机数据和调试签名迁移按文档单独处理。

## 长期协作方案

把此包作为首份归档；持续改进建议用 Git 私有仓库同步源码，保留提交历史，换电脑先拉取、完成修改再提交推送。当前原项目没有 Git 历史，这份包也不伪造历史。尚未替你创建或上传任何远程仓库。

初次在本文件所在目录执行 `git init` 后，用 `git add -n .` 检查将提交的文件，再创建初始提交。根 .gitignore 排除了缓存、APK、密钥和主要历史预览资料；正式运行素材仍在 app/assets/，设计规范、approved 与 references 保留。历史视频等大文件留在迁移归档，需要版本管理时再单独规划。

Git 同步代码，不会同步用户手机里的日记、照片或未来社区数据。不要把源码文件夹放进会同时覆盖文件的双向网盘目录后让两台电脑同时修改。

官方参考：
- Flutter SDK 历史版本：https://docs.flutter.dev/install/archive
- GitHub 仓库说明：https://docs.github.com/en/repositories/creating-and-managing-repositories/about-repositories

## 交付内容与排除项

- app/：Dart 源码、测试、运行素材、Android 工程、锁定依赖及 Gradle Wrapper。
- work/：设计规范、参考图、锁定素材、历史方案、脚本和验收图。历史脚本可能包含旧机路径/额外依赖，仅供参考，不影响 Flutter 主工程编译。
- outputs/：历史交互动效 MP4，不是当前 App 功能验收录像。
- release/：最新 0.9.1 调试 APK，不含所有过期 APK。
- MANIFEST.json：包内文件相对路径、大小与 SHA-256；VERIFY.ps1：解压完整性检查。
- 排除浏览器用户资料、Cookie、ADB 身份密钥、SDK/JDK/Gradle 下载缓存、构建产物目录、IDE 缓存、旧 APK 和旧 APK 解包碎片。
- 包中保留用户设计参考照片和文字，只用于本人迁移和可信协作，不应公开上传整个归档。

Windows 可在根目录运行 `powershell -ExecutionPolicy Bypass -File .\VERIFY.ps1` 检查交付文件；开发后文件变动导致校验失败属于预期。
