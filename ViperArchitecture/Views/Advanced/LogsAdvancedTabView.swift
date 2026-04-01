import SwiftUI

struct LogsAdvancedTabView: View {
    @ObservedObject var presenter: SimulatorPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toolbar
            HStack(spacing: 8) {
                // Start / Stop
                Button(action: {
                    Task {
                        if presenter.isStreamingLogs {
                            await presenter.stopLogs()
                        } else {
                            await presenter.startLogs()
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: presenter.isStreamingLogs ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 13))
                        Text(presenter.isStreamingLogs ? "Stop" : "Start Logs")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(presenter.isStreamingLogs ? .red : .accentColor)

                Button(action: { Task { await presenter.exportLogs() } }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("Export")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Spacer()

                // Live indicator
                if presenter.isStreamingLogs {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .opacity(1)
                            .modifier(PulsingModifier())
                        Text("Live")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }

                // Filter field
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Filter logs...", text: $presenter.logSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minWidth: 180)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                )
            }

            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        let lines = presenter.filteredLogLines.suffix(140)
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            LogLineRow(line: line)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
                .onChange(of: presenter.filteredLogLines.count) { count in
                    withAnimation {
                        proxy.scrollTo(min(count, 140) - 1, anchor: .bottom)
                    }
                }
            }

            // Footer
            HStack {
                Text("\(presenter.filteredLogLines.count) lines")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !presenter.logSearchQuery.isEmpty {
                    Text("\(presenter.filteredLogLines.count) match(es) for \(presenter.logSearchQuery)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Log Line Row

private struct LogLineRow: View {
    let line: String

    var level: LogLevel {
        let l = line.lowercased()
        if l.contains("error") || l.contains("fault") { return .error }
        if l.contains("warning") || l.contains("warn") { return .warning }
        if l.contains("debug") { return .debug }
        return .info
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            RoundedRectangle(cornerRadius: 1.5)
                .fill(level.color)
                .frame(maxWidth: 3, maxHeight: .infinity)
                .opacity(level == .info ? 0 : 1)

            Text(line)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(level.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

private enum LogLevel {
    case info, debug, warning, error

    var color: Color {
        switch self {
        case .info:    return .clear
        case .debug:   return .blue
        case .warning: return .orange
        case .error:   return .red
        }
    }

    var textColor: Color {
        switch self {
        case .info:    return Color(nsColor: .labelColor)
        case .debug:   return .blue
        case .warning: return .orange
        case .error:   return .red
        }
    }
}

// MARK: - Pulsing animation for live indicator

private struct PulsingModifier: ViewModifier {
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.2
                }
            }
            .opacity(opacity)
    }
}
