# Cognis 技术栈扩展文档

## 1. CI/CD 详细配置

### 1.1 GitHub Actions 工作流

#### 1.1.1 PR检查工作流 (`.github/workflows/pr-check.yml`)
```yaml
name: PR Check

on:
  pull_request:
    branches: [main, develop]

jobs:
  build-and-test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: .build
          key: ${{ runner.os }}-spm-${{ hashFiles('Package.resolved') }}

      - name: Build
        run: swift build

      - name: Run Tests
        run: swift test --parallel

      - name: SwiftLint
        run: |
          brew install swiftlint
          swiftlint --strict

  code-coverage:
    runs-on: macos-14
    needs: build-and-test
    steps:
      - uses: actions/checkout@v4
      - name: Generate Coverage
        run: |
          swift test --enable-code-coverage
          xcrun llvm-cov export -format="lcov" \
            .build/debug/CognisPackageTests.xctest/Contents/MacOS/CognisPackageTests \
            -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
      - name: Upload Coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.lcov
```

#### 1.1.2 发布工作流 (`.github/workflows/release.yml`)
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Import Certificates
        env:
          CERTIFICATE_P12: ${{ secrets.CERTIFICATE_P12 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          echo $CERTIFICATE_P12 | base64 --decode > certificate.p12
          security create-keychain -p "" build.keychain
          security import certificate.p12 -k build.keychain -P $CERTIFICATE_PASSWORD -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain

      - name: Build Archive
        run: |
          xcodebuild archive \
            -project Cognis.xcodeproj \
            -scheme Cognis \
            -archivePath build/Cognis.xcarchive \
            -configuration Release

      - name: Export App
        run: |
          xcodebuild -exportArchive \
            -archivePath build/Cognis.xcarchive \
            -exportPath build/export \
            -exportOptionsPlist ExportOptions.plist

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcrun notarytool submit build/export/Cognis.app.zip \
            --apple-id $APPLE_ID \
            --password $APPLE_PASSWORD \
            --team-id $TEAM_ID \
            --wait

      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg \
            --volname "Cognis" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --app-drop-link 400 185 \
            build/Cognis-${{ github.ref_name }}.dmg \
            build/export/Cognis.app

      - name: Upload Release Asset
        uses: softprops/action-gh-release@v1
        with:
          files: build/Cognis-${{ github.ref_name }}.dmg
```

### 1.2 Fastlane 配置

#### 1.2.1 Fastfile
```ruby
# Fastfile
default_platform(:mac)

platform :mac do
  desc "Run all tests"
  lane :test do
    run_tests(
      project: "Cognis.xcodeproj",
      scheme: "Cognis",
      clean: true
    )
  end

  desc "Build release version"
  lane :build_release do
    build_mac_app(
      project: "Cognis.xcodeproj",
      scheme: "Cognis",
      configuration: "Release",
      export_method: "developer-id",
      output_directory: "./build"
    )
  end

  desc "Notarize the app"
  lane :notarize_app do
    notarize(
      package: "./build/Cognis.app",
      bundle_id: "com.cognis.app",
      username: ENV["APPLE_ID"],
      asc_provider: ENV["TEAM_ID"]
    )
  end

  desc "Full release pipeline"
  lane :release do
    test
    build_release
    notarize_app
  end
end
```

### 1.3 版本管理

#### 1.3.1 语义化版本 (Semantic Versioning)
- **格式**: `MAJOR.MINOR.PATCH` (如 `1.2.3`)
- **MAJOR**: 不兼容的API变更
- **MINOR**: 向后兼容的功能新增
- **PATCH**: 向后兼容的Bug修复

#### 1.3.2 版本号自动化
```bash
# 使用git tag触发版本更新
git tag v1.0.0
git push origin v1.0.0
```

## 2. 代码质量工具配置

### 2.1 SwiftLint 配置 (`.swiftlint.yml`)
```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - identifier_name

opt_in_rules:
  - empty_count
  - explicit_init
  - closure_spacing
  - overridden_super_call
  - redundant_nil_coalescing
  - private_outlet
  - nimble_operator
  - attributes
  - operator_usage_whitespace
  - closure_end_indentation
  - first_where
  - object_literal
  - number_separator
  - prohibited_super_call
  - fatal_error_message

excluded:
  - Carthage
  - Pods
  - .build
  - Tests

line_length:
  warning: 120
  error: 150
  ignores_comments: true

type_body_length:
  warning: 300
  error: 400

file_length:
  warning: 500
  error: 1000

function_body_length:
  warning: 40
  error: 80

cyclomatic_complexity:
  warning: 10
  error: 15

nesting:
  type_level: 2
  function_level: 3

reporter: "xcode"
```

### 2.2 SwiftFormat 配置 (`.swiftformat`)
```
# .swiftformat

# 格式化规则
--swiftversion 5.10
--indent 4
--indentcase false
--trimwhitespace always
--voidtype void
--wraparguments before-first
--wrapcollections before-first
--maxwidth 120
--semicolons never
--commas always
--stripunusedargs closure-only
--self init-only
--importgrouping testable-bottom

# 禁用规则
--disable redundantSelf
--disable trailingClosures

# 排除目录
--exclude .build,Pods,Carthage
```

### 2.3 Pre-commit Hook
```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running SwiftFormat..."
swiftformat . --lint

echo "Running SwiftLint..."
swiftlint --strict

if [ $? -ne 0 ]; then
  echo "❌ Code quality checks failed. Please fix the issues before committing."
  exit 1
fi

echo "✅ All checks passed!"
```

## 3. 测试框架详细配置

### 3.1 单元测试结构
```
Tests/
├── CognisTests/
│   ├── Session/
│   │   ├── SSHSessionTests.swift
│   │   ├── SerialSessionTests.swift
│   │   └── SessionManagerTests.swift
│   ├── AI/
│   │   ├── AICoordinatorTests.swift
│   │   ├── ContextBufferTests.swift
│   │   └── MCPClientTests.swift
│   ├── Model/
│   │   ├── SessionConfigurationTests.swift
│   │   └── ConnectionHistoryTests.swift
│   └── Mocks/
│       ├── MockTerminalSession.swift
│       ├── MockMCPClient.swift
│       └── MockDataHub.swift
└── CognisUITests/
    ├── SessionManagementUITests.swift
    ├── TerminalInteractionUITests.swift
    └── AIInspectorUITests.swift
```

### 3.2 Mock策略
```swift
// MockTerminalSession.swift
final class MockTerminalSession: TerminalSession {
    var id: UUID = UUID()
    var name: String = "Mock Session"
    var state: SessionState = .disconnected
    var configuration: SessionConfiguration = .default

    // 测试辅助
    var connectCalled = false
    var sentData: [Data] = []
    var mockReceiveData: AsyncStream<Data>?

    func connect() async throws {
        connectCalled = true
        state = .connected
    }

    func send(_ data: Data) async throws {
        sentData.append(data)
    }

    func receive() -> AsyncStream<Data> {
        return mockReceiveData ?? AsyncStream { _ in }
    }
}
```

### 3.3 UI测试示例
```swift
// SessionManagementUITests.swift
import XCTest

final class SessionManagementUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testCreateSSHSession() throws {
        // 点击新建按钮
        app.buttons["New Session"].click()

        // 填写表单
        let hostField = app.textFields["Host"]
        hostField.click()
        hostField.typeText("192.168.1.100")

        let usernameField = app.textFields["Username"]
        usernameField.click()
        usernameField.typeText("admin")

        // 保存
        app.buttons["Connect"].click()

        // 验证会话已创建
        XCTAssertTrue(app.staticTexts["192.168.1.100"].exists)
    }
}
```

### 3.4 性能测试
```swift
func testTerminalRenderingPerformance() throws {
    measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
        // 模拟大量终端输出
        for _ in 0..<1000 {
            terminalView.appendOutput(generateRandomOutput(lines: 100))
        }
    }
}
```

## 4. 监控与日志系统

### 4.1 OSLog 配置
```swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!

    /// Session相关日志
    static let session = Logger(subsystem: subsystem, category: "Session")

    /// AI相关日志
    static let ai = Logger(subsystem: subsystem, category: "AI")

    /// 网络相关日志
    static let network = Logger(subsystem: subsystem, category: "Network")

    /// UI相关日志
    static let ui = Logger(subsystem: subsystem, category: "UI")
}

