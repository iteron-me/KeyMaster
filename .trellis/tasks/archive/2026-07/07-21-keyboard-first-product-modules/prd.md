# 屏幕元素键盘导航模块规划

## Goal

为 KeyMaster 规划一个可独立添加的内置工具模块：用户通过一个全局快捷键进入“屏幕元素键盘导航模式”，屏幕上给当前可操作 UI 元素显示字母提示，用户输入提示码即可聚焦或触发对应元素，从而减少鼠标点击。

## Background

- KeyMaster 当前通过 `KeyMaster/Tools/ToolRegistry.swift` 注册内置工具，现有工具包括区域截图和番茄钟。
- 快捷键动作已经支持 `KeyAction.runTool(ToolInvocation)`，工具可以通过现有规则系统绑定到任意修饰键组合。
- `KeyMaster/Tools/Screenshot/ScreenshotOverlayController.swift` 已有跨屏无边框 overlay 窗口的实现先例，适合复用同类窗口控制思路。
- `KeyMaster/Services/PermissionService.swift` 已检查 Accessibility 和 Input Monitoring。屏幕元素导航至少需要 Accessibility 权限，若使用现有全局快捷键触发则仍依赖 Input Monitoring。
- 本任务已从模块规划进入 MVP 实现；仍不重构项目、不改变 KeyMaster 定位。

## Requirements

- 新增一个内置工具，建议工具 ID 为 `screen.navigation`，名称为 `Screen Navigation`。
- 用户通过已绑定的 KeyMaster 快捷键触发该工具。
- 触发后进入导航模式，优先扫描当前前台应用的当前窗口或可见窗口。
- 只为可交互元素生成提示：按钮、链接、输入框、菜单项、复选框、单选项、弹窗按钮、列表中可按压或可选择项。
- 在所有相关屏幕上显示透明 overlay，元素旁显示短字母 hint，例如 `A`、`S`、`DF`。
- 用户输入 hint 后执行对应动作：
  - 支持 `AXPress` 的元素执行 press。
  - 支持聚焦的文本输入元素执行 focus。
  - 其他有有效 frame 的元素可退化为点击元素中心点。
- `Esc` 退出导航模式。
- 导航模式下按 `↑` / `↓` 可以滚动当前窗口，滚动后仍保持导航模式。
- 输入过程中只匹配当前 hint 前缀，匹配唯一元素后立即执行并退出。
- 第一版只做 Accessibility 方案，不做 OCR、浏览器 DOM 注入、AI 识别或复杂语义搜索。
- 失败时不执行危险兜底动作；没有扫描到元素时显示短暂状态并退出或允许 `Esc` 退出。

## Non-Goals

- 不替代鼠标拖拽、绘图、游戏、Canvas 内部控件操作。
- 不保证所有第三方 App 都可完整识别；自绘 UI、Electron、Canvas、受保护窗口可能暴露不完整。
- 不读取或上传窗口内容；第一版只读取 Accessibility 暴露的角色、标题、frame 和动作。
- 不在第一版支持 OCR 文本点击、图片区域点击、浏览器标签页 DOM 级导航。
- 不改变现有规则模型和动作持久化格式，除非实现时新增工具文件需要被 XcodeGen 纳入工程。

## Acceptance Criteria

- [x] 用户可以把 `Screen Navigation` 作为内置工具绑定到一个快捷键。
- [x] 按下快捷键后，当前前台窗口内的可交互元素出现可读的键盘 hint。
- [x] 输入完整 hint 能触发按钮/链接类元素，或聚焦输入框类元素。
- [x] `Esc` 可以随时取消并关闭所有 overlay。
- [ ] 多显示器环境下 overlay 位置与元素 frame 对齐。
- [x] 无 Accessibility 权限时给出明确提示，不悄悄失败。
- [x] 对扫描不到元素、元素执行失败等情况有可预期退出行为。

## Verification

- `xcodebuild test` passed with 14 tests.
- `./scripts/dev-run.sh` passed and launched `/Applications/KeyMaster.app`.
- Fixed a foreground-app detection bug where the shortcut could report "No active app" if `NSWorkspace.frontmostApplication` resolved to KeyMaster during global shortcut handling. The scanner now falls back to the topmost visible window owner PID.
- Fixed an overlay Y-axis conversion bug where AX elements near the top of a window, such as close/minimize buttons, could render their hints near the bottom of the screen.
- Removed broad `AXRow`/`AXCell` targets from the MVP candidate set because apps can expose invisible or large container-like cells that look like unexplained hints. Hint badges are now smaller, semi-transparent, and offset from the element top-left instead of centered over controls.
- Added a window-relative oversized text-area filter so terminal/editor content regions exposed as large `AXTextArea` targets do not receive confusing standalone hints in the middle of the window.
- Adjusted hint placement back near the target control after user testing showed outside placement was too far away. Expanded the hint alphabet to 26 letters and accepts additional small/medium AX elements that expose `AXPress`, improving target coverage without re-enabling oversized terminal/editor content regions.
- Fixed the command action secondary panel layout after adding built-in tools: the submenu is top-aligned, the built-in tool list shows from the top, and scroll areas use a top anchor so the first tool remains visible.
- Documented `Screen Navigation` in both README files and added `↑` / `↓` scrolling while the navigation overlay stays active.
- Reworked the navigation input path after user testing showed that key overlay windows could leave KeyMaster as the keyboard target and make `↑` / `↓` ineffective in Chrome-like apps. Screen Navigation now keeps overlay windows visual-only and uses a short-lived CGEvent tap to consume hint keys while letting arrow keys pass through to the original foreground app.
- Multi-display coordinate behavior still needs manual verification on an actual multi-display setup.

## Open Decision

- Hint 字母表建议第一版使用主键盘左手区优先的字母序列：`A S D F J K L Q W E R U I O`。这样减少手指移动，但会牺牲一点标签直觉。如果用户更偏好 Vimium 风格，可以改为 `A S D F G H J K L` 起步。
