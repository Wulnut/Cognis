# Cognis

[![CI](https://github.com/Wulnut/Cognis/actions/workflows/swift.yml/badge.svg)](https://github.com/Wulnut/Cognis/actions/workflows/swift.yml)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)
![Platform macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![License Private](https://img.shields.io/badge/license-Private-red.svg)

Cognis 是一款 macOS 原生智能终端管理器，结合了 MobaXterm 的强大功能与 Termius 的现代视觉体验。

## 🚀 项目愿景

- **核心逻辑**: MobaXterm 的强悍功能 (SSH/Serial/SFTP) + Termius 的现代视觉 (SwiftUI)
- **AI 特性**: 基于 MCP 协议的原生集成，利用 SSH 多信道实现“双轨会话”（Interactive + Silent）
- **平台**: macOS 14+ (Sonoma)

## 💻 开发指令 (Development Commands)

以下是 Swift 开发中常用的 CLI 命令：

| 命令 | 描述 | 备注 |
|------|------|------|
| `swift build` | 编译项目 | 默认构建 Debug 版本 |
| `swift build -c release` | 编译发布版本 | 包含优化 |
| `swift run` | 运行可执行文件 | 如果有多个目标需指定名称 |
| `swift test` | 运行测试套件 | 执行所有单元测试 |
| `swift package clean` | 清理构建产物 | 删除 `.build` 目录 |
| `swift package update` | 更新依赖包 | 更新到允许的最新版本 |
| `swift package resolve` | 解析依赖 | 下载并锁定依赖版本 |
| `swift package describe` | 查看包描述 | 显示 targets 和依赖关系 |

## 🏗️ 核心架构

项目遵循 **双轨会话 (Dual-Track)** 架构原则：
1. **Interactive Channel**: 用于用户交互 (PTY)
2. **Silent Channel**: 用于 AI 诊断和 MCP 操作 (Exec/Direct)

所有 I/O 操作严格使用 Swift `async/await` 异步模型。

## 📚 文档

详细文档位于 `doc/` 目录下：
- [架构设计](doc/ARCHITECTURE.md)
- [技术栈](doc/Cognis_Tech_Stack.md)
- [开发指南](CLAUDE.md) (包含代码规范)

## 许可证

Private
