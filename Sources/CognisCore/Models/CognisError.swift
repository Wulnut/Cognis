//
//  CognisError.swift
//  CognisCore
//
//  Cognis 统一错误类型定义
//  根据 CLAUDE.md 规范：统一使用 throws 抛出具体定义的 CognisError 枚举
//

import Foundation

/// Cognis 应用统一错误类型
///
/// 所有 Cognis 模块应使用此枚举抛出错误，确保错误处理的一致性。
/// 遵循 `LocalizedError` 协议，提供用户友好的错误描述。
///
/// ## 错误分类
/// - 连接错误：网络连接、超时、拒绝连接
/// - 认证错误：凭据验证、密钥认证
/// - 静默信道错误：AI 双轨会话中的静默信道问题
/// - 会话错误：会话生命周期相关
/// - 数据传输错误：发送/接收数据
/// - 配置错误：无效配置参数
///
public enum CognisError: Error, Sendable, LocalizedError, Equatable {

    // MARK: - 连接错误 (Connection Errors)

    /// 连接失败，附带具体原因
    case connectionFailed(reason: String)

    /// 连接超时
    case connectionTimeout

    /// 连接被远程主机拒绝
    case connectionRefused

    /// 网络不可达
    case networkUnreachable

    /// 主机名解析失败
    case hostResolutionFailed(host: String)

    // MARK: - 认证错误 (Authentication Errors)

    /// 认证失败，附带具体原因
    case authenticationError(reason: String)

    /// 无效的用户名或密码
    case invalidCredentials

    /// 公钥被远程主机拒绝
    case publicKeyRejected

    /// 私钥文件未找到或无法读取
    case privateKeyNotFound(path: String)

    /// 私钥密码错误
    case invalidPassphrase

    // MARK: - 静默信道错误 (Silent Channel Errors)

    /// 静默信道操作失败，附带具体原因
    /// - Note: 静默信道用于 AI 诊断，与用户交互信道分离
    case silentChannelError(reason: String)

    /// 静默信道不可用（未创建或已关闭）
    case silentChannelUnavailable

    /// 静默信道创建失败
    case silentChannelCreationFailed

    // MARK: - 会话错误 (Session Errors)

    /// 会话未找到
    case sessionNotFound(id: UUID)

    /// 会话已经处于连接状态
    case sessionAlreadyConnected

    /// 会话已关闭
    case sessionClosed

    /// 会话状态无效（当前状态不允许该操作）
    case invalidSessionState(current: String, expected: String)

    // MARK: - 数据传输错误 (Data Transfer Errors)

    /// 数据发送失败
    case sendFailed(reason: String)

    /// 数据接收失败
    case receiveFailed(reason: String)

    /// 数据编码/解码失败
    case dataEncodingFailed

    // MARK: - 配置错误 (Configuration Errors)

    /// 无效的配置参数
    case invalidConfiguration(reason: String)

    /// 缺少必需的配置字段
    case missingRequiredField(field: String)

    // MARK: - 串口错误 (Serial Port Errors)

    /// 串口未找到
    case serialPortNotFound(path: String)

    /// 串口已被其他进程占用
    case serialPortBusy(path: String)

    /// 无效的波特率
    case invalidBaudRate(rate: Int)

    // MARK: - LocalizedError 实现

    public var errorDescription: String? {
        switch self {
        // 连接错误
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .connectionTimeout:
            return "连接超时"
        case .connectionRefused:
            return "连接被拒绝"
        case .networkUnreachable:
            return "网络不可达"
        case .hostResolutionFailed(let host):
            return "无法解析主机名: \(host)"

        // 认证错误
        case .authenticationError(let reason):
            return "认证失败: \(reason)"
        case .invalidCredentials:
            return "用户名或密码错误"
        case .publicKeyRejected:
            return "公钥被拒绝"
        case .privateKeyNotFound(let path):
            return "私钥文件未找到: \(path)"
        case .invalidPassphrase:
            return "私钥密码错误"

        // 静默信道错误
        case .silentChannelError(let reason):
            return "静默信道错误: \(reason)"
        case .silentChannelUnavailable:
            return "静默信道不可用"
        case .silentChannelCreationFailed:
            return "静默信道创建失败"

        // 会话错误
        case .sessionNotFound(let id):
            return "会话未找到: \(id)"
        case .sessionAlreadyConnected:
            return "会话已连接"
        case .sessionClosed:
            return "会话已关闭"
        case .invalidSessionState(let current, let expected):
            return "无效的会话状态: 当前为 \(current)，期望为 \(expected)"

        // 数据传输错误
        case .sendFailed(let reason):
            return "发送失败: \(reason)"
        case .receiveFailed(let reason):
            return "接收失败: \(reason)"
        case .dataEncodingFailed:
            return "数据编码失败"

        // 配置错误
        case .invalidConfiguration(let reason):
            return "无效配置: \(reason)"
        case .missingRequiredField(let field):
            return "缺少必需字段: \(field)"

        // 串口错误
        case .serialPortNotFound(let path):
            return "串口未找到: \(path)"
        case .serialPortBusy(let path):
            return "串口被占用: \(path)"
        case .invalidBaudRate(let rate):
            return "无效的波特率: \(rate)"
        }
    }

    public var failureReason: String? {
        errorDescription
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionTimeout:
            return "请检查网络连接和防火墙设置"
        case .connectionRefused:
            return "请确认远程主机的 SSH 服务是否正在运行"
        case .invalidCredentials:
            return "请检查用户名和密码是否正确"
        case .publicKeyRejected:
            return "请确认公钥已添加到远程主机的 authorized_keys"
        case .privateKeyNotFound:
            return "请检查私钥文件路径是否正确"
        case .serialPortBusy:
            return "请关闭其他使用该串口的程序"
        default:
            return nil
        }
    }
}
