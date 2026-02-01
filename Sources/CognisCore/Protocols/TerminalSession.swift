//
//  TerminalSession.swift
//  CognisCore
//
//  Cognis 终端会话核心协议定义
//  根据 ARCHITECTURE.md 第2.1.1节设计
//
//  设计原则（来自 CLAUDE.md）：
//  1. 面向协议编程 (POP)：优先定义协议，再实现具体连接器
//  2. 双轨会话 (Dual-Track)：支持 Interactive Channel 和 Silent Channel
//  3. 异步模型：使用 Swift async/await 处理所有 I/O
//

import Foundation

// MARK: - TerminalSession 协议

/// 终端会话核心协议
///
/// 所有终端会话类型（SSH、串口等）必须实现此协议。
/// 协议定义了会话的生命周期管理、数据传输和会话控制接口。
///
/// ## 双轨会话设计
/// 根据 Cognis 的核心架构，所有 `TerminalSession` 必须同时支持：
/// - **Interactive Channel (PTY)**: 用户交互信道
/// - **Silent Channel (Exec/Direct)**: AI 诊断信道，不干扰用户 PTY
///
/// ## 使用示例
/// ```swift
/// let session: TerminalSession = SSHSession(configuration: config)
/// try await session.connect()
/// try await session.send("ls -la\n".data(using: .utf8)!)
///
/// for await data in session.receive() {
///     print(String(data: data, encoding: .utf8) ?? "")
/// }
/// ```
///
/// - Important: 所有 I/O 操作必须使用 async/await，严禁阻塞主线程。
///
public protocol TerminalSession: AnyObject, Identifiable, Sendable {

    // MARK: - 基础属性

    /// 会话唯一标识符
    var id: UUID { get }

    /// 会话显示名称（用户可编辑）
    var name: String { get set }

    /// 当前会话状态
    var state: SessionState { get }

    /// 会话配置（SSH配置或串口配置）
    var configuration: any SessionConfiguration { get }

    // MARK: - 生命周期管理

    /// 建立连接
    ///
    /// 异步建立与远程主机或设备的连接。
    /// 连接成功后，状态转换为 `.connected`。
    ///
    /// - Throws: `CognisError.connectionFailed` 连接失败时
    /// - Throws: `CognisError.authenticationError` 认证失败时
    /// - Throws: `CognisError.sessionAlreadyConnected` 会话已连接时
    ///
    func connect() async throws

    /// 断开连接
    ///
    /// 优雅地关闭连接，释放相关资源。
    /// 断开后，状态转换为 `.disconnected`。
    ///
    func disconnect() async

    /// 重新连接
    ///
    /// 断开当前连接并重新建立连接。
    /// 重连过程中，状态转换为 `.reconnecting`。
    ///
    /// - Throws: `CognisError.connectionFailed` 重连失败时
    ///
    func reconnect() async throws

    // MARK: - 数据传输

    /// 发送数据到远程主机/设备
    ///
    /// 通过 Interactive Channel 发送用户输入数据。
    ///
    /// - Parameter data: 要发送的原始数据
    /// - Throws: `CognisError.sendFailed` 发送失败时
    /// - Throws: `CognisError.sessionClosed` 会话已关闭时
    ///
    func send(_ data: Data) async throws

    /// 接收来自远程主机/设备的数据流
    ///
    /// 返回一个异步数据流，持续接收终端输出。
    /// 数据流会在连接断开时自动结束。
    ///
    /// - Returns: 异步数据流
    ///
    func receive() -> AsyncStream<Data>

    // MARK: - 会话控制

    /// 调整终端窗口大小
    ///
    /// 当用户调整终端窗口大小时，通知远程主机更新 PTY 尺寸。
    ///
    /// - Parameters:
    ///   - width: 终端宽度（列数）
    ///   - height: 终端高度（行数）
    /// - Throws: `CognisError.sendFailed` 发送窗口大小变更失败时
    ///
    func resize(width: Int, height: Int) async throws

    /// 获取远程环境变量
    ///
    /// - Returns: 环境变量字典
    ///
    func getEnvironment() async -> [String: String]
}

// MARK: - 协议扩展：默认实现

public extension TerminalSession {
    /// 默认的重连实现：先断开，再连接
    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

    /// 默认返回空环境变量
    func getEnvironment() async -> [String: String] {
        return [:]
    }
}

// MARK: - SessionState 枚举

/// 会话状态
///
/// 表示终端会话的生命周期状态。
///
/// ## 状态机
/// ```
/// disconnected → connecting → connected → reconnecting → connected
///      ↓              ↓            ↓            ↓
///    error ←─────────┴────────────┴────────────┘
/// ```
///
public enum SessionState: Sendable, Equatable {
    /// 已断开连接
    case disconnected

    /// 正在连接
    case connecting

    /// 已连接
    case connected

    /// 正在重新连接
    case reconnecting

    /// 错误状态
    case error(CognisError)

    /// 是否处于活动状态（连接中或已连接）
    public var isActive: Bool {
        switch self {
        case .connecting, .connected, .reconnecting:
            return true
        case .disconnected, .error:
            return false
        }
    }

    /// 是否可以发送数据
    public var canSendData: Bool {
        self == .connected
    }
}

// MARK: - SessionConfiguration 协议

/// 会话配置协议
///
/// 所有会话配置类型（SSH配置、串口配置）必须遵循此协议。
/// 配置必须支持 Codable 以便持久化存储。
///
public protocol SessionConfiguration: Codable, Sendable {
    /// 配置的显示名称
    var displayName: String { get }

    /// 验证配置是否有效
    func validate() throws
}

// MARK: - SessionType 枚举

/// 会话类型
public enum SessionType: String, Codable, Sendable, CaseIterable {
    /// SSH 远程连接
    case ssh

    /// 串口连接
    case serial

    /// 本地终端
    case local

    /// 类型显示名称
    public var displayName: String {
        switch self {
        case .ssh:
            return "SSH"
        case .serial:
            return "串口"
        case .local:
            return "本地"
        }
    }

    /// SF Symbol 图标名称
    public var iconName: String {
        switch self {
        case .ssh:
            return "network"
        case .serial:
            return "cable.connector"
        case .local:
            return "terminal"
        }
    }
}

// MARK: - DualTrackSession 协议

/// 双轨会话协议（可选实现）
///
/// 支持 AI 静默信道的会话类型应实现此协议。
/// 静默信道用于 AI 诊断命令，与用户交互信道分离。
///
/// - Important: AI 诊断逻辑必须运行在 Silent Channel，严禁干扰用户的 PTY 输入输出。
///
public protocol DualTrackSession: TerminalSession {
    /// 静默信道是否可用
    var isSilentChannelAvailable: Bool { get }

    /// 创建静默信道
    ///
    /// - Throws: `CognisError.silentChannelCreationFailed` 创建失败时
    ///
    func createSilentChannel() async throws

    /// 关闭静默信道
    func closeSilentChannel() async

    /// 通过静默信道执行命令
    ///
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令输出
    /// - Throws: `CognisError.silentChannelError` 执行失败时
    ///
    func executeSilentCommand(_ command: String) async throws -> String
}
