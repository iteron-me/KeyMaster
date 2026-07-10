# 发布 KeyMaster

KeyMaster 当前通过 tag 触发的 GitHub Actions 发布 ad-hoc 签名、未经 Apple
公证的 DMG。工作流只创建草稿 Release，维护者可以先测试真实下载产物，再决定是否
公开。

## 准备版本

从干净且已经与远端同步的 `main` 分支开始，版本号使用三段数字：

```sh
./scripts/release.sh 0.2.0
```

该命令会检查仓库状态、修改 `project.yml` 的 `MARKETING_VERSION`、重新生成
Xcode 工程、运行单元测试、创建 `chore(release): 0.2.0` 提交，并创建带说明的
`v0.2.0` tag。默认不会修改远端仓库。

检查提交和 tag 后，使用原子推送发布：

```sh
./scripts/release.sh 0.2.0 --push
```

如果直接从最初的干净状态执行带 `--push` 的命令，脚本会在同一个受保护流程中完成
准备和推送。

## GitHub Actions

推送 tag 后会启动 `.github/workflows/release.yml`：

1. 检出准确的 tag，并验证 tag 与 App 版本一致。
2. 在没有 Apple 证书的情况下构建通用架构 Release Archive。
3. 应用 ad-hoc 签名并验证 App。
4. 创建并挂载检查包含 KeyMaster 和 Applications 链接的压缩 DMG。
5. 生成 SHA-256 校验文件。
6. 创建 GitHub 草稿 Release，并上传两个文件。

如果只是临时 CI 故障，可以重新运行工作流，或通过手动触发选择已有 tag。如果源码
或打包脚本需要修改，通常应发布新的补丁版本，而不是移动已有 tag。

## 测试并公开

从草稿 Release 下载 DMG 和校验文件，不要只测试本地产物。验证校验值并安装后，
检查真实的浏览器隔离流程：

- Control 点击 App 后选择“打开”可以运行，或“隐私与安全性”出现“仍要打开”。
- 可以授予辅助功能和输入监控权限。
- 权限开启后全局快捷键可以工作。
- 使用截图工具时可以授予屏幕录制权限。
- 有测试设备时，分别验证 Apple 芯片和 Intel Mac。

全部通过后再公开草稿 Release。

## 本地打包

CI 与本地使用同一个打包命令：

```sh
./scripts/package-release.sh --expected-version 0.2.0 --build-number 2
```

产物会写入 `dist/`。排查问题时可以增加 `--keep-work-dir` 保留 Archive 和暂存文件。

## 取消本地准备

如果还没有推送，可以重新执行带 `--push` 的命令继续发布。若要取消，先确认 GitHub
上不存在该 tag，然后删除本地 tag，并在保留文件修改的情况下撤销 release commit：

```sh
git tag -d v0.2.0
git reset --soft HEAD^
```

Release 已公开后不要重写 tag。

## 未来正式签名

以后加入 Apple Developer Program 时，只需要把 `scripts/package-release.sh` 中的
ad-hoc 签名阶段替换为 Developer ID 签名、公证和 Staple。版本、tag、DMG、校验、
草稿测试和 GitHub 上传流程可以继续使用。
