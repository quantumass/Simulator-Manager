import MapKit
import SwiftUI

struct TestingAdvancedTabView: View {
    @ObservedObject var presenter: SimulatorPresenter
    @State private var privacyGrantState: [PrivacyService: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                capturePushSection
                locationSection
                appearanceSection
                deepLinkSection
                privacySection
                statusBarSection
                clipboardSection
            }
            .padding(.vertical, 20)
        }
        .font(.system(size: 13))
    }

    // MARK: - Capture & Push

    private var capturePushSection: some View {
        SectionCard(title: "Capture & Push", icon: "camera.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ActionButton(label: "Screenshot", icon: "camera.fill", style: .secondary) {
                        Task { await presenter.takeScreenshot() }
                    }
                    ActionButton(label: "Record Video", icon: "video.fill", style: .secondary) {
                        Task { await presenter.toggleVideoRecording() }
                    }
                    ActionButton(label: "Send Push", icon: "bell.badge.fill", style: .primary) {
                        Task { await presenter.sendPushPayload() }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Payload JSON", systemImage: "curlybraces")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Format JSON") {
                            formatPushPayloadJSON()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    TextEditor(text: $presenter.pushPayloadJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(minHeight: 90)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        SectionCard(title: "Location", icon: "location.fill") {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    LabeledField(label: "Latitude", symbol: "mappin", text: $presenter.locationLatitude, placeholder: "48.8566")
                    LabeledField(label: "Longitude", symbol: "mappin", text: $presenter.locationLongitude, placeholder: "2.3522")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(" ").font(.system(size: 11)) // spacer for label alignment
                        HStack(spacing: 6) {
                            ActionButton(label: "Set", icon: nil, style: .primary) {
                                Task { await presenter.setCustomLocation() }
                            }
                            ActionButton(label: "GPX", icon: nil, style: .secondary) {
                                Task { await presenter.runGPXLocation() }
                            }
                        }
                    }
                }

                mapPreview
            }
        }
    }

    private var mapPreview: some View {
        let latitude = Double(presenter.locationLatitude)
        let longitude = Double(presenter.locationLongitude)
        return StaticCoordinateMapView(latitude: latitude, longitude: longitude)
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SectionCard(title: "Appearance", icon: "circle.lefthalf.filled") {
            HStack(spacing: 0) {
                AppearanceChip(label: "☀️  Light", isSelected: presenter.selectedAppearance == .light) {
                    presenter.selectedAppearance = .light
                    Task { await presenter.setAppearance(.light) }
                }
                AppearanceChip(label: "🌙  Dark", isSelected: presenter.selectedAppearance == .dark) {
                    presenter.selectedAppearance = .dark
                    Task { await presenter.setAppearance(.dark) }
                }
            }
            .padding(3)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            )
            .fixedSize()
        }
    }

    // MARK: - Deep Link

    private var deepLinkSection: some View {
        SectionCard(title: "Deep Link", icon: "link") {
            VStack(alignment: .leading, spacing: 6) {
                Text("URL scheme or universal link")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    IconPrefixedTextField(
                        text: $presenter.deepLink,
                        placeholder: "myapp://home or https://example.com/path",
                        symbol: "link"
                    )
                    ActionButton(label: "Open Link", icon: "arrow.up.right", style: .primary) {
                        Task { await presenter.openDeepLink() }
                    }
                }
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        SectionCard(title: "Privacy Permissions", icon: "hand.raised.fill") {
            VStack(spacing: 0) {
                ForEach(Array(privacyPermissions.enumerated()), id: \.element.id) { index, permission in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(permission.tint.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: permission.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(permission.tint)
                        }

                        Text(permission.title)
                            .font(.system(size: 13))

                        Spacer()

                        GrantRevokeToggle(
                            isGrant: Binding(
                                get: { privacyGrantState[permission.service] ?? true },
                                set: { newValue in
                                    privacyGrantState[permission.service] = newValue
                                    Task { await applyPrivacy(permission.service, grant: newValue) }
                                }
                            )
                        )
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)

                    if index < privacyPermissions.count - 1 {
                        Divider()
                            .overlay(Color(nsColor: .separatorColor).opacity(0.3))
                    }
                }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBarSection: some View {
        SectionCard(title: "Status Bar", icon: "clock.fill") {
            HStack(alignment: .bottom, spacing: 8) {
                LabeledField(label: "Time", symbol: "clock", text: $presenter.statusBarTime, placeholder: "9:41")
                    .frame(maxWidth: 120)
                LabeledField(label: "Battery %", symbol: "battery.100", text: $presenter.statusBarBattery, placeholder: "100")
                    .frame(maxWidth: 120)

                Spacer()

                HStack(spacing: 6) {
                    ActionButton(label: "Override", icon: nil, style: .primary) {
                        Task { await presenter.applyStatusBarOverride() }
                    }
                    ActionButton(label: "Clear", icon: nil, style: .secondary) {
                        Task { await presenter.clearStatusBar() }
                    }
                }
                .padding(.bottom, 1)
            }
        }
    }

    // MARK: - Clipboard

    private var clipboardSection: some View {
        SectionCard(title: "Clipboard", icon: "doc.on.clipboard.fill") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Clipboard content")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    IconPrefixedTextField(
                        text: $presenter.clipboardText,
                        placeholder: "Paste or type content...",
                        symbol: "doc.on.doc"
                    )
                    ActionButton(label: "Copy", icon: "doc.on.doc", style: .secondary) {
                        Task { await presenter.copyTextToSimulatorClipboard() }
                    }
                    ActionButton(label: "Paste", icon: "clipboard", style: .secondary) {
                        Task { await pasteFromClipboard() }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var privacyPermissions: [PrivacyPermission] {
        [
            PrivacyPermission(title: "Camera", symbol: "camera.fill", tint: .blue, service: .camera),
            PrivacyPermission(title: "Microphone", symbol: "mic.fill", tint: .orange, service: .microphone),
            PrivacyPermission(title: "Location", symbol: "location.fill", tint: .purple, service: .location),
            PrivacyPermission(title: "Photos", symbol: "photo.fill", tint: .teal, service: .photos),
            PrivacyPermission(title: "Contacts", symbol: "person.crop.circle.fill", tint: .mint, service: .contacts),
            PrivacyPermission(title: "Calendar", symbol: "calendar", tint: .pink, service: .calendar),
            PrivacyPermission(title: "Notifications", symbol: "bell.badge.fill", tint: .indigo, service: .notifications),
        ]
    }

    private func applyPrivacy(_ service: PrivacyService, grant: Bool) async {
        presenter.selectedPrivacyService = service
        await presenter.setPrivacy(grant: grant)
    }

    private func formatPushPayloadJSON() {
        guard let data = presenter.pushPayloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let text = String(data: formatted, encoding: .utf8)
        else { return }
        presenter.pushPayloadJSON = text
    }

    private func pasteFromClipboard() async {
        await presenter.pasteTextFromSimulatorClipboard()
        presenter.clipboardText = presenter.pastedClipboardText
    }
}

// MARK: - SectionCard

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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

// MARK: - LabeledField

private struct LabeledField: View {
    let label: String
    let symbol: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            IconPrefixedTextField(text: $text, placeholder: placeholder, symbol: symbol)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - IconPrefixedTextField

private struct IconPrefixedTextField: View {
    @Binding var text: String
    let placeholder: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField(placeholder, text: $text)
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
    }
}

// MARK: - ActionButton

private enum ActionButtonStyle { case primary, secondary }

private struct ActionButton: View {
    let label: String
    let icon: String?
    let style: ActionButtonStyle
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 60)
        }
//        .buttonStyle(style == .primary ? AnyButtonStyle(.borderedProminent) : AnyButtonStyle(.bordered))
    }
}

