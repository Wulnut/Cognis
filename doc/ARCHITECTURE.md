# Cognis 详细架构设计

## 1. 系统架构概览

### 1.1 整体架构图
```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer (SwiftUI)                    │
├──────────────┬──────────────────────┬────────────────────────┤
│   Sidebar    │    Main Canvas       │   AI Inspector        │
│  (Sessions)  │   (Terminal Tabs)    │  (Recommendations)    │
└──────┬───────┴───────┬──────────────┴─────────┬──────────────┘
       │               │                        │
       ▼               ▼                        ▼
┌──────────────────────────────────────────────────────────────┐
│                    Session Layer (Protocol)                   │
├───────────────────┬──────────────────┬───────────────────────┤
│  SessionManager   │  TerminalSession │   DataHub             │
│                   │  (SSH/Serial)    │   (Multiplexer)       │
└─────────┬─────────┴────────┬─────────┴──────────┬────────────┘
          │                  │                    │
          ▼                  ▼                    ▼
┌──────────────────────────────────────────────────────────────┐
│                      AI Layer (MCP Bridge)                    │
├──────────────────┬────────────────────┬──────────────────────┤
│  AICoordinator   │  ContextBuffer     │  MCPClient           │
│                  │  (Vectorization)   │  (Tool Calls)        │
└──────────┬───────┴─────────┬──────────┴─────────┬────────────┘
           │                 │                    │
           ▼                 ▼                    ▼
┌──────────────────────────────────────────────────────────────┐
│                Infrastructure Layer                           │
├──────────────┬───────────────────┬───────────────────────────┤
│  libssh2     │  ORSSerialPort    │  SwiftData/Keychain      │
│  (SSH)       │  (Serial)         │  (Storage)               │
└──────────────┴───────────────────┴───────────────────────────┘
```

### 1.2 技术选型理由

#### Swift 5.10+ 和 SwiftUI
- **原生性能**: 充分利用macOS平台优化
- **并发模型**: Swift并发模型（async/await）简化异步编程
- **类型安全**: 强类型系统减少运行时错误
- **声明式UI**: SwiftUI提供现代化、响应式UI开发体验

#### 面向协议编程 (POP)
- **解耦合**: Session层通过协议抽象，SSH和串口实现可独立开发
- **可测试性**: 协议便于Mock，提高单元测试覆盖率
- **扩展性**: 未来支持新协议（如Telnet）只需实现TerminalSession协议

#### MCP协议
- **标准化**: 使用开放标准，避免供应商锁定
- **灵活性**: 支持多种AI模型后端
- **工具生态**: 可复用现有MCP工具和服务

## 2. 组件详细设计

### 2.1 Session层

#### 2.1.1 TerminalSession协议
```swift
protocol TerminalSession: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var state: SessionState { get }
    var configuration: SessionConfiguration { get }

    // 生命周期管理
    func connect() async throws
    func disconnect() async
    func reconnect() async throws

    // 数据传输
    func send(_ data: Data) async throws
    func receive() -> AsyncStream<Data>

    // 会话控制
    func resize(width: Int, height: Int) async throws
    func getEnvironment() async -> [String: String]
}

enum SessionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(Error)
}
```

#### 2.1.2 SSHSession类设计
```swift
@Observable
final class SSHSession: TerminalSession {
    // 属性
    let id: UUID
    var name: String
    private(set) var state: SessionState
    let configuration: SSHConfiguration

    // SSH特定属性
    private var sshConnection: SSH2Connection
    private var interactiveChannel: SSH2Channel  // PTY信道
    private var silentChannel: SSH2Channel?      // AI静默信道

    // 双信道管理
    func createSilentChannel() async throws -> SSH2Channel
    func closeSilentChannel() async

    // 状态机
    private func transitionState(to newState: SessionState)
}

struct SSHConfiguration: Codable {
    let host: String
    let port: Int
    let username: String
    let authMethod: AuthenticationMethod
    let keepAliveInterval: TimeInterval
    let timeout: TimeInterval
}

enum AuthenticationMethod {
    case password(String)
    case publicKey(privateKeyPath: String, passphrase: String?)
    case agent
}
```

