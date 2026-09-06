import SwiftUI

struct DataAdvancedTabView: View {
    @ObservedObject var presenter: SimulatorPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            containerSection
            fileSection
            mediaInfoSection
        }
        .padding(.vertical, 20)
    }

    // MARK: - Container Access

    private var containerSection: some View {
        SectionCard(title: "Container Access", icon: "shippingbox.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select which app container to open in Finder.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Picker("", selection: $presenter.containerKind) {
                            ForEach(AppContainerKind.allCases, id: \.self) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                    .frame(maxWidth: 200, alignment: .leading)
                    Spacer()
                    Button(action: { Task { await presenter.openContainer(kind: presenter.containerKind) } }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 11))
                            Text("Open Container")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - File Access

    private var fileSection: some View {
        SectionCard(title: "App File Access", icon: "doc.fill") {
            VStack(alignment: .leading, spacing: 14) {
                // Push File
                VStack(alignment: .leading, spacing: 6) {
                    Text("Push File")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: "doc.badge.arrow.up")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            TextField("Remote destination path", text: $presenter.remotePushPath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                        )

                        Button(action: { Task { await presenter.pushFileIntoApp() } }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 11))
                                Text("Push File")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var mediaInfoSection: some View {
        SectionCard(title: "Media Library", icon: "photo.on.rectangle.angled") {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Media import is simulator-level.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Use \"Add To Photos\" in the simulator quick actions (next to \"Data Folder\") to add photos and videos.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - SectionCard (local copy if not shared)

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
