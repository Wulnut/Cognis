# Cognis AI集成详细设计

## 1. AI集成架构

### 1.1 总体流程
```
Terminal Output -> Context Buffer -> Pattern Recognition -> AI Trigger
                                                              |
                                                              v
AI Service <- MCP Protocol <- Context Assembly <- AI Coordinator
     |
     v
Response -> Response Parsing -> Recommendation Engine -> UI Display
                                         |
                                         v
                                  Action Execution -> Silent Channel
```

### 1.2 核心组件
- **ContextBuffer**: 实时收集终端输出，维护滑动窗口
- **AICoordinator**: 协调分析请求，管理AI状态
- **MCPClient**: 实现Model Context Protocol，对接AI后端
- **RecommendationEngine**: 将AI响应转换为结构化建议
- **ExecutionManager**: 安全执行AI建议的操作

## 2. MCP协议集成

### 2.1 架构选择
采用 **Client-Host-Server** 架构：
- **Cognis App**: 扮演 MCP Client 和 MCP Host
- **Internal Bridge**: 内部桥接层
- **AI Service**: 外部 MCP Server (如 ssh-mcp, filesystem-mcp)

### 2.2 核心接口实现

#### 2.2.1 初始化
```json
// Client -> Server
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {
    "protocolVersion": "0.1.0",
    "capabilities": {
      "roots": { "listChanged": true },
      "sampling": {}
    },
    "clientInfo": { "name": "Cognis", "version": "1.0.0" }
  }
}
```

#### 2.2.2 Tool调用
AI模型通过Tool Call来执行操作。Cognis提供以下核心Tool：

```swift
// Tool定义
let executeCommandTool = Tool(
    name: "execute_command",
    description: "Execute a shell command on the connected remote server",
    inputSchema:JSONSchema(
        properties: [
            "command": .string(description: "The command to execute"),
            "reason": .string(description: "Why this command is needed"),
            "is_dangerous": .boolean(description: "Whether this command modifies system state")
        ],
        required: ["command", "reason"]
    )
)
```

### 2.3 ssh-mcp 服务集成
`ssh-mcp` 是一个运行在本地的MCP Server，负责通过SSH协议操作远程服务器。

- **连接方式**: Stdio (标准输入输出)
- **生命周期**: 每个Terminal Session启动一个对应的ssh-mcp实例
- **通信**: 通过 `SSHSession.silentChannel` 转发实际命令

## 3. 上下文管理

### 3.1 实时上下文捕获
- **滑动窗口**: 保持最近N行（如200行）或M个Token的上下文
- **结构化解析**: 识别Prompt、Command、Output、Error部分
- **重要性标记**: 标记包含错误关键词的行

### 3.2 向量化与检索 (RAG) - *二期规划*
- **本地Embedding**: 使用CoreML运行轻量级Embedding模型
- **向量数据库**: 使用SQLite-vss或纯内存向量索引
- **检索策略**: 当上下文超出窗口时，检索相关的历史片段

### 3.3 Prompt工程

#### 系统提示词 (System Prompt)
```text
You are Cognis AI, an intelligent assistant embedded in a terminal emulator.
Your goal is to help users diagnose issues, optimize performance, and explain complex commands.

CONTEXT:
User is connected to: {host} ({os_version})
Current shell: {shell_type}
Recent history:
{history_summary}

RULES:
1. Be concise. Terminal users prefer short, actionable advice.
2. When suggesting commands, use the `execute_command` tool.
3. Mark dangerous commands (rm, dd, mkfs, etc.) clearly.
4. If you see an error, explain the root cause first, then suggest a fix.
```

## 4. AI响应处理

### 4.1 建议生成算法
当AI返回响应时，解析为以下三种类型之一：

1. **解释 (Explanation)**: 纯文本解释，显示在AI面板
2. **命令建议 (Command)**: 可执行的Shell命令，显示为卡片
3. **操作序列 (Playbook)**: 多个步骤的组合

### 4.2 建议优先级排序
```swift
enum Priority {
    case critical // 系统崩溃、数据风险 (红色)
    case high     // 错误修复 (橙色)
    case medium   // 优化建议 (蓝色)
    case low      // 信息提示 (灰色)
}

func calculatePriority(content: String, errorType: ErrorType?) -> Priority {
    if content.contains("Kernel Panic") { return .critical }
    if content.contains("Permission denied") { return .high }
    // ...
}
```

### 4.3 执行管理
- **一键执行**: 用户点击"Execute"按钮
- **安全检查**:
  - 检查命令是否包含高危操作 (`rm -rf /`)
  - 检查是否需要sudo权限
- **执行反馈**:
  - 执行中：显示Spinner
  - 执行成功：显示绿色对勾
  - 执行失败：显示错误信息并允许重试

## 5. 触发机制

### 5.1 被动触发 (Auto-Analysis)
系统自动监测终端输出，符合特征时触发AI分析。

- **错误模式匹配**:
  - Exit code != 0
  - 关键词: "Error", "Failed", "Exception", "Panic", "Timeout"
  - 正则: `Command not found`, `Connection refused`

- **防抖动**: 避免在大量输出时频繁触发，设置触发冷却时间（如5秒）

### 5.2 主动触发 (Manual)
- **快捷键**: `Cmd+Shift+A` 主动请求分析当前屏幕
- **选中询问**: 选中一段文本 -> 右键 -> "Ask AI"
- **输入框**: 在AI面板输入自然语言问题

## 6. 模型配置

### 6.1 支持的模型后端
1. **Cloud Models** (默认):
   - Claude 3.5 Sonnet (推荐用于代码生成)
   - GPT-4o
2. **Local Models** (隐私优先):
   - Ollama (Llama 3, Mistral)
   - MLX (Apple Silicon优化)

### 6.2 成本控制
- **Token计数**: 实时估算Token消耗
- **限额设置**: 允许用户设置每日/每月API调用限额
- **缓存**: 对相似的错误上下文缓存AI响应，避免重复查询

## 7. 性能优化
- **异步推理**: AI请求绝不阻塞UI线程
- **流式响应**: 使用Streaming API，实现打字机效果，降低感知延迟
- **后台处理**: 在Tab切换到后台时暂停自动分析，节省资源