#### 2.1.3 SerialSession类设计
```swift
@Observable
final class SerialSession: TerminalSession {
    // 属性
    let id: UUID
    var name: String
    private(set) var state: SessionState
    let configuration: SerialConfiguration

    // 串口特定属性
    private var serialPort: ORSSerialPort
    private var readBuffer: AsyncStream<Data>.Continuation

    // 串口控制
    func setBaudRate(_ baudRate: Int) async throws
    func setDataBits(_ dataBits: Int) async throws
    func setStopBits(_ stopBits: Int) async throws
    func setParity(_ parity: ParityType) async throws
}

struct SerialConfiguration: Codable {
    let portPath: String
    let baudRate: Int
    let dataBits: Int
    let stopBits: Int
    let parity: ParityType
    let flowControl: FlowControlType
}
```

#### 2.1.4 SessionManager组件
```swift
@Observable
final class SessionManager {
    // 单例
    static let shared = SessionManager()

    // 会话池
    private(set) var sessions: [UUID: TerminalSession] = [:]
    private(set) var activeSessionId: UUID?

    // 持久化
    private let storage: SessionStorage

    // 会话管理
    func createSession(
        type: SessionType,
        configuration: SessionConfiguration
    ) async throws -> TerminalSession

    func getSession(id: UUID) -> TerminalSession?
    func closeSession(id: UUID) async
    func setActiveSession(id: UUID)

    // 批量操作
    func closeAllSessions() async
    func getActiveSessions() -> [TerminalSession]
    func getSessions(matching predicate: (TerminalSession) -> Bool) -> [TerminalSession]
}

enum SessionType {
    case ssh
    case serial
}
```

#### 2.1.5 DataHub（数据分发器）
```swift
actor DataHub {
    // 订阅者管理
    private var subscribers: [UUID: AsyncStream<Data>.Continuation] = [:]

    // 数据分发
    func distribute(_ data: Data, from sessionId: UUID) async

    // 订阅管理
    func subscribe(sessionId: UUID) -> AsyncStream<Data>
    func unsubscribe(sessionId: UUID)

    // 过滤和路由
    func addFilter(sessionId: UUID, filter: DataFilter)
    func removeFilter(sessionId: UUID)
}

protocol DataFilter {
    func shouldForward(_ data: Data) -> Bool
    func transform(_ data: Data) -> Data
}
```

### 2.2 AI层

#### 2.2.1 AICoordinator组件
```swift
@Observable
final class AICoordinator {
    // 依赖
    private let mcpClient: MCPClient
    private let contextBuffer: ContextBuffer

    // 状态
    private(set) var isAnalyzing: Bool = false
    private(set) var recommendations: [AIRecommendation] = []

    // 核心功能
    func analyzeContext(sessionId: UUID) async throws -> [AIRecommendation]
    func executeRecommendation(_ recommendation: AIRecommendation) async throws -> ExecutionResult
    func updateContextBuffer(sessionId: UUID, content: String) async

    // 实时感知
    func enableAutoAnalysis(for sessionId: UUID, patterns: [ErrorPattern])
    func disableAutoAnalysis(for sessionId: UUID)
}

struct AIRecommendation: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let command: String
    let priority: RecommendationPriority
    let rationale: String
    let estimatedImpact: ImpactLevel
}

enum RecommendationPriority {
    case critical   // 系统错误，需要立即处理
    case high       // 严重问题，影响功能
    case medium     // 性能优化、建议改进
    case low        // 可选操作
}

enum ImpactLevel {
    case none       // 只读操作
    case low        // 修改配置
    case medium     // 重启服务
    case high       // 数据修改
    case critical   // 系统级操作
}
```

