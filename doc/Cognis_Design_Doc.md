# Cognis 详细设计文档

## 1. 核心设计理念：双轨会话 (Dual-Track Session)
Cognis 的核心竞争力在于通过单一连接实现用户与 AI 的并行协作。

### 1.1 SSH 多信道架构 (Multiplexing)
- **交互信道 (Interactive Channel)**: 分配一个 PTY，负责标准 I/O，对接 SwiftTerm UI。
- **静默信道 (Silent Channel)**: 开启一个 `direct-tcpip` 或 `exec` 信道。此信道对用户不可见，专门供 AI 代理执行诊断指令（如 `top`, `df`, `dmesg`）。

### 1.2 串口流镜像 (Serial Mirroring)
- 串口数据通过 `DataHub` 分发：一路发送至 UI 渲染，另一路发送至 AI 上下文缓冲区进行正则匹配（如匹配 Kernel Panic 或 Error 关键字）。

## 2. 软件架构 (Software Architecture)
- **Session 层 (Protocol-Oriented)**: 
    - 定义 `TerminalSession` 协议。
    - 实现 `SSHSession` 与 `SerialSession` 类。
- **AI 层 (MCP Bridge)**:
    - 负责将 LLM 的 Tool Call 意图转化为特定设备的 Shell 命令。
- **UI 层 (Three-Pane Layout)**:
    - **Sidebar**: 分组会话管理。
    - **Main Canvas**: 多标签终端，支持分屏。
    - **AI Inspector**: 右侧浮动或固定面板，展示 AI 分析结果。

## 3. 安全设计
- **沙盒机制**: 严格遵循 macOS App Sandbox 规范。
- **凭据隔离**: 物理连接层与逻辑 UI 层分离，AI 仅能通过授权的 Silent Channel 操作，无法直接模拟键盘输入敏感信息。

## 4. 详细组件设计

### 4.1 SessionManager 组件
- **职责**: 统一管理所有终端会话的生命周期
- **核心功能**:
  - 会话创建、销毁和状态管理
  - 连接池管理，支持并发多个SSH/串口连接
  - 会话状态持久化到 SwiftData
- **接口设计**:
  - `createSession(type: SessionType, configuration: SessionConfig) -> TerminalSession`
  - `getActiveSessions() -> [TerminalSession]`
  - `closeSession(sessionId: UUID)`

### 4.2 TerminalRenderer 组件
- **职责**: 负责终端内容的渲染和用户交互
- **核心功能**:
  - SwiftTerm 集成和配置管理
  - 终端主题和样式管理
  - 键盘输入处理和快捷键映射
  - 分屏和标签页渲染
- **接口设计**:
  - `renderTerminal(buffer: TerminalBuffer, theme: TerminalTheme)`
  - `handleKeyEvent(event: KeyEvent) -> Bool`
  - `resizeTerminal(width: Int, height: Int)`

### 4.3 AICoordinator 组件
- **职责**: 协调 AI 与终端的交互
- **核心功能**:
  - MCP 协议客户端实现
  - 上下文缓冲区管理和向量化处理
  - AI 建议生成和优先级排序
  - 一键执行权限验证和结果反馈
- **接口设计**:
  - `analyzeContext(context: SessionContext) -> [AIRecommendation]`
  - `executeRecommendation(recommendation: AIRecommendation) -> ExecutionResult`
  - `updateContextBuffer(sessionId: UUID, content: String)`

## 5. 错误处理设计

### 5.1 错误分类
- **连接错误**: SSH认证失败、串口连接超时、网络不可达
- **协议错误**: MCP协议解析错误、终端协议不兼容
- **运行时错误**: 内存不足、文件系统权限不足、沙盒限制
- **AI错误**: 模型响应超时、上下文过长、工具调用失败

### 5.2 错误恢复策略
- **自动重试**: 对于暂时性网络错误，实现指数退避重试机制
- **优雅降级**: AI功能不可用时，降级为纯终端工具
- **状态恢复**: 应用崩溃后能够恢复之前的会话状态
- **用户引导**: 提供清晰的错误信息和解决建议

### 5.3 用户错误提示
- **实时通知**: 在状态栏显示非阻塞的错误提示
- **详细日志**: 提供技术细节供高级用户排查
- **操作指引**: 针对常见错误提供一键修复建议
- **反馈渠道**: 集成错误报告功能

## 6. 性能设计

### 6.1 内存管理
- **会话隔离**: 每个会话在独立的内存空间中运行
- **缓冲区限制**: 终端输出缓冲区和AI上下文缓冲区有大小限制
- **资源回收**: 不活跃会话的资源自动释放
- **内存监控**: 实时监控应用内存使用，预警内存泄漏

### 6.2 CPU优化
- **异步处理**: 所有I/O操作使用Swift并发模型
- **渲染优化**: 终端渲染使用增量更新，避免全量重绘
- **AI推理**: AI推理在后台线程执行，不影响UI响应
- **懒加载**: 非活动标签页的组件延迟初始化

### 6.3 网络优化
- **连接复用**: SSH连接支持多路复用，减少连接建立开销
- **数据压缩**: 大文件传输支持压缩
- **带宽适应**: 根据网络质量自适应调整传输策略
- **离线缓存**: 常用命令结果缓存，减少重复查询
