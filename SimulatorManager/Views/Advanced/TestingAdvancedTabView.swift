import MapKit
import SwiftUI

struct TestingAdvancedTabView: View {
    @ObservedObject var presenter: SimulatorPresenter
    var includeAppScopedControls: Bool = true
    var includeSimulatorScopedControls: Bool = true
    @State private var privacyGrantState: [PrivacyService: Bool] = [:]
    @State private var isNotificationComposerPresented = false
    @State private var composerPayloadJSON = ""
    @State private var composerSelectedPresetID: UUID?
    @State private var composerSelectedOptions: Set<NotificationPayloadOption> = []
    @State private var composerOptionSelectedValues: [NotificationPayloadOption: String] = [:]
    @State private var composerErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                capturePushSection
                if includeSimulatorScopedControls {
                    locationSection
                    appearanceSection
                    deepLinkSection
                    simulatorSystemSection
                }
                if includeAppScopedControls {
                    privacySection
                }
                if includeSimulatorScopedControls {
                    overridesSection
                    statusBarSection
                    clipboardSection
                }
            }
            .padding(.vertical, 20)
        }
        .font(.system(size: 13))
    }

    // MARK: - Capture & Push

    private var capturePushSection: some View {
        SectionCard(title: captureSectionTitle, icon: "camera.fill", iconColor: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if includeSimulatorScopedControls {
                        ActionButton(label: "Screenshot", icon: "camera.fill", style: .secondary) {
                            Task { await presenter.takeScreenshot() }
                        }
                        ActionButton(label: "Record Video", icon: "video.fill", style: .secondary) {
                            Task { await presenter.toggleVideoRecording() }
                        }
                    }
                }

                if includeAppScopedControls {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Notification Presets", systemImage: "bell.badge")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                            ForEach(presenter.notificationPayloadPresets) { preset in
                                Button {
                                    openNotificationComposer(with: preset)
                                } label: {
                                    NotificationPresetTileView(
                                        title: preset.name,
                                        subtitle: notificationPresetSubtitle(from: preset.payloadJSON),
                                        symbol: "bell.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete") {
                                        presenter.deleteNotificationPayloadPreset(id: preset.id)
                                    }
                                }
                            }

                            Button {
                                openNotificationComposer(with: nil)
                            } label: {
                                NotificationPresetTileView(
                                    title: "New Notification",
                                    subtitle: "Create custom payload",
                                    symbol: "plus"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isNotificationComposerPresented) {
            notificationComposerSheet
        }
    }

    private var notificationComposerSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Notification Payload")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if let selectedID = composerSelectedPresetID,
                       let preset = presenter.notificationPayloadPresets.first(where: { $0.id == selectedID }) {
                        Text(preset.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
                    } else {
                        Text("New")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Options")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(NotificationPayloadOption.allCases) { option in
                            Button {
                                setComposerPayloadOption(option, enabled: !composerSelectedOptions.contains(option))
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: composerSelectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12))
                                    Text(option.title)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(composerSelectedOptions.contains(option) ? Color(nsColor: .controlAccentColor).opacity(0.14) : Color(nsColor: .windowBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            composerSelectedOptions.contains(option)
                                            ? Color(nsColor: .controlAccentColor).opacity(0.5)
                                            : Color(nsColor: .separatorColor).opacity(0.35),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !selectedConfigurableComposerOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Option Values")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(selectedConfigurableComposerOptions, id: \.self) { option in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(option.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Picker(option.title, selection: composerOptionValueBinding(for: option)) {
                                            ForEach(option.selectableValues) { choice in
                                                Text(choice.title).tag(choice.rawValue)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Format JSON") {
                        formatComposerPayloadJSON()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                TextEditor(text: $composerPayloadJSON)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(minHeight: 220)
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

                if let composerErrorMessage {
                    Text(composerErrorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 8) {
                    Button("Cancel") {
                        isNotificationComposerPresented = false
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        saveComposerPreset()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Send") {
                        Task {
                            composerErrorMessage = nil
                            presenter.pushPayloadJSON = composerPayloadJSON
                            await presenter.sendPushPayload()
                            if presenter.errorMessage == nil {
                                isNotificationComposerPresented = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 620, minHeight: 420)
    }

    private var captureSectionTitle: String {
        if includeAppScopedControls && includeSimulatorScopedControls {
            return "Capture & Push"
        }
        if includeAppScopedControls {
            return "Push Notifications"
        }
        return "Capture"
    }

    // MARK: - Location

    private var locationSection: some View {
        SectionCard(title: "Location", icon: "location.fill", iconColor: .green) {
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
        SectionCard(title: "Appearance", icon: "circle.lefthalf.filled", iconColor: .purple) {
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
        SectionCard(title: "Deep Link", icon: "link", iconColor: .orange) {
            VStack(alignment: .leading, spacing: 8) {
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

    // MARK: - Simulator System

    private var simulatorSystemSection: some View {
        SectionCard(title: "Simulator System", icon: "gearshape.fill", iconColor: .teal) {
            HStack(spacing: 8) {
                ActionButton(label: "Trigger iCloud Sync", icon: "icloud.and.arrow.down.fill", style: .secondary) {
                    Task { await presenter.triggeriCloudSync() }
                }
                ActionButton(label: "Reset Keychain", icon: "key.fill", style: .secondary) {
                    Task { await presenter.resetKeychain() }
                }
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        SectionCard(title: "Privacy Permissions", icon: "hand.raised.fill", iconColor: .red) {
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

    // MARK: - Overrides

    private var overridesSection: some View {
        SectionCard(title: "Overrides", icon: "switch.2", iconColor: .yellow) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SubsectionTitle(title: "Display")
                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Content Size")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $presenter.contentSizeCategory) {
                                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: 280, alignment: .leading)

                        ActionButton(label: "Apply", icon: nil, style: .secondary) {
                            Task { await presenter.setContentSize(presenter.contentSizeCategory) }
                        }
                    }
                }

                Divider()
                    .overlay(Color(nsColor: .separatorColor).opacity(0.3))

                VStack(alignment: .leading, spacing: 8) {
                    SubsectionTitle(title: "Localization")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Language")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $presenter.languageCode) {
                            ForEach(languageOptions, id: \.code) { option in
                                Text(option.name).tag(option.code)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Locale")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $presenter.localeIdentifier) {
                            ForEach(localeOptions, id: \.identifier) { option in
                                Text(option.name).tag(option.identifier)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ActionButton(label: "Set Language/Locale", icon: nil, style: .secondary) {
                        Task { await presenter.applyLanguageLocale() }
                    }
                }
                .onChange(of: presenter.languageCode) { _, newValue in
                    if !localeOptions.contains(where: { $0.identifier == presenter.localeIdentifier }),
                       let first = localeEntries(for: newValue).first {
                        presenter.localeIdentifier = first.identifier
                    }
                }

                Divider()
                    .overlay(Color(nsColor: .separatorColor).opacity(0.3))

                VStack(alignment: .leading, spacing: 8) {
                    SubsectionTitle(title: "Accessibility")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                        ForEach(accessibilityRows, id: \.key) { row in
                            Toggle(row.title, isOn: accessibilityBinding(for: row.key))
                                .toggleStyle(.switch)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBarSection: some View {
        SectionCard(title: "Status Bar", icon: "clock.fill", iconColor: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    LabeledField(label: "Time", symbol: "clock", text: $presenter.statusBarTime, placeholder: "9:41")
                        .frame(maxWidth: 130)
                    LabeledField(label: "Carrier", symbol: "antenna.radiowaves.left.and.right", text: $presenter.statusBarOperator, placeholder: "Carrier")
//                    ActionButton(label: "Set 9:41", icon: nil, style: .secondary) {
//                        presenter.setAppleStatusBarTime()
//                    }.padding()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("Network")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $presenter.statusBarDataNetwork) {
                            ForEach(StatusBarDataNetwork.allCases, id: \.self) { network in
                                Text(dataNetworkDisplayName(network)).tag(network)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
//                        .frame(maxWidth: 180)
                    }

                    HStack(alignment: .center, spacing: 4) {
                        Text("Wi-Fi Mode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $presenter.statusBarWiFiMode) {
                            ForEach(StatusBarWiFiMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue.capitalized).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
//                        .frame(maxWidth: 180)
                    }

                    HStack(alignment: .center, spacing: 4) {
                        Text("Cellular Mode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $presenter.statusBarCellularMode) {
                            ForEach(StatusBarCellularMode.allCases, id: \.self) { mode in
                                Text(cellularModeDisplayName(mode)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
//                        .frame(maxWidth: 180)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("Wi-Fi Bars")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: wifiBarsBinding) {
                            ForEach(0...3, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    HStack(alignment: .center, spacing: 4) {
                        Text("Cellular Bars")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: cellularBarsBinding) {
                            ForEach(0...4, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("Battery State")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $presenter.statusBarBatteryState) {
                            ForEach(StatusBarBatteryState.allCases, id: \.self) { state in
                                Text(state.rawValue.capitalized).tag(state)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: 180)

                    HStack(alignment: .center, spacing: 4) {
                        Text("Battery \(batteryLevelBinding.wrappedValue)%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Slider(value: batterySliderBinding, in: 0...100, step: 1)
                    }
                }

                HStack(spacing: 6) {
                    ActionButton(label: "Override", icon: nil, style: .primary) {
                        Task { await presenter.applyStatusBarOverride() }
                    }
                    ActionButton(label: "Clear", icon: nil, style: .secondary) {
                        Task { await presenter.clearStatusBar() }
                    }
                }.padding(.vertical)
            }
        }
    }

    // MARK: - Clipboard

    private var clipboardSection: some View {
        SectionCard(title: "Clipboard", icon: "doc.on.clipboard.fill", iconColor: .gray) {
            VStack(alignment: .leading, spacing: 8) {
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

    private func openNotificationComposer(with preset: NotificationPayloadPreset?) {
        composerErrorMessage = nil
        if let preset {
            composerSelectedPresetID = preset.id
            composerPayloadJSON = preset.payloadJSON
        } else {
            composerSelectedPresetID = nil
            composerPayloadJSON = presenter.pushPayloadJSON
        }
        composerSelectedOptions = currentPayloadOptions(from: composerPayloadJSON)
        composerOptionSelectedValues = currentPayloadOptionSelectedValues(from: composerPayloadJSON)
        isNotificationComposerPresented = true
    }

    private func saveComposerPreset() {
        presenter.pushPayloadJSON = composerPayloadJSON
        if let selectedID = composerSelectedPresetID {
            presenter.selectNotificationPayloadPreset(selectedID)
            presenter.pushPayloadJSON = composerPayloadJSON
            presenter.updateSelectedNotificationPayloadPreset()
        } else {
            presenter.createNotificationPayloadPreset()
            composerSelectedPresetID = presenter.selectedNotificationPayloadPresetID
        }
    }

    private func setComposerPayloadOption(_ option: NotificationPayloadOption, enabled: Bool) {
        guard let data = composerPayloadJSON.data(using: .utf8),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            composerErrorMessage = "Invalid payload JSON."
            return
        }
        var aps = object["aps"] as? [String: Any] ?? [:]
        if enabled {
            let selectedRawValue = composerOptionSelectedValues[option] ?? option.defaultSelectableRawValue
            aps[option.payloadKey] = option.payloadValue(for: selectedRawValue)
            composerSelectedOptions.insert(option)
            if let selectedRawValue {
                composerOptionSelectedValues[option] = selectedRawValue
            }
        } else {
            aps.removeValue(forKey: option.payloadKey)
            composerSelectedOptions.remove(option)
            composerOptionSelectedValues.removeValue(forKey: option)
        }
        object["aps"] = aps
        guard let formattedData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let formattedText = String(data: formattedData, encoding: .utf8) else {
            composerErrorMessage = "Unable to update payload options."
            return
        }
        composerPayloadJSON = formattedText
        composerErrorMessage = nil
    }

    private func setComposerPayloadOptionSelectedValue(_ option: NotificationPayloadOption, rawValue: String) {
        composerOptionSelectedValues[option] = rawValue
        guard composerSelectedOptions.contains(option) else {
            return
        }
        guard let data = composerPayloadJSON.data(using: .utf8),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            composerErrorMessage = "Invalid payload JSON."
            return
        }
        var aps = object["aps"] as? [String: Any] ?? [:]
        aps[option.payloadKey] = option.payloadValue(for: rawValue)
        object["aps"] = aps
        guard let formattedData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let formattedText = String(data: formattedData, encoding: .utf8) else {
            composerErrorMessage = "Unable to update option value."
            return
        }
        composerPayloadJSON = formattedText
        composerErrorMessage = nil
    }

    private func formatComposerPayloadJSON() {
        guard let data = composerPayloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: formatted, encoding: .utf8) else {
            composerErrorMessage = "Invalid payload JSON."
            return
        }
        composerPayloadJSON = text
        composerSelectedOptions = currentPayloadOptions(from: text)
        composerOptionSelectedValues = currentPayloadOptionSelectedValues(from: text)
        composerErrorMessage = nil
    }

    private func currentPayloadOptions(from payloadJSON: String) -> Set<NotificationPayloadOption> {
        guard let data = payloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let aps = object["aps"] as? [String: Any] else {
            return []
        }
        var options: Set<NotificationPayloadOption> = []
        for option in NotificationPayloadOption.allCases {
            if aps[option.payloadKey] != nil {
                options.insert(option)
            }
        }
        return options
    }

    private func currentPayloadOptionSelectedValues(from payloadJSON: String) -> [NotificationPayloadOption: String] {
        guard let data = payloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let aps = object["aps"] as? [String: Any] else {
            return [:]
        }
        var selectedValues: [NotificationPayloadOption: String] = [:]
        for option in NotificationPayloadOption.allCases where !option.selectableValues.isEmpty {
            guard let payloadValue = aps[option.payloadKey] else {
                continue
            }
            if let matchedValue = option.selectedRawValue(from: payloadValue) {
                selectedValues[option] = matchedValue
            } else if let defaultValue = option.defaultSelectableRawValue {
                selectedValues[option] = defaultValue
            }
        }
        return selectedValues
    }

    private var selectedConfigurableComposerOptions: [NotificationPayloadOption] {
        composerSelectedOptions
            .filter { !$0.selectableValues.isEmpty }
            .sorted { $0.title < $1.title }
    }

    private func composerOptionValueBinding(for option: NotificationPayloadOption) -> Binding<String> {
        Binding(
            get: { composerOptionSelectedValues[option] ?? option.defaultSelectableRawValue ?? "" },
            set: { newValue in
                setComposerPayloadOptionSelectedValue(option, rawValue: newValue)
            }
        )
    }

    private func notificationPresetSubtitle(from payloadJSON: String) -> String {
        guard let data = payloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let aps = object["aps"] as? [String: Any] else {
            return "Custom payload"
        }
        if let alert = aps["alert"] as? String, !alert.isEmpty {
            return alert
        }
        if let alertObject = aps["alert"] as? [String: Any], let body = alertObject["body"] as? String, !body.isEmpty {
            return body
        }
        return "Ready to send"
    }

    private func pasteFromClipboard() async {
        await presenter.pasteTextFromSimulatorClipboard()
        presenter.clipboardText = presenter.pastedClipboardText
    }

    private var wifiBarsBinding: Binding<Int> {
        Binding(
            get: { Int(presenter.statusBarWiFiBars) ?? 3 },
            set: { presenter.statusBarWiFiBars = "\($0)" }
        )
    }

    private var cellularBarsBinding: Binding<Int> {
        Binding(
            get: { Int(presenter.statusBarCellularBars) ?? 4 },
            set: { presenter.statusBarCellularBars = "\($0)" }
        )
    }

    private var batterySliderBinding: Binding<Double> {
        Binding(
            get: { Double(Int(presenter.statusBarBattery) ?? 100) },
            set: { presenter.statusBarBattery = "\(Int($0.rounded()))" }
        )
    }

    private var batteryLevelBinding: Binding<Int> {
        Binding(
            get: { Int(presenter.statusBarBattery) ?? 100 },
            set: { presenter.statusBarBattery = "\($0)" }
        )
    }

    private var languageOptions: [(code: String, name: String)] {
        NSLocale.isoLanguageCodes
            .compactMap { code in
                let name = Locale.current.localizedString(forLanguageCode: code)
                guard let name else { return nil }
                return (code: code, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var localeOptions: [(identifier: String, name: String)] {
        localeEntries(for: presenter.languageCode)
    }

    private var accessibilityRows: [(key: AccessibilityOverride, title: String)] {
        [
            (.enhanceTextLegibility, "Bold Text"),
            (.showButtonShapes, "Button Shapes"),
            (.showOnOffLabels, "On/Off Labels"),
            (.reduceTransparency, "Reduce Transparency"),
            (.increaseContrast, "Increase Contrast"),
            (.differentiateWithoutColor, "Differentiate Without Color"),
            (.smartInvert, "Smart Invert"),
            (.reduceMotion, "Reduce Motion"),
            (.preferCrossFadeTransitions, "Prefer Cross-Fade Transitions")
        ]
    }

    private func localeEntries(for languageCode: String) -> [(identifier: String, name: String)] {
        Locale.availableIdentifiers
            .filter { $0.hasPrefix(languageCode) }
            .compactMap { identifier in
                let name = Locale.current.localizedString(forIdentifier: identifier)
                guard let name else { return nil }
                return (identifier: identifier, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func accessibilityBinding(for key: AccessibilityOverride) -> Binding<Bool> {
        Binding(
            get: { presenter.accessibilityOverrideStates[key] ?? false },
            set: { newValue in
                presenter.accessibilityOverrideStates[key] = newValue
                Task { await presenter.setAccessibilityOverride(key, enabled: newValue) }
            }
        )
    }

    private func dataNetworkDisplayName(_ network: StatusBarDataNetwork) -> String {
        switch network {
        case .wifi: return "Wi-Fi"
        default: return network.rawValue.uppercased()
        }
    }

    private func cellularModeDisplayName(_ mode: StatusBarCellularMode) -> String {
        switch mode {
        case .notSupported: return "Not Supported"
        default: return mode.rawValue.capitalized
        }
    }
}

// MARK: - SectionCard

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
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

private struct NotificationPresetTileView: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: .controlAccentColor))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
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

private struct SubsectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
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
            .frame(minWidth: 60)
        }
//        .buttonStyle(style == .primary ? .borderedProminent : .bordered)
        .controlSize(.small)
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

            ZStack(alignment: isGrant ? .trailing : .leading) {
                Capsule()
                    .fill(isGrant ? Color.green : Color(nsColor: .separatorColor).opacity(0.5))
                    .frame(width: 42, height: 24)
                    .animation(.easeInOut(duration: 0.2), value: isGrant)

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