// Helper to erase button style type
private struct AnyButtonStyle: ButtonStyle {
    private let base: any ButtonStyle
    init(_ style: some ButtonStyle) { base = style }
    func makeBody(configuration: Configuration) -> some View {
        AnyView(base.makeBody(configuration: configuration))
    }
}

// MARK: - AppearanceChip

private struct AppearanceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.18) : Color.clear)
                )
                .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GrantRevokeToggle
private struct GrantRevokeToggle: View {
    @Binding var isGrant: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(isGrant ? "Granted" : "Revoked")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isGrant ? Color.green : Color.secondary)
                .animation(.easeInOut(duration: 0.15), value: isGrant)
                .frame(width: 52, alignment: .trailing)

            // Toggle track
            ZStack(alignment: isGrant ? .trailing : .leading) {
                Capsule()
                    .fill(isGrant ? Color.green : Color(nsColor: .separatorColor).opacity(0.5))
                    .frame(width: 42, height: 24)
                    .animation(.easeInOut(duration: 0.2), value: isGrant)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .padding(3)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isGrant)
            }
            .onTapGesture {
                isGrant.toggle()
            }
        }
    }
}

// MARK: - Map

private struct StaticCoordinateMapView: NSViewRepresentable {
    let latitude: Double?
    let longitude: Double?

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        guard let latitude, let longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        mapView.setRegion(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ),
            animated: false
        )
    }
}

// MARK: - Model

private struct PrivacyPermission: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let tint: Color
    let service: PrivacyService
}