#### 2.2.2 ContextBuffer（上下文缓冲区）
```swift
actor ContextBuffer {
    // 缓冲区配置
    private let maxSize: Int = 10_000  // 最大行数
    private let maxAge: TimeInterval = 3600  // 1小时过期

    // 缓冲数据
    private var buffer: CircularBuffer<ContextEntry> = CircularBuffer(capacity: 10_000)
    private var sessionBuffers: [UUID: CircularBuffer<ContextEntry>] = [:]

    // 写入
    func append(sessionId: UUID, content: String, metadata: ContextMetadata) async

    // 读取
    func getContext(sessionId: UUID, lines: Int) async -> [ContextEntry]
    func getRecentErrors(sessionId: UUID, count: Int) async -> [ContextEntry]

    // 分析
    func extractPatterns(sessionId: UUID) async -> [DetectedPattern]
    func summarize(sessionId: UUID) async -> ContextSummary

    // 清理
    func cleanup(sessionId: UUID) async
    func clearOldEntries() async
}

struct ContextEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: UUID
    let content: String
    let metadata: ContextMetadata
}

struct ContextMetadata {
    let isError: Bool
    let severity: LogSeverity
    let tags: [String]
}

struct DetectedPattern {
    let type: PatternType
    let occurrences: Int
    let firstSeen: Date
    let lastSeen: Date
    let examples: [String]
}

enum PatternType {
    case error(code: String)
    case warning
    case kernelPanic
    case connectionLoss
    case permissionDenied
    case custom(pattern: String)
}
```

#### 2.2.3 MCPClient（MCP协议客户端）
```swift
final class MCPClient {
    // 连接配置
    private let serverURL: URL
    private let timeout: TimeInterval

    // 连接状态
    private var isConnected: Bool = false
    private var connection: MCPConnection?

    // 生命周期
    func connect() async throws
    func disconnect() async
    func reconnect() async throws

    // Tool调用
    func executeTool(
        name: String,
        arguments: [String: Any],
        sessionId: UUID
    ) async throws -> ToolResult

    func listAvailableTools() async throws -> [ToolDefinition]

    // 上下文管理
    func sendContext(_ context: MCPContext) async throws
    func clearContext() async throws
}

struct MCPContext {
    let sessionId: UUID
    let recentOutput: String
    let environment: [String: String]
    let currentDirectory: String
    let shellType: String
}

struct ToolResult {
    let success: Bool
    let output: String
    let error: String?
    let exitCode: Int?
}

struct ToolDefinition {
    let name: String
    let description: String
    let parameters: [ToolParameter]
}
```

### 2.3 UI层

#### 2.3.1 主视图结构
```swift
struct ContentView: View {
    @State private var sessionManager = SessionManager.shared
    @State private var aiCoordinator = AICoordinator()
    @State private var selectedSessionId: UUID?
    @State private var isAIInspectorVisible: Bool = true

    var body: some View {
        NavigationSplitView(
            sidebar: { SessionSidebarView(sessionManager: sessionManager) },
            content: { TerminalCanvasView(sessionId: selectedSessionId) },
            detail: {
                if isAIInspectorVisible {
                    AIInspectorView(coordinator: aiCoordinator)
                }
            }
        )
    }
}
```

#### 2.3.2 终端渲染组件
```swift
struct TerminalView: NSViewRepresentable {
    let session: TerminalSession
    @Binding var theme: TerminalTheme

    func makeNSView(context: Context) -> TerminalNSView {
        let terminalView = TerminalNSView()
        terminalView.configureTerminal(theme: theme)
        return terminalView
    }

    func updateNSView(_ nsView: TerminalNSView, context: Context) {
        nsView.updateTheme(theme)
    }
}

final class TerminalNSView: NSView {
    private let terminalView: TerminalView  // SwiftTerm

    func configureTerminal(theme: TerminalTheme)
    func updateTheme(_ theme: TerminalTheme)
    func handleKeyEvent(_ event: NSEvent) -> Bool
    func resizeTerminal(to size: CGSize)
}
```

## 3. 数据流设计

### 3.1 用户输入处理流程
```
User Input (Keyboard)
    ↓
TerminalView (NSView)
    ↓
TerminalSession.send(data)
    ↓
SSHSession.interactiveChannel.write(data)
    ↓
libssh2 → SSH Server
```

