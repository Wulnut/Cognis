# Cognis 技术栈规格书

## 1. 核心语言与框架
- **开发语言**: Swift 5.10+ (利用其强类型安全性和并发模型)
- **UI 框架**: SwiftUI (用于构建 macOS 原生视觉效果、多栏布局及磨砂玻璃材质)
- **底层架构**: 面向协议编程 (POP) + MVVM

## 2. 通信与终端模块
- **终端模拟引擎**: `SwiftTerm` (高性能 VT100/Xterm 兼容，支持 Sixel 图像及现代终端特性)
- **SSH 协议库**: `libssh2` (通过 Swift 封装，支持多信道 [Channel Multiplexing] 特性)
- **串口库**: `ORSSerialPort` (支持 macOS 即插即用识别及自动化波特率配置)
- **SFTP 引擎**: 基于 `libssh2` 的文件传输子系统

## 3. AI 与 自动化 (AI-Native)
- **AI 协议**: MCP (Model Context Protocol) 
- **AI 模型对接**: 通过内部 Bridge 对接 `ssh-mcp` 服务
- **上下文管理**: 自研 `SessionContextBuffer`，用于实时捕获终端流数据并向量化处理

## 4. 存储与数据管理
- **本地数据库**: `SwiftData` (用于持久化会话配置、标签、密钥及连接历史)
- **密钥管理**: macOS Keychain API (确保用户密码与 SSH 私钥的安全存储)

## 5. 开发工具链
- **AI 辅助**: Gemini-cli
- **设计工具**: Figma
- **编译/构建**: Swift Package Manager (SPM) + Xcode Toolchain

## 6. 测试工具链

### 6.1 单元测试框架
- **XCTest**: Swift原生测试框架，用于核心业务逻辑测试
- **测试覆盖率工具**: Xcode内置覆盖率分析工具
- **Mock框架**: 基于协议的手动Mock实现

### 6.2 集成测试工具
- **SSH连接测试**: 使用本地SSH服务器进行集成测试
- **串口测试**: 使用虚拟串口设备进行模拟测试
- **MCP测试**: 使用Mock MCP服务器验证AI集成

### 6.3 UI测试工具
- **SwiftUI Preview**: 用于快速UI迭代和组件预览
- **XCUITest**: macOS UI自动化测试框架
- **快照测试**: 对关键UI界面进行视觉回归测试

### 6.4 性能测试工具
- **Xcode Instruments**: CPU、内存、网络性能分析
- **Time Profiler**: CPU热点分析
- **Allocations**: 内存分配和泄漏检测
- **Network**: 网络请求和流量分析

## 7. 开发工具链

### 7.1 代码质量工具
- **SwiftLint**: Swift代码风格检查和规范强制
  - 配置规则：行长度限制120字符，函数复杂度限制15
  - 集成到Xcode构建阶段，零警告目标
- **SwiftFormat**: 自动代码格式化工具
  - 统一缩进、空格、换行等格式
  - Git pre-commit hook集成

### 7.2 构建工具
- **Swift Package Manager (SPM)**: 依赖管理和包组织
- **Xcode Cloud**: 云端构建和CI集成（可选）
- **xcbeautify**: 美化Xcode构建输出

### 7.3 部署工具
- **Fastlane**: 自动化构建、签名和发布流程
- **notarytool**: macOS应用公证工具
- **create-dmg**: 创建macOS安装包

### 7.4 文档工具
- **DocC**: Swift文档生成和托管
- **Markdown**: 项目文档和README编写

## 8. CI/CD工具链

### 8.1 持续集成
- **GitHub Actions**: 主要CI/CD平台
  - 自动构建：每次PR触发构建和测试
  - 代码质量检查：SwiftLint自动检查
  - 测试运行：单元测试和集成测试自动运行
- **工作流配置**:
  - PR检查：构建 + 测试 + Lint
  - 主分支：完整测试套件 + 性能测试
  - 标签发布：构建 + 签名 + 公证 + 发布

### 8.2 持续部署
- **自动化打包**: 使用Fastlane脚本自动打包
- **代码签名**: 使用Xcode签名和Apple开发者证书
- **公证流程**: 自动提交到Apple公证服务
- **版本管理**: 自动生成版本号和变更日志

## 9. 监控和运维工具链

### 9.1 应用监控
- **崩溃报告**:
  - 开发阶段：Xcode Organizer本地崩溃报告
  - 生产环境：考虑集成Sentry或自建崩溃收集系统
- **性能监控**:
  - MetricKit：收集应用性能指标
  - 自定义埋点：关键操作耗时统计
- **用户分析**（可选）:
  - 匿名化使用统计
  - 功能使用频率分析

### 9.2 日志系统
- **OSLog**: macOS原生统一日志系统
  - 支持日志级别：Debug、Info、Default、Error、Fault
  - 支持结构化日志和隐私保护
- **日志策略**:
  - 开发环境：Debug级别，控制台输出
  - 生产环境：Default级别，系统日志持久化
  - 错误追踪：关键错误自动上报

### 9.3 错误跟踪
- **GitHub Issues**: 用户反馈和Bug追踪
- **内置反馈**: 应用内错误报告功能
- **诊断日志**: 自动收集系统诊断信息

## 10. 安全和隐私工具

### 10.1 安全审计
- **App Sandbox**: 严格沙盒配置审计
- **Entitlements**: 最小权限原则检查
- **代码签名**: 签名验证和证书管理

### 10.2 依赖扫描
- **Swift Package Manager审计**: 定期检查依赖更新和安全漏洞
- **第三方库审计**: 评估第三方库的安全性和维护状态

### 10.3 隐私合规
- **隐私清单**: 声明所有数据收集和使用
- **用户同意**: 敏感操作需要用户明确授权
- **数据加密**: 敏感数据传输和存储加密
