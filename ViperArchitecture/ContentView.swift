import AppKit
import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var presenter: SimulatorPresenter
    @FocusState private var isSearchFocused: Bool
    @State private var advancedApp: IndexedApp?

    init() {
        _presenter = StateObject(wrappedValue: SimulatorModuleBuilder.build())
    }

    init(presenter: SimulatorPresenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    var body: some View {
        VStack(spacing: 0) {
            topSearchBar

            if presenter.isSimulatorSelected {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 272)
                        .background(Color(nsColor: .windowBackgroundColor))

                    Divider()

                    resultsArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .underPageBackgroundColor))
                }
            } else {
                simulatorDiscoveryArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .underPageBackgroundColor))
            }

            statusBar
        }
        .frame(minWidth: 920, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onMoveCommand { direction in
            switch direction {
            case .down: presenter.moveSelection(offset: 1)
            case .up:   presenter.moveSelection(offset: -1)
            default:    break
            }
        }
        .task { await presenter.loadDataIfNeeded() }
        .onChange(of: presenter.filteredApps) { _, updatedApps in
            guard let advancedApp else { return }
            if !updatedApps.contains(where: { $0.id == advancedApp.id }) {
                self.advancedApp = nil
            }
        }
        .animation(.easeInOut(duration: 0.18), value: presenter.filteredApps)
        .overlay(shortcutButtons)
        .alert(
            "Simulator Error",
            isPresented: Binding(
                get: { presenter.errorMessage != nil },
                set: { if !$0 { presenter.clearError() } }
            ),
            actions: { Button("OK") { presenter.clearError() } },
            message: { Text(presenter.errorMessage ?? "") }
        )
        .sheet(item: $advancedApp) { app in
            AppAdvancedPopup(
                presenter: presenter,
                app: app,
                onClose: { advancedApp = nil }
            )
        }
    }

    // MARK: - Top Search Bar

    private var topSearchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if presenter.isSimulatorSelected {
                    Button {
                        presenter.clearSelectedSimulator()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .help("Back to simulators")
                }

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)

                    TextField("Search simulator, app, bundle ID…", text: $presenter.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isSearchFocused)
                        .onSubmit { Task { await presenter.launchSelectedApp() } }

                    if !presenter.searchQuery.isEmpty {
                        Button {
                            presenter.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().frame(height: 16)

                    // Refresh
                    Button {
                        Task { await presenter.refresh(forceRescan: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(presenter.isLoadingSimulators || presenter.isScanningApps)
                    .help("Refresh simulators")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                )
            }

            // Filters row
            HStack(spacing: 6) {
                FilterPicker(label: "iOS Version", selection: $presenter.selectedOSVersionFilter, options: presenter.osVersionFilterOptions.map { (label: $0, value: $0) }, width: 0)
                FilterPicker(label: "Type", selection: $presenter.selectedDeviceTypeFilter, options: SimulatorDeviceTypeFilter.allCases.map { (label: $0.rawValue, value: $0) }, width: 0)
                FilterPicker(label: "Sort", selection: $presenter.selectedSortOption, options: SimulatorSortOption.allCases.map { (label: $0.rawValue, value: $0) }, width: 0)

                Spacer()

                if presenter.isScanningApps {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Scanning…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !presenter.favoriteSimulators.isEmpty {
                    simulatorSection(title: "Favorites", icon: "star.fill", tint: .yellow, simulators: presenter.favoriteSimulators)
                }
                simulatorSection(title: "All Simulators", icon: "cpu", tint: .secondary, simulators: presenter.nonFavoriteSimulators)
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func simulatorSection(title: String, icon: String, tint: Color, simulators: [SimulatorDevice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 6)

            VStack(spacing: 2) {
                ForEach(simulators) { simulator in
                    Button {
                        presenter.selectSimulator(simulator.id)
                    } label: {
                        SidebarSimulatorRow(
                            simulator: simulator,
                            selected: presenter.selectedSimulatorID == simulator.id,
                            favorite: presenter.favorites.contains(simulator.id),
                            multiSelected: presenter.selectedSimulatorIDs.contains(simulator.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(simulator.isBooted ? "Shutdown" : "Boot") {
                            Task {
                                if simulator.isBooted { await presenter.shutdown(simulator) }
                                else { await presenter.boot(simulator) }
                            }
                        }
                        Button("Open in Simulator") { Task { await presenter.openSimulator(simulator) } }
                        Button("Erase") { Task { await presenter.erase(simulator) } }
                        Divider()
                        Button(presenter.favorites.contains(simulator.id) ? "Remove Favorite" : "Add Favorite") {
                            presenter.toggleFavorite(simulatorID: simulator.id)
                        }
                        Button(presenter.selectedSimulatorIDs.contains(simulator.id) ? "Remove from Batch" : "Add to Batch") {
                            presenter.toggleMultiSelection(simulatorID: simulator.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Discovery Area

    @ViewBuilder
    private var simulatorDiscoveryArea: some View {
        if presenter.filteredSimulators.isEmpty {
            ContentUnavailableView(
                "No Simulators Found",
                systemImage: "desktopcomputer.and.iphone",
                description: Text("Try adjusting your search or filters.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(presenter.filteredSimulators) { simulator in
                        Button {
                            presenter.selectSimulator(simulator.id)
                        } label: {
                            SimulatorSelectionCard(simulator: simulator)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Results Area

    @ViewBuilder
    private var resultsArea: some View {
        if presenter.isScanningApps && presenter.allApps.isEmpty {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in AppCardSkeleton() }
                }
                .padding(16)
            }
        } else if presenter.filteredApps.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let selectedSimulator = presenter.selectedSimulator {
                        SimulatorQuickActionsBar(presenter: presenter, simulator: selectedSimulator)
                    }

                    ContentUnavailableView(
                        "No Apps Found",
                        systemImage: "magnifyingglass",
                        description: Text("Search by bundle ID, app name, or simulator UDID.")
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let selectedSimulator = presenter.selectedSimulator {
                        SimulatorQuickActionsBar(presenter: presenter, simulator: selectedSimulator)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 340), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(presenter.filteredApps) { app in
                            AppGridItem(
                                presenter: presenter,
                                app: app,
                                selectedSimulatorID: presenter.selectedSimulatorID,
                                onOpenAdvanced: {
                                    presenter.selectedAppID = app.id
                                    advancedApp = app
                                },
                                onLaunch: { Task { await presenter.launch(app) } },
                                onTerminate: {
                                    Task {
                                        presenter.selectedAppID = app.id
                                        await presenter.terminateSelectedApp()
                                    }
                                },
                                onUninstall: {
                                    Task {
                                        await presenter.uninstall(app)
                                    }
                                },
                                onReinstall: {
                                    Task {
                                        presenter.selectedAppID = app.id
                                        await presenter.reinstallSelectedApp()
                                    }
                                },
                                onOpenContainer: { Task { await presenter.openContainer(app) } },
                                onCopyBundleID: { Task { await presenter.copyBundleID(app) } }
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                StatusBarItem(icon: "cpu", label: "Simulators", value: "\(presenter.simulators.count)")
                StatusBarItem(icon: "app.badge", label: "Apps", value: "\(presenter.indexedAppCount)")
                StatusBarItem(icon: "checklist", label: "Batch", value: "\(presenter.selectedTargets.count)")
                StatusBarItem(icon: "clock", label: "Scan", value: formattedScanTime)
            }

            Spacer()

            if let action = presenter.actionMessage, !action.isEmpty {
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text(action)
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }

    private var formattedScanTime: String {
        guard let time = presenter.lastScanTime else { return "Never" }
        return time.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Shortcuts

    private var shortcutButtons: some View {
        Group {
            Button("") { isSearchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .frame(width: 0, height: 0).opacity(0)

            Button("") { Task { await presenter.launchSelectedApp() } }
                .keyboardShortcut(.return, modifiers: [])
                .frame(width: 0, height: 0).opacity(0)

            Button("") {
                Task {
                    if let selected = presenter.selectedApp { await presenter.openAppSimulator(selected) }
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .frame(width: 0, height: 0).opacity(0)
        }
        .onAppear { presenter.focusFirstResult() }
    }
}

// MARK: - Filter Picker

private struct FilterPicker<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [(label: String, value: T)]
    let width: CGFloat

    var selectionLabel: String {
        options.first(where: { $0.value == selection })?.label ?? ""
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Menu {
                ForEach(options, id: \.label) { option in
                    Button(option.label) { selection = option.value }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(selectionLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Status Bar Item

private struct StatusBarItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .help(label)
    }
}

// MARK: - Sidebar Row

private struct SidebarSimulatorRow: View {
    let simulator: SimulatorDevice
    let selected: Bool
    let favorite: Bool
    let multiSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            ZStack {
                Circle()
                    .fill(simulator.isBooted ? Color.green.opacity(0.2) : Color.clear)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(simulator.isBooted ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(simulator.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("iOS \(simulator.osVersion)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                if favorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                if multiSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Simulator Selection Card

private struct SimulatorSelectionCard: View {
    let simulator: SimulatorDevice
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Device icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(simulator.isBooted ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: deviceIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(simulator.isBooted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(simulator.name)
                        .font(.system(size: 13, weight: .semibold))
                    if simulator.isBooted {
                        Text("Running")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1), in: Capsule())
                    }
                }

                HStack(spacing: 10) {
                    Label("iOS \(simulator.osVersion)", systemImage: "gearshape")
                    Label(simulator.deviceType.rawValue, systemImage: "iphone")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                Text(simulator.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0.03), radius: isHovered ? 8 : 4, y: 2)
        .scaleEffect(isHovered ? 1.005 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var deviceIcon: String {
        let name = simulator.name.lowercased()
        if name.contains("ipad") { return "ipad" }
        if name.contains("watch") { return "applewatch" }
        if name.contains("tv") { return "appletv" }
        return "iphone"
    }

    private func formatted(date: Date?) -> String {
        guard let date else { return "Unknown" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Simulator Quick Actions Bar

private struct SimulatorQuickActionsBar: View {
    @ObservedObject var presenter: SimulatorPresenter
    let simulator: SimulatorDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Actions row
            HStack(spacing: 8) {
                // Boot / Shutdown
                Button {
                    Task {
                        if simulator.isBooted { await presenter.shutdown(simulator) }
                        else { await presenter.boot(simulator) }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: simulator.isBooted ? "stop.circle.fill" : "play.circle.fill")
                        Text(simulator.isBooted ? "Shutdown" : "Boot")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(simulator.isBooted ? .red : .accentColor)

                QuickActionButton(label: "Open Simulator", icon: "macwindow") {
                    Task { await presenter.openSimulator(simulator) }
                }
                QuickActionButton(label: "Erase", icon: "trash") {
                    Task { await presenter.erase(simulator) }
                }
                QuickActionButton(label: "Data Folder", icon: "folder") {
                    Task { await presenter.openSimulatorDataFolder(simulator) }
                }

                Spacer()

                // Simulator name badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(simulator.isBooted ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(simulator.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .overlay(Color(nsColor: .separatorColor).opacity(0.3))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Install Source")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Install a build directly from a .app or .ipa file.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            Color(nsColor: .separatorColor).opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                        )
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.app")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                        if presenter.installFilePath.isEmpty {
                            Text("Drop .app or .ipa here")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text((presenter.installFilePath as NSString).lastPathComponent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity, minHeight: 72)

                HStack(spacing: 6) {
                    Text("or")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button("browse file…") { Task { await presenter.pickInstallFile() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .disabled(presenter.isInstallingAppFile)

                    if !presenter.installFilePath.isEmpty {
                        Button {
                            presenter.installFilePath = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .disabled(presenter.isInstallingAppFile)
                    }

                    Spacer()

                    if presenter.isInstallingAppFile {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Installing…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(presenter.isInstallingAppFile ? "Installing…" : "Install") {
                        Task { await presenter.installSelectedAppFile() }
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(presenter.installFilePath.isEmpty || presenter.isInstallingAppFile)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

private struct QuickActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - App Result Card

private struct AppGridItem: View {
    @ObservedObject var presenter: SimulatorPresenter
    let app: IndexedApp
    let selectedSimulatorID: String?
    let onOpenAdvanced: () -> Void
    let onLaunch: () -> Void
    let onTerminate: () -> Void
    let onUninstall: () -> Void
    let onReinstall: () -> Void
    let onOpenContainer: () -> Void
    let onCopyBundleID: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                AppBundleIcon(bundlePath: app.bundlePath)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .bold))
                    Text(app.bundleID)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 8) {
                        if let version = app.version, !version.isEmpty {
                            InfoTag(icon: "tag", text: "v\(version)")
                        }
                        if let build = app.build, !build.isEmpty {
                            InfoTag(icon: "hammer", text: "Build \(build)")
                        }
                        if let size = app.sizeInBytes {
                            InfoTag(icon: "internaldrive", text: byteFormatter.string(fromByteCount: size))
                        }
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    Button(action: onCopyBundleID) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.bordered)
                    .help("Copy Bundle ID")

                    Button(action: onOpenContainer) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .help("Open Documents Folder")
                }
                .opacity(isHovered ? 1 : 0.001)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .contentShape(Rectangle())
            .onTapGesture { onOpenAdvanced() }

            HStack(spacing: 8) {
                lifecycleButton(title: "Launch", icon: "play.fill", tint: .blue, action: onLaunch)
                lifecycleButton(title: "Terminate", icon: "stop.fill", tint: .orange, action: onTerminate)
                lifecycleButton(title: "Uninstall", icon: "trash.fill", tint: .red, action: onUninstall)
                lifecycleButton(title: "Reinstall", icon: "arrow.triangle.2.circlepath", tint: .green, action: onReinstall)
            }

            if !app.installedOn.isEmpty {
                Text("The app is installed on:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(app.installedOn, id: \.self) { installed in
                            simulatorChip(installed)
                        }
                    }
                }
            }

            Divider()
                .overlay(Color(nsColor: .separatorColor).opacity(0.3))

            HStack(spacing: 12) {
                if let installDate = app.installDate {
                    Label(installDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
                Label(app.bundlePath, systemImage: "folder.badge.gearshape")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)

            Button {
                onOpenAdvanced()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Advanced Options")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.07 : 0.03), radius: isHovered ? 10 : 4, y: 3)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private func lifecycleButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .help(title)
    }
    
    // MARK: - Simulator Chip

    private func simulatorChip(_ installed: InstalledOnSimulator) -> some View {
        let selected = selectedSimulatorIDs.contains(installed.simulatorID)
        return Button {
            presenter.selectSimulator(installed.simulatorID)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: installed.simulatorName.lowercased().contains("ipad") ? "ipad" : "iphone")
                    .font(.system(size: 10, weight: .semibold))
                Text(installed.simulatorName)
                    .font(.system(size: 10, weight: .medium))
                Circle()
                    .fill(installed.state == "Booted" ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                Capsule().fill(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule().stroke(Color(nsColor: .separatorColor).opacity(selected ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedSimulatorIDs: Set<String> {
        if presenter.selectedSimulatorIDs.isEmpty, let selectedSimulatorID {
            return [selectedSimulatorID]
        }
        return presenter.selectedSimulatorIDs
    }

    private var byteFormatter: ByteCountFormatter {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB]
        f.countStyle = .file
        return f
    }
}

private struct AppAdvancedPopup: View {
    @ObservedObject var presenter: SimulatorPresenter
    let app: IndexedApp
    let onClose: () -> Void

    @State private var localTab: ControlPanelTab = .testing
    @Namespace private var advancedTabAnimation

    private let tabs: [ControlPanelTab] = [.data, .testing, .logs]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(10)
                }
                .buttonStyle(.bordered)
                .help("Close")

                AppBundleIcon(bundlePath: app.bundlePath, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(app.bundleID)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)

            Divider()
                .overlay(Color(nsColor: .separatorColor).opacity(0.3))

            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    let isSelected = localTab == tab
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                            localTab = tab
                        }
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.symbolName)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            Rectangle()
                                .fill(isSelected ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "detail-tab-underline", in: advancedTabAnimation, isSource: isSelected)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .background(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.25))
                    .frame(height: 1)
            }

            Group {
                switch localTab {
                case .data:
                    DataAdvancedTabView(presenter: presenter)
                case .testing:
                    TestingAdvancedTabView(presenter: presenter)
                case .logs:
                    LogsAdvancedTabView(presenter: presenter)
                case .app:
                    EmptyView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        )
        .frame(minWidth: 720, minHeight: 560)
    }
}

private struct AppBundleIcon: View {
    let bundlePath: String
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(nsImage: resolvedIcon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(nsImage: fallbackIcon)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(8, size * 0.22)))
        .overlay(
            RoundedRectangle(cornerRadius: max(8, size * 0.22))
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        )
    }

    private var fallbackIcon: NSImage {
        let icon = NSWorkspace.shared.icon(forFileType: "app")
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    private var resolvedIcon: NSImage? {
        let plistPath = URL(fileURLWithPath: bundlePath).appendingPathComponent("Info.plist").path
        guard
            FileManager.default.fileExists(atPath: plistPath),
            let plist = NSDictionary(contentsOfFile: plistPath) as? [String: Any]
        else {
            return nil
        }
        let candidates = iconNameCandidates(from: plist)
        for candidate in candidates {
            if let icon = loadIcon(named: candidate) {
                return icon
            }
        }
        return nil
    }

    private func iconNameCandidates(from plist: [String: Any]) -> [String] {
        var names: [String] = []
        if let iconFile = plist["CFBundleIconFile"] as? String, !iconFile.isEmpty {
            names.append(iconFile)
        }
        if let iconFiles = plist["CFBundleIconFiles"] as? [String] {
            names.append(contentsOf: iconFiles)
        }
        if
            let icons = plist["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        {
            names.append(contentsOf: iconFiles)
        }
        return Array(NSOrderedSet(array: names)) as? [String] ?? []
    }

    private func loadIcon(named name: String) -> NSImage? {
        let possibleNames: [String]
        if name.contains(".") {
            possibleNames = [name]
        } else {
            possibleNames = [name, "\(name).png"]
        }
        for fileName in possibleNames {
            let direct = URL(fileURLWithPath: bundlePath).appendingPathComponent(fileName).path
            if let icon = NSImage(contentsOfFile: direct) {
                icon.size = NSSize(width: size, height: size)
                return icon
            }
            let resources = URL(fileURLWithPath: bundlePath).appendingPathComponent("Resources").appendingPathComponent(fileName).path
            if let icon = NSImage(contentsOfFile: resources) {
                icon.size = NSSize(width: size, height: size)
                return icon
            }
        }
        return nil
    }
}

// MARK: - Info Tag

private struct InfoTag: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1))
    }
}

// MARK: - App Card Skeleton

private struct AppCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)).frame(width: 200, height: 14)
            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)).frame(width: 280, height: 11)
            RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)).frame(height: 24)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)).frame(width: 70, height: 26)
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)).frame(width: 110, height: 26)
            }
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .redacted(reason: .placeholder)
    }
}

// MARK: - ControlPanelTab extension

private extension ControlPanelTab {
    var symbolName: String {
        switch self {
        case .app:     return "app.fill"
        case .data:    return "folder.fill"
        case .testing: return "testtube.2"
        case .logs:    return "doc.text.fill"
        }
    }
}

#Preview {
    ContentView()
}
