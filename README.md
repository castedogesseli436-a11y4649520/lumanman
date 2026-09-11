# 路慢慢

Flutter 生活记录 App，当前版本 `0.9.1+10`。支持心情记录、照片、收支、夸夸墙、日历回想和系统语音转文字入口。

## 接手开发

先读 [HANDOFF.md](HANDOFF.md)、[AGENTS.md](AGENTS.md) 和 [设计决策](work/design-spec/UI-DESIGN-DECISIONS.md)。Flutter 工程位于 `app/`。

本机验证环境为 Flutter 3.47.1 / Dart 3.13.1 / JDK 17 / Android SDK 36。安装相应工具后：

```sh
cd app
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

更详细的环境与签名说明见 [START-HERE.md](START-HERE.md)。其中迁移 ZIP、MANIFEST.json、VERIFY.ps1 和安装包是独立归档内容，不随 Git 仓库发布。本仓库保留完整 `work/design-spec/`，包括历史效果图、参考图片、锁定素材与验收资料。

## 当前边界

- 数据保存在用户手机本机；Git 只同步工程文件，不备份手机记录。
- 语音识别已增加异常处理和状态提示，仍待用户真机确认，不能视为已验证恢复。
- 账号、云同步、点赞评论社区和 iOS 工程尚未实现。
- 私有签名密钥单独保存，不进入 Git。换电脑覆盖安装旧 APK 前请核对签名，勿直接卸载旧应用。
- 包含用户设计参考照片和文字，本仓库应保持私有。

迁移副本验证见 [TRANSFER-VERIFICATION.md](TRANSFER-VERIFICATION.md)：22 项测试通过，Android Debug 构建通过；真实第二台电脑及手机识别仍待验证。
