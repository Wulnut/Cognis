//
//  MockSession.swift
//  CognisApp
//
//  Mock Terminal Session for Dual-Track Demo
//

import Foundation
import CognisCore

// Mock Configuration
struct MockConfiguration: SessionConfiguration {
    var displayName: String

    func validate() throws {
        // Mock always valid
    }
}

// Mock Session implementing Dual-Track
class MockSession: DualTrackSession, ObservableObject, Identifiable, @unchecked Sendable {
    let id = UUID()
    @Published var name: String
    @Published var state: SessionState = .disconnected
    @Published var lastAnalysis: String?

    let configuration: any SessionConfiguration

    // Internal simulation state
    private var outputContinuation: AsyncStream<Data>.Continuation?

    init(name: String) {
        self.name = name
        self.configuration = MockConfiguration(displayName: name)
    }

    // MARK: - Lifecycle

    func connect() async throws {
        // Prevent connecting if already connected
        guard state != .connected else { return }

        state = .connecting
        // Simulate network delay (0.5s)
        try await Task.sleep(nanoseconds: 500_000_000)
        state = .connected

        // Send welcome banner via interactive channel
        let welcome = """
        \r\n
        Welcome to Cognis Mock Terminal [\(name)]
        Type 'help' for commands.
        Try typing 'diagnose' to trigger Silent Channel AI analysis.
        \r\n>
        """
        sendToStream(welcome)
    }

    func disconnect() async {
        state = .disconnected
        outputContinuation?.finish()
    }

    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

    // MARK: - Interactive Channel (PTY Simulation)

    func send(_ data: Data) async throws {
        guard state == .connected else { throw CognisError.sessionClosed }

        guard let input = String(data: data, encoding: .utf8) else { return }

        // Echo input (Simulate local echo)
        sendToStream(input)

        // Handle newline (Enter key)
        if input.contains("\r") || input.contains("\n") {
             sendToStream("\r\n") // New line

             // Simple command processor
             // Note: In real PTY, we just send bytes. Here we parse for demo.
             // We assume the last line is the command.
             // For simplicity in this mock, we just respond to specific triggers if they were typed cleanly.

             if input.trimmingCharacters(in: .whitespacesAndNewlines).contains("help") {
                 sendToStream("Available commands: help, clear, date, diagnose\r\n> ")
             } else if input.trimmingCharacters(in: .whitespacesAndNewlines).contains("date") {
                 sendToStream("\(Date())\r\n> ")
             } else if input.trimmingCharacters(in: .whitespacesAndNewlines).contains("diagnose") {
                 sendToStream("Running system diagnosis... (See Inspector)\r\n> ")
                 Task {
                     let result = try? await executeSilentCommand("diagnose")
                     await MainActor.run {
                         self.lastAnalysis = result
                     }
                 }
             } else {
                 sendToStream("> ")
             }
        }
    }

    func receive() -> AsyncStream<Data> {
        AsyncStream { continuation in
            self.outputContinuation = continuation
        }
    }

    func resize(width: Int, height: Int) async throws {
        // Mock resize
        print("Resized to \(width)x\(height)")
    }

    private func sendToStream(_ text: String) {
        if let data = text.data(using: .utf8) {
            outputContinuation?.yield(data)
        }
    }

    // MARK: - Silent Channel (Dual-Track AI Simulation)

    var isSilentChannelAvailable: Bool { return true }

    func createSilentChannel() async throws {
        // Mock always available
    }

    func closeSilentChannel() async {
        // No-op
    }

    func executeSilentCommand(_ command: String) async throws -> String {
        // Simulate AI Diagnostics running in background
        // Does NOT affect the Interactive Channel

        // Simulate processing time
        try await Task.sleep(nanoseconds: 800_000_000)

        // Return simulated JSON result
        return """
        {
          "command": "\(command)",
          "status": "success",
          "timestamp": "\(Date().ISO8601Format())",
          "analysis": "Silent channel execution successful. No anomalies detected."
        }
        """
    }
}