// 使用示例
Logger.session.info("SSH connection established to \(host, privacy: .public)")
Logger.ai.error("MCP client error: \(error.localizedDescription, privacy: .public)")
Logger.network.debug("Bytes received: \(count)")
```

### 4.2 日志级别策略
| 级别 | 用途 | 生产环境 |
|------|------|----------|
| `.debug` | 详细调试信息 | 不记录 |
| `.info` | 一般信息 | 不持久化 |
| `.default` | 重要事件 | 持久化 |
| `.error` | 错误信息 | 持久化 + 上报 |
| `.fault` | 系统级故障 | 持久化 + 立即上报 |

### 4.3 崩溃报告集成
```swift
// 使用 MetricKit 收集诊断信息
import MetricKit

class DiagnosticSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            // 处理崩溃报告
            if let crashDiagnostics = payload.crashDiagnostics {
                handleCrashDiagnostics(crashDiagnostics)
            }
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // 处理性能指标
            Logger.default.info("App launch time: \(payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.bucketEnumerator)")
        }
    }
}
```

### 4.4 性能指标收集
```swift
import MetricKit

struct PerformanceMonitor {
    static func startMonitoring() {
        MXMetricManager.shared.add(DiagnosticSubscriber())
    }

    /// 自定义指标
    static func recordCommandExecutionTime(_ duration: TimeInterval) {
        // 使用 signpost 记录
        let signposter = OSSignposter()
        // ...
    }
}
```

## 5. 部署与分发

### 5.1 构建配置

#### Debug 配置
- 优化级别: `-Onone`
- 调试符号: 完整
- 断言: 启用
- SwiftLint: 警告模式

#### Release 配置
- 优化级别: `-O`
- 调试符号: dSYM分离
- 断言: 禁用
- Strip: 启用

### 5.2 代码签名

#### 开发签名
- Team: 开发者Team ID
- Signing Certificate: Apple Development
- Provisioning Profile: 自动管理

#### 发布签名
- Team: 发布Team ID
- Signing Certificate: Developer ID Application
- Hardened Runtime: 启用

### 5.3 公证流程
```bash
# 1. 创建ZIP包
ditto -c -k --keepParent "Cognis.app" "Cognis.zip"

