//
//  SwiftTermView.swift
//  CognisApp
//
//  NSViewRepresentable wrapper for SwiftTerm using LocalProcessTerminalView
//

import SwiftUI
import SwiftTerm
import CognisCore

// MARK: - SwiftUI Wrapper

struct SwiftTermView: NSViewRepresentable {
    let session: any TerminalSession

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Design System Integration
        if let nerdFont = NSFont(name: "MesloLGS NF", size: 13) {
            terminalView.font = nerdFont
        } else if let menlo = NSFont(name: "Menlo", size: 13) {
            terminalView.font = menlo
        } else {
            terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        terminalView.nativeBackgroundColor = NSColor(Theme.Colors.terminalBackground)
        terminalView.nativeForegroundColor = NSColor(Theme.Colors.terminalText)

        // Set delegate for process events
        terminalView.processDelegate = context.coordinator
        context.coordinator.terminalView = terminalView
        context.coordinator.session = session

        // Start the shell process
        startShell(terminalView: terminalView)

        // Auto-focus with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // If session changed, we might need to restart
        if context.coordinator.session?.id != session.id {
            context.coordinator.session = session
            // Re-focus on session change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func startShell(terminalView: LocalProcessTerminalView) {
        // Get the user's default shell
        let shell = getShell()
        let shellName = "-" + (shell as NSString).lastPathComponent

        // Change to home directory
        FileManager.default.changeCurrentDirectoryPath(
            FileManager.default.homeDirectoryForCurrentUser.path
        )

        // Start the process - LocalProcessTerminalView handles everything internally
        terminalView.startProcess(executable: shell, execName: shellName)
    }

    private func getShell() -> String {
        let bufsize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufsize != -1 else {
            return "/bin/zsh"
        }
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufsize)
        defer { buffer.deallocate() }

        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>? = UnsafeMutablePointer<passwd>.allocate(capacity: 1)

        if getpwuid_r(getuid(), &pwd, buffer, bufsize, &result) != 0 {
            return "/bin/zsh"
        }
        return String(cString: pwd.pw_shell)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var session: (any TerminalSession)?
        weak var terminalView: LocalProcessTerminalView?

        // MARK: - LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Terminal resized - could update session if needed
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Could update window title
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Could track current directory
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Process ended - could handle cleanup
            print("[SwiftTermView] Process terminated with exit code: \(exitCode ?? -1)")
        }
    }
}
