# KeyMaster / 键盘侠

[English](README.md) | 中文

KeyMaster 是一个原生 macOS 菜单栏应用，用来可视化配置全局键盘快捷键。你可以在键盘布局上点击一个键，选择要执行的动作，然后在任何地方用修饰键组合触发它。

它适合喜欢 Hammerspoon、启动器和 shell 脚本能力，但不想长期维护手写配置的 macOS 用户。

## 截图

公开发布前可以把截图放到下面这些位置：

| 键盘面板 | 动作菜单 | 权限状态 |
| --- | --- | --- |
| `docs/screenshots/keyboard-panel.png` | `docs/screenshots/action-menu.png` | `docs/screenshots/permissions.png` |

## 它能做什么

- 用可视化 ANSI 键盘布局配置快捷键。
- 绑定 `Control + K`、`Command + Shift + P` 这类修饰键组合。
- 打开本机 Applications 目录里发现的 macOS 应用。
- 打开命名 URL。
- 通过 `/bin/zsh -lc` 运行显式配置的 shell 命令。
- 发送另一个按键，用作简单按键映射。
- 触发内置工具，例如区域截图和番茄钟。
- 将全部快捷键规则和动作历史导出为可迁移的配置文件。
- 将规则以 JSON 形式保存在用户本机 Application Support 目录。

## 如何使用

1. 从菜单栏打开 KeyMaster。
2. 按提示授予需要的 macOS 权限。
3. 在可视化键盘上点击一个键。
4. 选择修饰键层和动作类型。
5. 选择应用、URL、命令、按键映射或内置工具。
6. 在 macOS 任意位置按下保存好的快捷键。

如果打开动作菜单时没有按住任何修饰键，KeyMaster 默认编辑 `Control` 层。编辑时按住 `Control`、`Option`、`Shift` 或 `Command`，可以直接切换到对应修饰键层。

## 配置备份

右键点击 KeyMaster 菜单栏图标，可以导入或导出配置。`.config`
文件包含全部快捷键规则，以及 URL 和命令动作历史，可用于在另一台 Mac
恢复相同配置。导出名称使用可排序的
`KM-yyyyMMdd.config` 格式。

JSON 只保留可迁移的行为字段；规则内部 ID、派生显示名称和时间戳会在导入时
重新生成。

导入会先校验整个文件，并在替换当前配置前要求确认。应用快捷键使用 bundle
identifier 保存，即使目标 Mac 尚未安装对应应用，规则也会保留。

## 权限说明

全局键盘拦截依赖 macOS 隐私权限：

- 辅助功能：用于低层级快捷键处理。
- 输入监控：用于监听全局键盘事件。
- 屏幕录制：仅使用截图工具时需要。
- 通知：番茄钟提醒可选需要。

本地开发和权限测试时，请始终使用稳定安装路径启动：

```sh
./scripts/dev-run.sh
```

请把权限授予 `/Applications/KeyMaster.app`，不要授予临时 DerivedData 构建产物。

## 安全说明

Shell 命令能力很强。KeyMaster 会让命令动作保持显式可见，并且只运行你自己绑定过的命令。不要绑定你不了解的命令。

导出的配置文件是可读 JSON，其中可能包含 URL 和 shell 命令，请将它作为敏感
文件妥善保存和分享。

KeyMaster 是 local-first 应用。快捷键规则和动作历史保存在本机：

```text
~/Library/Application Support/KeyMaster/rules.json
~/Library/Application Support/KeyMaster/action-history.json
```

## 环境要求

- macOS 15.0 或更新版本。
- 从源码构建需要 Xcode 26.5 或更新版本。
- 需要 XcodeGen 重新生成 Xcode 工程。
- 真正拦截全局快捷键需要辅助功能和输入监控权限。

通过 Homebrew 安装 XcodeGen：

```sh
brew install xcodegen
```

## 从源码构建

`project.yml` 是 Xcode 工程配置的唯一源头。修改 target、源码分组、构建设置、scheme 或资源后，需要重新生成工程。

```sh
./scripts/generate-xcodeproj.sh
```

命令行构建：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyMasterDerived \
  build
```

日常开发建议使用：

```sh
./scripts/dev-run.sh
```

这个脚本会重新生成工程、构建应用、安装到 `/Applications/KeyMaster.app`、应用稳定的本地签名要求，并打开安装后的应用。

## 文档

- [产品需求](docs/PRODUCT_REQUIREMENTS.md)
- [架构说明](docs/ARCHITECTURE.md)
- [路线图](docs/ROADMAP.md)
- [品牌说明](docs/brand/BRAND.md)
- [历史实现计划](docs/archive/IMPLEMENTATION_PLAN.md)

## 许可证

当前还没有指定许可证。正式公开发布前需要添加 `LICENSE` 文件。
