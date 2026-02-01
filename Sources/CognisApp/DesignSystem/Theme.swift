//
//  Theme.swift
//  CognisApp
//
//  Design System Definition
//  遵循 CLAUDE.md: Design System First
//

import SwiftUI

enum Theme {
    enum Colors {
        // Semantic colors adapting to Light/Dark mode
        static let background = Color(nsColor: .windowBackgroundColor)
        static let secondaryBackground = Color(nsColor: .controlBackgroundColor)

        // Terminal specific
        static let terminalBackground = Color.black
        static let terminalText = Color.white

        // State colors
        static let connected = Color.green
        static let disconnected = Color.gray
        static let error = Color.red
        static let warning = Color.orange

        // Brand
        static let accent = Color.accentColor
    }

    enum Materials {
        // macOS Native Materials for transparency
        // 侧边栏使用 .thinMaterial
        static let sidebar = Material.thin
        // 内容/检查器使用 .ultraThinMaterial
        static let content = Material.ultraThin
        // 弹出层
        static let popover = Material.regular
    }

    enum Radius {
        // 小组件/按钮
        static let small: CGFloat = 6.0
        // 标准容器/卡片
        static let main: CGFloat = 12.0
    }

    enum Spacing {
        static let xs: CGFloat = 4.0
        static let s: CGFloat = 8.0
        static let m: CGFloat = 12.0
        static let l: CGFloat = 16.0
        static let xl: CGFloat = 24.0
        static let xxl: CGFloat = 32.0
    }

    enum Fonts {
        // 等宽字体用于终端
        static let terminal = Font.system(.body, design: .monospaced)
        // 标题
        static let header = Font.headline
    }
}
