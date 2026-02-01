//
//  LocalTerminalSession.swift
//  CognisApp
//
//  Local Shell Session Implementation
//

import Foundation
import SwiftTerm
import CognisCore
import Darwin // For winsize

// MARK: - Configuration

struct LocalSessionConfiguration: SessionConfiguration {
    var displayName: String = "Local Shell"
    var shellPath: String = "/bin/zsh"

    func validate() throws {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: shellPath) else {
            throw CognisError.invalidConfiguration(reason: "Shell not found or not executable at \(shellPath)")
        }
    }
}

// MARK: - Session Implementation

final class LocalTerminalSession: TerminalSession, DualTrackSession, LocalProcessDelegate, ObservableObject, @unchecked Sendable {

    // MARK: - Properties

    let id = UUID()
    @Published var name: String
    @Published var state: SessionState = .disconnected
    let configuration: any SessionConfiguration

    // Interactive Channel (PTY)
    private var localProcess: LocalProcess?
    private var outputContinuation: AsyncStream<Data>.Continuation?

    // MARK: - Initialization

    init(name: String = "Local Terminal", shellPath: String = "/bin/zsh") {
        self.name = name
        self.configuration = LocalSessionConfiguration(displayName: name, shellPath: shellPath)
    }

    // MARK: - TerminalSession Lifecycle

    func connect() async throws {
        // Prevent re-connection logic issues
        if state == .connected { return }

        await MainActor.run { state = .connecting }

        guard let localConfig = configuration as? LocalSessionConfiguration else {
            let err = CognisError.invalidConfiguration(reason: "Invalid configuration")
            await MainActor.run { state = .error(err) }
            throw err
        }

        // Initialize LocalProcess from SwiftTerm
        let process = LocalProcess(delegate: self)
        self.localProcess = process

        // Build environment with proper TERM settings
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        // Disable Powerline/special characters in simple terminals
        env["POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD"] = "true"
        let envArray = env.map { "\($0.key)=\($0.value)" }

        // Start the process with environment
        process.startProcess(executable: localConfig.shellPath, args: [], environment: envArray)
        await MainActor.run { state = .connected }
    }

    func disconnect() async {
        localProcess?.terminate()
        localProcess = nil
        outputContinuation?.finish()
        outputContinuation = nil
        await MainActor.run { state = .disconnected }
    }

    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

    // MARK: - Interactive Channel (I/O)

    func send(_ data: Data) async throws {
        guard state == .connected, let process = localProcess else {
            throw CognisError.sessionClosed
        }
        process.send(data: ArraySlice(data))
    }

    func receive() -> AsyncStream<Data> {
        // Create a new stream and store continuation
        return AsyncStream { continuation in
            self.outputContinuation = continuation

            // Handle stream termination
            continuation.onTermination = { @Sendable _ in
                // Optional cleanup
            }
        }
    }

    func resize(width: Int, height: Int) async throws {
        guard state == .connected else { return }
        // localProcess?.windowSizeChanged(width: width, height: height)
        // Note: Manual PTY resize requires ioctl which is complex to access from here directly without helpers.
        // Skipping for this iteration.
    }

    func getEnvironment() async -> [String : String] {
        return ProcessInfo.processInfo.environment
    }

    // MARK: - LocalProcessDelegate

    // Called when the child process outputs data
    func dataReceived(slice: ArraySlice<UInt8>) {
        let nsData = Data(slice)
        outputContinuation?.yield(nsData)
    }

    // Called when the child process terminates
    func processTerminated(_ process: LocalProcess, exitCode: Int32?) {
        Task {
            await disconnect()
        }
    }

    func getWindowSize() -> winsize {
        // Default size 80x24
        var ws = winsize()
        ws.ws_col = 80
        ws.ws_row = 24
        return ws
    }

    // MARK: - DualTrackSession (Silent Channel)

    var isSilentChannelAvailable: Bool { true }

    func createSilentChannel() async throws {
        // No persistent connection needed for local silent channel
    }

    func closeSilentChannel() async {
        // No-op
    }

    func executeSilentCommand(_ command: String) async throws -> String {
        // Run a completely separate Process for "Silent" execution
        // This ensures the PTY (Interactive) is not polluted with command output

        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            // Use zsh to execute the command string
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", command]
            task.standardOutput = pipe
            task.standardError = pipe // Capture stderr too

            do {
                try task.run()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                if let output = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(returning: "")
                }
            } catch {
                continuation.resume(throwing: CognisError.silentChannelError(reason: error.localizedDescription))
            }
        }
    }
}
