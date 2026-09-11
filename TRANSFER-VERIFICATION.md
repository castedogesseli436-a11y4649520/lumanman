# 迁移副本验证（2026-09-10）

- 在迁移副本的独立 app 路径运行 flutter pub get：成功。
- flutter analyze --no-pub：No issues found。
- flutter test --no-pub：22 项全部通过。
- flutter build apk --debug --no-pub：成功，Gradle 输出耗时 67.5 秒。
- 主工程 Gradle 下载地址为 services.gradle.org 的 9.3.1-all ZIP；官方 SHA-256 与项目原校验值一致：17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43。
- 原工程与迁移副本的 app/lib、app/test、app/assets 文件逐一 SHA-256 相同；pubspec.lock 相同。
- IMPLEMENTATION-LOCK.md 表格中的 13 个 approved 资源哈希全部一致。
- 附带 APK 为原交付 0.9.1+10 文件，SHA-256：C6459EA9924D5ECC1897FCD3911E405663144188063385C3193119FBA967820F。
- APK 经 apksigner 验证，证书与单独备份的 debug.keystore 一致。
- 检查源码包中的常见私钥/访问令牌格式，未发现嵌入图像之外的匹配；这是有限模式检查，不等于完整安全审计。密钥文件独立打包。

限制：测试在原 Windows 主机的全新工程目录进行，复用了已安装的 Flutter、JDK、Android SDK 和全局依赖缓存，未在实际第二台电脑测试，也不证明无网络环境可以构建。包内不含生成的 local.properties/build/.gradle 等，新机需按 START-HERE.md 重新生成。语音识别、相册权限、真实数据迁移与手机覆盖安装仍须目标设备验收；iOS 尚未构建。

保留的构建警告：speech_to_text 使用 Kotlin Gradle Plugin 的未来兼容警告、SDK XML 解析版本提示。未因这些提示变更依赖。

压缩时会生成 MANIFEST.json，并逐一读取 ZIP 内文件计算 SHA-256 与源清单比较；解压后可运行 VERIFY.ps1 再校验。MANIFEST.json 本身不自包含哈希，外层 ZIP 哈希保存在同级 SHA256SUMS.txt。
