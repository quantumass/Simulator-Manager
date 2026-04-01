import SwiftUI

struct AppAdvancedTabView: View {
    @ObservedObject var presenter: SimulatorPresenter
    let app: IndexedApp
    @Binding var isActionRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            lifecycleSection
        }
        .padding(.vertical, 20)
        .font(.system(size: 13))
    }

    // MARK: - Lifecycle

    private var lifecycleSection: some View {
        SectionCard(title: "App Lifecycle", icon: "bolt.fill") {
            HStack(spacing: 8) {
                LifecycleButton(title: "Launch", icon: "play.fill", tint: .blue) {
                    await runAction { await presenter.launch(app) }
                }
                LifecycleButton(title: "Terminate", icon: "stop.fill", tint: .orange) {
                    await runAction { await presenter.terminateSelectedApp() }
                }
                LifecycleButton(title: "Uninstall", icon: "trash.fill", tint: .red) {
                    await runAction { await presenter.uninstallSelectedApp() }
                }
                LifecycleButton(title: "Reinstall", icon: "arrow.triangle.2.circlepath", tint: .green) {
                    await runAction { await presenter.reinstallSelectedApp() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func runAction(_ operation: @escaping () async -> Void) async {
        isActionRunning = true
        await operation()
        isActionRunning = false
    }
}

// MARK: - LifecycleButton

private struct LifecycleButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () async -> Void
    @State private var isHovering = false

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovering ? tint : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(isHovering ? 0.18 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovering ? tint.opacity(0.3) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.02 : 1)
        .shadow(color: isHovering ? tint.opacity(0.2) : .clear, radius: 6, y: 2)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - InfoBadge

private struct InfoBadge: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1))
    }
}

// MARK: - SectionCard

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
                .overlay(Color(nsColor: .separatorColor).opacity(0.4))

            content()
                .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}
