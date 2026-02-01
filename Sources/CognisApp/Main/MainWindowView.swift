//
//  MainWindowView.swift
//  CognisApp
//
//  主窗口视图：三栏布局实现
//

import SwiftUI
import CognisCore
import SwiftTerm // Ensure SwiftTerm is imported for types if needed, though SwiftTermView handles it

struct MainWindowView: View {
    // Demo Sessions
    // Using 'any TerminalSession' to support mixed session types
    @State private var sessions: [any TerminalSession] = [
        LocalTerminalSession(name: "Local Zsh"),
        MockSession(name: "Remote Server (Mock)"),
        MockSession(name: "Database Cluster")
    ]
    @State private var selectedSessionId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectorVisible: Bool = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // COLUMN 1: Sidebar
            SidebarView(sessions: sessions, selection: $selectedSessionId)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
                .background(Theme.Materials.sidebar)
        } detail: {
            // COLUMN 2: Terminal Content
            if let session = selectedSession(id: selectedSessionId) {
                // Use SwiftTermView for all sessions
                SwiftTermView(session: session)
                    .background(Theme.Colors.terminalBackground)
                    .focusable()
                    .onAppear {
                        // Force focus to terminal when it appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    }
            } else {
                ContentUnavailableView("Select a Session", systemImage: "terminal")
            }
        }
        .inspector(isPresented: $inspectorVisible) {
            // COLUMN 3: Inspector / AI Assistant
            if let session = selectedSession(id: selectedSessionId) {
                // Check if session supports DualTrack
                if let dualTrackSession = session as? (any DualTrackSession) {
                    AIInspectorView(session: dualTrackSession)
                        .inspectorColumnWidth(min: 250, ideal: 300)
                        .background(Theme.Materials.content)
                } else {
                    ContentUnavailableView("AI Not Available", systemImage: "bolt.slash")
                }
            } else {
                ContentUnavailableView("No Session", systemImage: "cpu")
            }
        }
    }

    private func selectedSession(id: UUID?) -> (any TerminalSession)? {
        guard let id = id else { return nil }
        return sessions.first(where: { $0.id == id })
    }
}

// MARK: - Subviews

struct SidebarView: View {
    let sessions: [any TerminalSession]
    @Binding var selection: UUID?

    var body: some View {
        List(sessions, id: \.id, selection: $selection) { session in
            NavigationLink(value: session.id) {
                Label(session.name, systemImage: "desktopcomputer")
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle("Sessions")
    }
}

// Replaced MockTerminalView with SwiftTermView (in separate file)

struct AIInspectorView: View {
    let session: any DualTrackSession
    @State private var analysisResult: String?
    @State private var isAnalyzing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("AI Diagnostics")
                .font(Theme.Fonts.header)

            Divider()

            if isAnalyzing {
                ProgressView("Analyzing system via Silent Channel...")
                    .controlSize(.small)
            } else if let result = analysisResult {
                ScrollView {
                    Text(result)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Theme.Colors.secondaryBackground)
                        .cornerRadius(Theme.Radius.small)
                        .textSelection(.enabled)
                }
            } else {
                Text("System Normal. No active alerts.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Spacer()

            Button(action: runAnalysis) {
                Label("Run Deep Scan", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAnalyzing)
        }
        .padding()
        // Reset state when session changes
        .id(session.id)
    }

    private func runAnalysis() {
        isAnalyzing = true
        analysisResult = nil // Clear previous

        Task {
            // Call the Silent Channel API (Dual-Track)
            // For Local Session: Executes separate process
            // For Mock Session: Returns mock JSON
            do {
                let result = try await session.executeSilentCommand("uptime && echo '---' && ls -lh | head -n 5")
                await MainActor.run {
                    self.analysisResult = result
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.analysisResult = "Error: \(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }
}