# 2. 提交公证
xcrun notarytool submit Cognis.zip \
  --apple-id "your@email.com" \
  --password "@keychain:AC_PASSWORD" \
  --team-id "TEAM_ID" \
  --wait

# 3. Staple
xcrun stapler staple "Cognis.app"

# 4. 验证
spctl -a -vv "Cognis.app"
```

### 5.4 分发渠道

#### Mac App Store
- 需要额外的沙盒限制
- 审核周期：1-3天
- 自动更新

#### 直接下载 (Developer ID)
- DMG格式分发
- 公证必需
- 需自建更新机制（Sparkle）

### 5.5 自动更新 (Sparkle)
```swift
// 集成 Sparkle 框架
import Sparkle

let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)

// appcast.xml 托管在 GitHub Releases
```

## 6. 开发环境设置

### 6.1 必备工具
```bash
# Xcode Command Line Tools
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 开发工具
brew install swiftlint swiftformat gh

# 可选：本地AI模型
brew install ollama
```

### 6.2 项目初始化
```bash
# 克隆项目
git clone https://github.com/your-org/cognis.git
cd cognis

# 安装 Git Hooks
cp scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

# 打开项目
open Cognis.xcodeproj
```

### 6.3 环境变量
```bash
# .env.local (不提交到Git)
APPLE_ID=your@email.com
APPLE_TEAM_ID=XXXXXXXXXX
OPENAI_API_KEY=sk-xxxxx  # 如果使用云端AI
```

## 7. 第三方依赖管理

### 7.1 SPM 依赖清单
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
    .package(url: "https://github.com/libssh2/libssh2", from: "1.11.0"),
    .package(url: "https://github.com/armadsen/ORSSerialPort", from: "2.1.0"),
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
]
```

### 7.2 依赖更新策略
- **每月检查**: 检查依赖更新和安全公告
- **锁定版本**: 使用 `Package.resolved` 锁定精确版本
- **安全扫描**: 使用 GitHub Dependabot 自动扫描

### 7.3 许可证合规
| 依赖 | 许可证 | 合规要求 |
|------|--------|----------|
| SwiftTerm | MIT | 保留版权声明 |
| libssh2 | BSD-3 | 保留版权声明 |
| ORSSerialPort | MIT | 保留版权声明 |
| Sparkle | MIT | 保留版权声明 |

## 8. 文档生成

### 8.1 DocC 配置
```swift
// 在代码中添加文档注释
/// A terminal session that connects to a remote server via SSH.
///
/// Use `SSHSession` to establish secure shell connections:
///
/// ```swift
/// let session = SSHSession(configuration: config)
/// try await session.connect()
/// ```
///
/// - Note: Requires network access entitlement.
/// - Important: Always call `disconnect()` when done.
public final class SSHSession: TerminalSession {
    // ...
}
```

### 8.2 生成文档
```bash
# 生成文档
swift package generate-documentation

# 预览文档
swift package --disable-sandbox preview-documentation
```

## 9. 故障排除指南

### 9.1 常见构建问题

#### libssh2 链接失败
```bash
# 确保已安装 libssh2
brew install libssh2

# 设置 PKG_CONFIG_PATH
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"
```

#### 签名问题
```bash
# 重置签名
codesign --remove-signature Cognis.app
codesign -s "Developer ID Application: Your Name" --deep --force Cognis.app
```

### 9.2 调试技巧

#### SSH调试
```swift
// 启用 libssh2 详细日志
setenv("LIBSSH2_DEBUG", "1", 1)
```

#### SwiftTerm调试
```swift
// 启用终端调试输出
terminalView.debug = true
```

### 9.3 性能分析
```bash
# 使用 Instruments
xcrun xctrace record --template 'Time Profiler' --launch Cognis.app

# 内存泄漏检测
leaks --atExit -- ./Cognis.app/Contents/MacOS/Cognis
```