### 3.2 AI响应处理流程
```
Terminal Output
    ↓
DataHub.distribute(data)
    ├─→ TerminalView (UI渲染)
    └─→ ContextBuffer.append(content)
            ↓
        AICoordinator.analyzeContext()
            ↓
        MCPClient.executeTool()
            ↓
        SSHSession.silentChannel.write(command)
            ↓
        ToolResult → AIRecommendation
            ↓
        AI Inspector (显示建议)
```

### 3.3 串口数据镜像流程
```
Serial Port Data
    ↓
SerialSession.receive()
    ↓
DataHub.distribute(data, from: sessionId)
    ├─→ TerminalView (UI渲染)
    └─→ ContextBuffer.append(content)
            ↓
        Pattern Matching (Kernel Panic, Error)
            ↓
        AICoordinator.autoAnalysis()
```

### 3.4 错误处理流程
```
Error Occurrence (Connection失败、协议错误等)
    ↓
Session.transitionState(to: .error(error))
    ↓
SessionManager观察状态变化
    ↓
UI更新（显示错误状态）
    ├─→ 用户通知（Toast/Alert）
    └─→ 错误日志记录
            ↓
        自动恢复策略评估
            ↓
        重试或降级处理
```

## 4. API接口规范

### 4.1 内部组件接口

#### SessionManager接口
```swift
// 会话创建
func createSession(type: SessionType, configuration: SessionConfiguration) async throws -> TerminalSession

// 会话管理
func getSession(id: UUID) -> TerminalSession?
func closeSession(id: UUID) async
func setActiveSession(id: UUID)

// 批量操作
func closeAllSessions() async
func getActiveSessions() -> [TerminalSession]
```

#### AICoordinator接口
```swift
// 分析
func analyzeContext(sessionId: UUID) async throws -> [AIRecommendation]

// 执行
func executeRecommendation(_ recommendation: AIRecommendation) async throws -> ExecutionResult

// 上下文更新
func updateContextBuffer(sessionId: UUID, content: String) async
```

### 4.2 外部集成接口

#### MCP协议接口
```swift
// 连接管理
func connect() async throws
func disconnect() async

// Tool调用
func executeTool(name: String, arguments: [String: Any], sessionId: UUID) async throws -> ToolResult

// 上下文
func sendContext(_ context: MCPContext) async throws
```

### 4.3 协议定义

#### TerminalSession协议
- 所有终端会话类型必须实现的基础协议
- 定义生命周期管理、数据传输、会话控制接口
- 支持协议扩展添加默认实现

#### DataFilter协议
- 数据过滤和转换接口
- 用于DataHub的数据路由和处理

## 5. 状态管理

### 5.1 会话状态机
```
disconnected → connecting → connected → reconnecting → connected
     ↓              ↓            ↓            ↓
   error ←────────┴─────────────┴────────────┘
```

### 5.2 SwiftUI状态管理
- 使用`@Observable`宏实现响应式状态
- SessionManager和AICoordinator作为共享状态
- 通过Environment传递依赖

## 6. 并发模型

### 6.1 Swift并发
- 所有I/O操作使用`async/await`
- Actor隔离保护共享状态（ContextBuffer、DataHub）
- MainActor保证UI操作在主线程

### 6.2 线程策略
- UI渲染：主线程
- 网络I/O：系统调度的后台线程
- AI推理：后台线程
- 数据处理：Actor隔离的并发队列

## 7. 安全设计

### 7.1 沙盒配置
- 网络客户端权限（SSH连接）
- 串口设备访问权限
- 文件系统读写权限（仅用户目录）
- Keychain访问权限

### 7.2 数据隔离
- SSH密钥存储在macOS Keychain
- 会话凭据不存储在内存中超过必要时间
- AI静默信道与交互信道物理隔离

## 8. 扩展性设计

### 8.1 插件系统（未来）
- 协议扩展支持新的会话类型
- Tool定义允许自定义AI工具
- UI组件模块化支持自定义主题

### 8.2 多平台支持（未来）
- Session层和AI层平台无关
- UI层使用SwiftUI支持iOS/iPadOS移植
- 使用条件编译隔离平台特定代码
