# KeyMaster / 键盘侠

中文 | [English](README.en.md)

KeyMaster 是一个原生 macOS 菜单栏应用，通过可视化键盘配置全局快捷键。点击一个
按键，选择动作，就能在 Mac 的任何地方触发它。

![KeyMaster 键盘界面](docs/screenshots/keyboard-overview.png)

## 修饰键层

- **直接点击按键：** 默认编辑 `Control` 层。
- **按住修饰键：** 展示对应 `Control`、`Option`、`Shift`、`Command` 层的
  快捷方式，也可以同时按住多个修饰键查看组合层。
- **按住后点击：** 为当前修饰键层添加或编辑动作。

## 动作

每个快捷键可以配置四类动作：

![为按键选择动作](docs/screenshots/action-picker.png)

### App

搜索 Mac 上已经安装的应用，将它绑定到快捷键后即可快速启动。

### Web

保存一个带名称的网站，通过快捷键从任何位置打开。

### Command

运行 Shell 命令。

**KeyMaster 内置工具：**

**区域截图**

框选屏幕区域，添加矩形或文字标注，然后复制结果或将截图贴在桌面上。

<img src="docs/screenshots/screenshot-area.png" alt="KeyMaster 区域截图工具" width="600">

**番茄钟**

自动运行专注与休息周期，支持暂停、跳过、停止和通知，并在菜单栏实时显示剩余
时间。

<img src="docs/screenshots/pomodoro-timer.png" alt="KeyMaster 番茄钟" width="360">

**屏幕导航**

为当前应用窗口中可操作的界面元素显示字母提示，输入提示字母即可点击按钮、打开链接
或聚焦输入框。导航模式下按 `↑` / `↓` 可以滚动当前窗口，按 `Esc` 退出。

**应用命令**

打开类似 Spotlight 的命令面板，搜索当前应用菜单栏及多级菜单中的原文命令。输入关键词
后使用 `↑` / `↓` 选择，按 `Enter` 执行，按 `Esc` 退出；面板同时显示应用菜单原有的
快捷键，全程无需鼠标。

### Key Mapping

将快捷键映射为其他按键或按键组合。例如：

- `Control + I/J/K/L` → 上、左、下、右方向键。
- `Control + Shift + I/J/K/L` → 对应方向的文本选择。

该布局可减少手指在主键区与方向键区之间的移动。

## 配置迁移

右键点击 KeyMaster 菜单栏图标，可以导入或导出全部快捷键和动作历史。

## 环境要求

- macOS 15.0 或更新版本。
- 使用全局快捷键需要辅助功能和输入监控权限。

## 安装发布版本

从 [GitHub Releases](https://github.com/liumengjie1218/KeyMaster/releases)
下载 DMG 和对应的 `.sha256` 文件。可以使用下面的命令验证下载内容：

```sh
shasum -a 256 -c KeyMaster-0.1.1-macos-universal.dmg.sha256
```

打开 DMG，把 KeyMaster 拖到“应用程序”。当前发布版本使用 ad-hoc 签名，未经 Apple
公证。第一次启动时，Control 点击 KeyMaster 并选择“打开”。如果仍被 macOS 阻止，
前往“系统设置 > 隐私与安全性”，点击“仍要打开”。

绕过 Gatekeeper 不会自动授予运行权限。全局快捷键需要辅助功能和输入监控权限；
屏幕导航也需要辅助功能权限来读取和操作界面元素；只有截图工具需要屏幕录制权限。
请只安装从本仓库下载的发布产物。

## 从源码构建

安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，然后运行：

```sh
brew install xcodegen
./scripts/dev-run.sh
```

`dev-run.sh` 会生成 Xcode 工程、构建 KeyMaster，并将开发版本安装到
`/Applications/KeyMaster.app`。

维护者可以参考[发布说明](docs/RELEASING.zh-CN.md)，使用自动 tag 和草稿 Release
流程。

更多信息：[架构说明](docs/ARCHITECTURE.md) · [路线图](docs/ROADMAP.md)
