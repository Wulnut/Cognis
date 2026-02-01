# Cognis 数据模型与安全设计

## 1. 数据模型设计

### 1.1 实体关系图 (ERD)

```mermaid
erDiagram
    SessionConfiguration ||--o{ TerminalSession : configures
    TerminalSession ||--o{ ConnectionHistory : generates
    TerminalSession ||--o{ CommandHistory : contains
    TerminalSession ||--|| AIContext : has
    AIContext ||--o{ AIRecommendation : produces

    SessionGroup ||--o{ SessionConfiguration : contains

    class SessionConfiguration {
        UUID id
        String name
        SessionType type
        Date createdAt
        Date updatedAt
    }

    class TerminalSession {
        UUID id
        Date startTime
        Date endTime
    }
```

### 1.2 SwiftData 模型设计

#### 1.2.1 SessionConfiguration (会话配置)
```swift
@Model
final class SessionConfiguration {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: SessionType
    var group: String?
    var tags: [String]
    var iconName: String?
    var colorHex: String?
    var lastUsed: Date?
    var createdAt: Date

    // SSH特定配置
    var sshHost: String?
    var sshPort: Int?
    var sshUsername: String?
    var sshAuthType: SSHAuthType?
    var sshKeyPath: String? // 仅存储路径，不存储内容

    // 串口特定配置
    var serialPath: String?
    var serialBaudRate: Int?
    var serialDataBits: Int?
    var serialStopBits: Int?
    var serialParity: ParityType?

    // 关联
    @Relationship(deleteRule: .cascade) var histories: [ConnectionHistory]

    init(name: String, type: SessionType) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.createdAt = Date()
    }
}

enum SessionType: String, Codable {
    case ssh
    case serial
    case local
}

enum SSHAuthType: String, Codable {
    case password
    case key
    case agent
}
```

#### 1.2.2 ConnectionHistory (连接历史)
```swift
@Model
final class ConnectionHistory {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var status: ConnectionStatus
    var errorMessage: String?
    var bytesSent: Int64
    var bytesReceived: Int64

    // 关联
    var configuration: SessionConfiguration?

    init(startTime: Date = Date()) {
        self.id = UUID()
        self.startTime = startTime
        self.status = .connecting
        self.bytesSent = 0
        self.bytesReceived = 0
    }
}

enum ConnectionStatus: String, Codable {
    case connecting
    case connected
    case disconnected
    case failed
}
```

#### 1.2.3 AIContextHistory (AI上下文历史)
```swift
@Model
final class AIContextHistory {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var sessionId: UUID
    var summary: String
    var detectedIssues: [String]
    var recommendationsCount: Int

    // 不存储完整上下文，只存储元数据
    // 完整日志存储在文件系统中
}
```

### 1.3 内存数据结构

#### 1.3.1 SessionContextBuffer (会话上下文缓冲)
用于实时存储终端输出，供AI分析。不持久化到数据库。

```swift
actor SessionContextBuffer {
    private var buffer: CircularBuffer<String>
    private let maxLines: Int = 10000

    // 结构化行数据
    struct LogLine {
        let timestamp: Date
        let content: String
        let type: OutputType // stderr, stdout
    }

    // 获取最近N行
    func getRecentLines(count: Int) -> [String]

    // 获取特定时间段的日志
    func getLines(from start: Date, to end: Date) -> [String]
}
```

#### 1.3.2 TerminalBuffer (终端显示缓冲)
SwiftTerm维护的显示缓冲区，负责屏幕渲染。

## 2. 安全详细设计

### 2.1 认证与授权

#### 2.1.1 Keychain集成
敏感信息绝不存储在SwiftData或普通文件中，必须使用macOS Keychain。

- **SSH密码**: 存储在Keychain中，Service=`com.cognis.ssh.password`, Account=`UUID`
- **SSH私钥密码**: 存储在Keychain中，Service=`com.cognis.ssh.keypass`, Account=`UUID`
- **API Keys**: 如果使用云端AI服务，Key存储在Keychain中

```swift
struct KeychainHelper {
    static func save(password: String, for account: String) throws
    static func get(account: String) throws -> String?
    static func delete(account: String) throws
}
```

#### 2.1.2 Touch ID / Face ID 集成
对于敏感操作（如查看密码、导出私钥），要求生物识别认证。

```swift
func authenticateUser(reason: String) async throws -> Bool {
    let context = LAContext()
    // LocalAuthentication 实现
}
```

### 2.2 数据安全

#### 2.2.1 传输加密
- **SSH连接**: 强制使用SSH v2协议，禁用不安全的加密算法（如DES, RC4）
- **MCP通信**: 本地通信使用Stdio，远程通信使用TLS 1.3
- **云同步**: 如果启用iCloud同步，使用CloudKit加密存储

#### 2.2.2 静态数据加密
- SwiftData默认存储在应用沙盒中，受OS保护
- 敏感配置导出时支持AES-256加密

#### 2.2.3 内存安全
- 密码和私钥使用`SecureString`类型，使用后立即清零
- 禁止在Debug日志中打印敏感信息（密码、私钥、Token）

### 2.3 沙盒安全 (App Sandbox)

#### 2.3.1 Entitlements 配置
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 网络连接：允许SSH连接 -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- 串口通信：允许访问USB串口设备 -->
    <key>com.apple.security.device.serial</key>
    <true/>
    <key>com.apple.security.device.usb</key>
    <true/>

    <!-- 文件访问：允许用户选择文件上传/下载 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- 下载文件夹访问 -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

#### 2.3.2 文件访问策略
- **Security-Scoped Bookmarks**: 访问用户选择的外部文件或目录（如SSH Key）时，必须持久化权限书签
- **临时文件**: 所有临时文件存储在`NSTemporaryDirectory()`，退出时清理

## 3. 隐私保护

### 3.1 数据收集策略
- **最小化收集**: 仅收集必要的崩溃日志和性能指标
- **本地优先**: 所有会话数据、命令历史、AI分析结果默认仅存储在本地
- **AI隐私**:
  - 用户可选择AI模型（本地模型 vs 云端模型）
  - 发送给AI的数据经过脱敏处理（尝试隐藏密码、IP等敏感信息）

### 3.2 数据清理
- **自动清理**: 支持配置历史记录保留时间（如30天），过期自动删除
- **一键清除**: 提供"清除所有历史"和"重置应用"功能
- **隐私模式**: 支持"无痕模式"会话，不记录任何历史和日志

### 3.3 敏感信息过滤
在发送数据给AI层之前，通过正则匹配过滤敏感信息：

```swift
struct PrivacyFilter {
    static let sensitivePatterns: [NSRegularExpression] = [
        // IPv4地址
        try! NSRegularExpression(pattern: "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"),
        // Email
        try! NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"),
        // AWS Key
        try! NSRegularExpression(pattern: "AKIA[0-9A-Z]{16}"),
        // Private Key Header
        try! NSRegularExpression(pattern: "-----BEGIN [A-Z]+ PRIVATE KEY-----")
    ]

    static func redact(text: String) -> String {
        // 替换为 [REDACTED]
    }
}
```

## 4. 备份与恢复

### 4.1 导出/导入
- **格式**: JSON格式导出配置（不含密码）
- **加密包**: 支持导出加密的备份包（含密码，需主密码解密）

### 4.2 iCloud同步
- 通过CloudKit同步会话配置（SessionConfiguration）
- 不同步连接历史和大量日志
- Keychain项通过iCloud Keychain同步

## 5. 合规性
- **GDPR**: 提供数据导出和删除功能
- **App Store审核**: 确保符合Apple隐私准则，特别是关于远程控制和脚本执行的规定
