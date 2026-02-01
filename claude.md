# Cognis Project Guide

## 🚀 项目愿景
Cognis 是一款 macOS 原生智能终端管理器。
- **核心逻辑**: MobaXterm 的强悍功能 (SSH/Serial/SFTP) + Termius 的现代视觉 (SwiftUI)。
- **AI 特性**: 基于 MCP 协议的原生集成，利用 SSH 多信道实现“双轨会话”（Interactive + Silent）。
- **称呼**: 请叫我Coder

## 💻 常用指令 (Build & Dev)
- **编译项目**: `swift build`
- **运行应用**: `swift run`
- **运行测试**: `swift test`
- **清理工程**: `swift package clean`
- **更新依赖**: `swift package update`

## 🏗️ 核心架构原则 (必读)
1. **双轨会话 (Dual-Track)**: 
   - 所有的 `TerminalSession` 必须同时支持 `InteractiveChannel` (PTY) 和 `SilentChannel` (Exec/Direct)。
   - AI 诊断逻辑必须运行在 `SilentChannel`，严禁干扰用户的 PTY 输入输出。
2. **面向协议编程 (POP)**:
   - 优先定义协议 (Protocol)，再实现具体的连接器（如 `SSHSession`, `SerialSession`）。
3. **异步模型**:
   - 必须使用 Swift `async/await` 处理所有网络和串口 I/O，严禁阻塞主线程。

## 🎨 代码风格规范
- **命名**: 类名和协议名使用 `UpperCamelCase`，变量和函数名使用 `lowerCamelCase`。
- **UI**: 必须使用原生 SwiftUI 组件，尽量利用 macOS 15 的系统材质 (`.thinMaterial`)。
- **错误处理**: 统一使用 `Result` 类型或 `throws` 抛出具体定义的 `CognisError` 枚举。
- **注释**: 复杂的并发逻辑或 libssh2 的底层调用必须附带详细的 SwiftDoc 注释。
- **语言规范**: 代码中的返回值、错误消息、日志输出必须使用**英文**；注释可以使用中文。

## 📦 依赖管理
- **SwiftTerm**: 终端仿真渲染。
- **libssh2**: SSH 底层协议处理。
- **ORSSerialPort**: 串口通信。
- **SwiftData**: 本地持久化。

## 🤖 AI & MCP 协作
- 当执行涉及设备分析的任务时，调用 `MCPBridge` 通过静默信道获取数据，而非抓取终端窗口文本。

## 🎨 Visual Constraints & Figma Mapping
1. **Design System First**: 
   - 严禁在 View 中硬编码颜色、间距或字体大小。
   - 所有视觉参数必须引用 `Theme.swift` 中的静态定义。
2. **Figma Translation Rules**:
   - **Colors**: 当从 Figma 获取 Hex 值时，应将其更新至 `Theme.Colors` 并支持 Light/Dark Mode 适配。
   - **Spacing**: 遵循 4pt 进位原则（4, 8, 12, 16, 24, 32）。
   - **Corner Radius**: 标准容器使用 `Theme.Radius.main` (12pt)，小组件使用 `Theme.Radius.small` (6pt)。
3. **macOS Native Aesthetics**:
   - 窗口必须支持 `VisualEffectView`。优先使用 `.thinMaterial` 或 `.ultraThinMaterial` 实现透明感。
   - 侧边栏必须符合 macOS 15 的 `NavigationSplitView` 标准交互，选中态使用 `AccentColor`。
4. **Icons**:
   - 优先使用 **SF Symbols 5.0+**。只有在 SF Symbols 无法满足时，才考虑从 Figma 导出 PDF/SVG 矢量资源。
5. **Layout Engine**:
   - 必须使用 SwiftUI 的 `LazyVStack` 或 `List` 处理大数据量（如终端回显和 SFTP 列表），以保证滚动性能。