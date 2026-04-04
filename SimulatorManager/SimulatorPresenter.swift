import Foundation

enum ControlPanelTab: String, CaseIterable, Identifiable {
    case app = "App"
    case data = "Data"
    case testing = "Testing"
    case logs = "Logs"

    var id: String { rawValue }
}

enum SimulatorSortOption: String, CaseIterable, Identifiable {
    case lastUsed = "Last Used"
    case creationDate = "Creation Date"

    var id: String { rawValue }
}

enum SimulatorDeviceTypeFilter: String, CaseIterable, Identifiable {
    case all = "All Types"
    case iphone = "iPhone"
    case ipad = "iPad"
    case iwatch = "iWatch"
    case tv = "Apple TV"
    case vision = "Vision"
    case other = "Other"

    var id: String { rawValue }

    func matches(_ type: SimulatorDeviceType) -> Bool {
        switch self {
        case .all:
            return true
        case .iphone:
            return type == .iphone
        case .ipad:
            return type == .ipad
        case .iwatch:
            return type == .iwatch
        case .tv:
            return type == .tv
        case .vision:
            return type == .vision
        case .other:
            return type == .other
        }
    }
}

@MainActor
final class SimulatorPresenter: ObservableObject {
    @Published var searchQuery: String {
        didSet {
            UserDefaults.standard.set(searchQuery, forKey: Self.lastSearchDefaultsKey)
            debounceApplyFilters()
        }
    }
    @Published var selectedSimulatorID: String?
    @Published var selectedSimulatorIDs: Set<String> = []
    @Published var selectedOSVersionFilter = "All Versions" {
        didSet {
            applyFilters()
        }
    }
    @Published var selectedDeviceTypeFilter: SimulatorDeviceTypeFilter = .all {
        didSet {
            applyFilters()
        }
    }
    @Published var selectedSortOption: SimulatorSortOption = .lastUsed {
        didSet {
            applyFilters()
        }
    }
    @Published var selectedAppID: String?
    @Published var selectedTab: ControlPanelTab = .app
    @Published var installFilePath = ""
    @Published private(set) var isInstallingAppFile = false
    @Published var bundleIDInput = ""
    @Published var containerKind: AppContainerKind = .data
    @Published var remotePushPath = "Documents/"
    @Published var deepLink = ""
    @Published var pushPayloadJSON = "{\n  \"aps\": {\n    \"alert\": \"Hello from simctl\"\n  }\n}"
    @Published var locationLatitude = "48.8566"
    @Published var locationLongitude = "2.3522"
    @Published var selectedAppearance: AppearanceMode = .light
    @Published var selectedPrivacyService: PrivacyService = .camera
    @Published var clipboardText = ""
    @Published var pastedClipboardText = ""
    @Published var statusBarTime = "9:41"
    @Published var statusBarOperator = "Carrier"
    @Published var statusBarDataNetwork: StatusBarDataNetwork = .wifi
    @Published var statusBarWiFiMode: StatusBarWiFiMode = .active
    @Published var statusBarBattery = "100"
    @Published var statusBarBatteryState: StatusBarBatteryState = .charged
    @Published var statusBarWiFiBars = "3"
    @Published var statusBarCellularMode: StatusBarCellularMode = .active
    @Published var statusBarCellularBars = "4"
    @Published var contentSizeCategory: ContentSizeCategory = .medium
    @Published var languageCode = Locale.current.language.languageCode?.identifier ?? "en"
    @Published var localeIdentifier = Locale.current.identifier
    @Published var accessibilityOverrideStates: [AccessibilityOverride: Bool] = [:]
    @Published private(set) var isRecordingVideo = false
    @Published private(set) var isStreamingLogs = false
    @Published private(set) var logLines: [String] = []
    @Published var logSearchQuery = ""
    @Published var networkConditionNote = "Network throttling is not exposed by simctl. Use macOS Network Link Conditioner if installed."
    @Published private(set) var filteredApps: [IndexedApp] = []
    @Published private(set) var filteredSimulators: [SimulatorDevice] = []
    @Published private(set) var allApps: [IndexedApp] = []
    @Published private(set) var simulators: [SimulatorDevice] = []
    @Published private(set) var isLoadingSimulators = false
    @Published private(set) var isScanningApps = false
    @Published private(set) var favorites: Set<String>
    @Published private(set) var lastScanTime: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let simulatorService: SimulatorServiceing
    private let scannerService: AppScannerServiceing
    private let router: SimulatorRouting
    private let appManager: AppOperationsManaging
    private let dataManager: DataOperationsManaging
    private let testingManager: TestingOperationsManaging
    private let logManager: LogOperationsManaging
    private var hasLoadedSimulators = false
    private var searchDebounceTask: Task<Void, Never>?
    private var logsTask: Task<Void, Never>?
    private var activeLogStreamID: UUID?

    private static let lastSearchDefaultsKey = "simulator.search.query"
    private static let favoriteDefaultsKey = "simulator.favorites.ids"

    init(
        simulatorService: SimulatorServiceing,
        scannerService: AppScannerServiceing,
        router: SimulatorRouting,
        appManager: AppOperationsManaging,
        dataManager: DataOperationsManaging,
        testingManager: TestingOperationsManaging,
        logManager: LogOperationsManaging
    ) {
        self.simulatorService = simulatorService
        self.scannerService = scannerService
        self.router = router
        self.appManager = appManager
        self.dataManager = dataManager
        self.testingManager = testingManager
        self.logManager = logManager
        self.searchQuery = UserDefaults.standard.string(forKey: Self.lastSearchDefaultsKey) ?? ""
        self.favorites = Set(UserDefaults.standard.stringArray(forKey: Self.favoriteDefaultsKey) ?? [])
    }

    deinit {
        searchDebounceTask?.cancel()
        logsTask?.cancel()
        if let activeLogStreamID {
            Task {
                await logManager.stop(streamID: activeLogStreamID)
            }
        }
    }

    var availableSimulatorCount: Int {
        simulators.filter(\.isAvailable).count
    }

    var indexedAppCount: Int {
        allApps.count
    }

    var selectedSimulator: SimulatorDevice? {
        guard let selectedSimulatorID else {
            return nil
        }
        return simulators.first(where: { $0.id == selectedSimulatorID })
    }

    var favoriteSimulators: [SimulatorDevice] {
        filteredSimulators.filter { favorites.contains($0.id) }
    }

    var nonFavoriteSimulators: [SimulatorDevice] {
        filteredSimulators.filter { !favorites.contains($0.id) }
    }

    var isSimulatorSelected: Bool {
        selectedSimulatorID != nil
    }

    var osVersionFilterOptions: [String] {
        let versions = Set(simulators.map(\.osVersion))
        let sorted = versions.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedDescending
        }
        return ["All Versions"] + sorted
    }

    var selectedApp: IndexedApp? {
        guard let selectedAppID else {
            return filteredApps.first
        }
        return filteredApps.first(where: { $0.id == selectedAppID }) ?? filteredApps.first
    }

    var selectedTargets: [SimulatorCommandTarget] {
        if !selectedSimulatorIDs.isEmpty {
            return simulators
                .filter { selectedSimulatorIDs.contains($0.id) }
                .map { SimulatorCommandTarget(simulatorID: $0.id, simulatorName: $0.name, state: $0.state) }
        }
        if let selectedSimulatorID, let simulator = simulators.first(where: { $0.id == selectedSimulatorID }) {
            return [SimulatorCommandTarget(simulatorID: simulator.id, simulatorName: simulator.name, state: simulator.state)]
        }
        if let app = selectedApp {
            return app.installedOn.map { SimulatorCommandTarget(simulatorID: $0.simulatorID, simulatorName: $0.simulatorName, state: $0.state) }
        }
        return []
    }

    var locationPresets: [LocationPreset] {
        [
            LocationPreset(id: "paris", name: "Paris", latitude: "48.8566", longitude: "2.3522"),
            LocationPreset(id: "new-york", name: "New York", latitude: "40.7128", longitude: "-74.0060"),
            LocationPreset(id: "tokyo", name: "Tokyo", latitude: "35.6762", longitude: "139.6503")
        ]
    }

    var filteredLogLines: [String] {
        let query = logSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return logLines
        }
        return logLines.filter { $0.lowercased().contains(query) }
    }

    func loadDataIfNeeded() async {
        guard !hasLoadedSimulators else {
            return
        }
        hasLoadedSimulators = true
        await refresh(forceRescan: false)
    }

    func refresh(forceRescan: Bool) async {
        isLoadingSimulators = true
        isScanningApps = true
        errorMessage = nil
        defer {
            isLoadingSimulators = false
            isScanningApps = false
        }

        do {
            let devices = try await self.simulatorService.allSimulators()
            simulators = devices
            if let selectedSimulatorID, !devices.contains(where: { $0.id == selectedSimulatorID }) {
                self.selectedSimulatorID = nil
            }
            selectedSimulatorIDs = selectedSimulatorIDs.intersection(Set(devices.map(\.id)))
            applyFilters()

            do {
                let snapshot = try await scannerService.scanApps(simulators: devices, forceRefresh: forceRescan)
                allApps = snapshot.apps
                lastScanTime = snapshot.scannedAt
                applyFilters()
            } catch {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSelection(offset: Int) {
        guard !filteredApps.isEmpty else {
            return
        }

        guard let selectedApp else {
            selectedAppID = filteredApps.first?.id
            return
        }

        guard let currentIndex = filteredApps.firstIndex(where: { $0.id == selectedApp.id }) else {
            selectedAppID = filteredApps.first?.id
            return
        }

        let index = min(max(currentIndex + offset, 0), filteredApps.count - 1)
        selectedAppID = filteredApps[index].id
    }

    func focusFirstResult() {
        selectedAppID = filteredApps.first?.id
    }

    func toggleFavorite(simulatorID: String) {
        if favorites.contains(simulatorID) {
            favorites.remove(simulatorID)
        } else {
            favorites.insert(simulatorID)
        }
        UserDefaults.standard.set(Array(favorites), forKey: Self.favoriteDefaultsKey)
    }

    func toggleSimulatorFilter(_ simulatorID: String?) {
        if selectedSimulatorID == simulatorID {
            selectedSimulatorID = nil
        } else {
            selectedSimulatorID = simulatorID
        }
        if let simulatorID {
            selectedSimulatorIDs = [simulatorID]
        } else {
            selectedSimulatorIDs = []
        }
        applyFilters()
    }

    func selectSimulator(_ simulatorID: String) {
        selectedSimulatorID = simulatorID
        selectedSimulatorIDs = [simulatorID]
        applyFilters()
    }

    func clearSelectedSimulator() {
        selectedSimulatorID = nil
        selectedSimulatorIDs = []
        applyFilters()
    }

    func toggleMultiSelection(simulatorID: String) {
        if selectedSimulatorIDs.contains(simulatorID) {
            selectedSimulatorIDs.remove(simulatorID)
        } else {
            selectedSimulatorIDs.insert(simulatorID)
        }
    }

    func boot(_ simulator: SimulatorDevice) async {
        errorMessage = nil
        do {
            try await self.simulatorService.boot(udid: simulator.id)
            await refresh(forceRescan: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shutdown(_ simulator: SimulatorDevice) async {
        errorMessage = nil
        do {
            try await self.simulatorService.shutdown(udid: simulator.id)
            await refresh(forceRescan: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func erase(_ simulator: SimulatorDevice) async {
        errorMessage = nil
        do {
            try await self.simulatorService.erase(udid: simulator.id)
            await refresh(forceRescan: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSimulator(_ simulator: SimulatorDevice) async {
        errorMessage = nil
        do {
            try await self.simulatorService.openInSimulator(udid: simulator.id)
            await refresh(forceRescan: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func triggeriCloudSync() async {
        await performForSelectedTargets { target in
            try await self.testingManager.triggeriCloudSync(target: target)
        }
    }

    func resetKeychain() async {
        await performForSelectedTargets { target in
            try await self.testingManager.resetKeychain(target: target)
        }
    }

    func launchSelectedApp() async {
        guard let app = selectedApp else {
            return
        }
        await launch(app)
    }

    func launch(_ app: IndexedApp) async {
        guard let target = targetSimulator(for: app) else {
            return
        }
        errorMessage = nil
        do {
            let commandTarget = SimulatorCommandTarget(simulatorID: target.simulatorID, simulatorName: target.simulatorName, state: target.state)
            try await self.appManager.launch(bundleID: app.bundleID, target: commandTarget)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openAppSimulator(_ app: IndexedApp) async {
        await launch(app)
    }

    func openSimulatorDataFolder(_ simulator: SimulatorDevice) async {
        errorMessage = nil
        let simulatorDataPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices")
            .appendingPathComponent(simulator.id)
            .appendingPathComponent("data")
            .path
        do {
            try await router.openFolder(path: simulatorDataPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openContainer(_ app: IndexedApp) async {
        guard let target = targetSimulator(for: app) else {
            return
        }
        errorMessage = nil
        do {
            let containerPath = try await self.simulatorService.appContainer(bundleID: app.bundleID, simulatorUDID: target.simulatorID)
            let documentsPath = URL(fileURLWithPath: containerPath)
                .appendingPathComponent("Documents")
                .path
            try await router.openFolder(path: documentsPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyBundleID(_ app: IndexedApp) async {
        await router.copyToClipboard(app.bundleID)
    }

    func pickInstallFile() async {
        if let path = await router.pickFile(allowedFileTypes: ["app", "ipa"]) {
            installFilePath = path
        }
    }

    func installSelectedAppFile() async {
        guard !installFilePath.isEmpty else {
            return
        }
        let pathToInstall = installFilePath
        isInstallingAppFile = true
        actionMessage = "Installing app…"
        defer { isInstallingAppFile = false }
        await performForSelectedTargets { target in
            try await self.appManager.install(path: pathToInstall, target: target)
        }
        installFilePath = ""
        await refresh(forceRescan: true)
    }

    func uninstallSelectedApp() async {
        guard let app = selectedApp else {
            return
        }
        await uninstall(app)
    }

    func uninstall(_ app: IndexedApp) async {
        let targetSimulatorIDs = targetedSimulatorIDs(for: app)
        await performForTargets(of: app) { target in
            try await self.appManager.uninstall(bundleID: app.bundleID, target: target)
        }
        pruneAppFromLocalState(bundleID: app.bundleID, removedFrom: targetSimulatorIDs)
        await refresh(forceRescan: true)
    }

    func terminateSelectedApp() async {
        guard let app = selectedApp else {
            return
        }
        await performForTargets(of: app) { target in
            try await self.appManager.terminate(bundleID: app.bundleID, target: target)
        }
    }

    func reinstallSelectedApp() async {
        guard let app = selectedApp, !installFilePath.isEmpty else {
            return
        }
        await performForTargets(of: app) { target in
            try await self.appManager.reinstall(path: self.installFilePath, bundleID: app.bundleID, target: target)
        }
        await refresh(forceRescan: true)
    }

    func openContainer(kind: AppContainerKind) async {
        guard let app = selectedApp, let target = targetSimulator(for: app) else {
            return
        }
        errorMessage = nil
        do {
            let commandTarget = SimulatorCommandTarget(simulatorID: target.simulatorID, simulatorName: target.simulatorName, state: target.state)
            let containerPath = try await self.dataManager.openContainer(bundleID: app.bundleID, target: commandTarget, kind: kind)
            try await router.openFolder(path: containerPath)
            actionMessage = "Opened \(kind.rawValue) container."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pushFileIntoApp() async {
        guard let app = selectedApp else {
            return
        }
        guard let localPath = await router.pickFile(allowedFileTypes: ["json", "txt", "png", "jpg", "pdf", "mp4", "sqlite"]) else {
            return
        }
        await performForTargets(of: app) { target in
            try await self.dataManager.pushFile(bundleID: app.bundleID, target: target, localPath: localPath, remotePath: self.remotePushPath)
        }
    }

    func addMediaToSelectedSimulators() async {
        guard let mediaPath = await router.pickFile(allowedFileTypes: ["png", "jpg", "jpeg", "mov", "mp4"]) else {
            return
        }
        await performForSelectedTargets { target in
            try await self.dataManager.addMedia(target: target, filePath: mediaPath)
        }
    }

    func takeScreenshot() async {
        guard let path = await router.savePanel(defaultName: "simulator-\(Date().timeIntervalSince1970).png", allowedFileTypes: ["png"]) else {
            return
        }
        await performForSelectedTargets { target in
            try await self.testingManager.screenshot(target: target, path: path)
        }
    }

    func toggleVideoRecording() async {
        if isRecordingVideo {
            await performForSelectedTargets { target in
                try await self.testingManager.stopRecording(target: target)
            }
            isRecordingVideo = false
            actionMessage = "Recording stopped."
            return
        }
        guard let path = await router.savePanel(defaultName: "simulator-\(Date().timeIntervalSince1970).mp4", allowedFileTypes: ["mp4"]) else {
            return
        }
        await performForSelectedTargets { target in
            try await self.testingManager.startRecording(target: target, path: path)
        }
        isRecordingVideo = true
        actionMessage = "Recording started."
    }

    func applyLocationPreset(_ preset: LocationPreset) async {
        locationLatitude = preset.latitude
        locationLongitude = preset.longitude
        await setCustomLocation()
    }

    func setCustomLocation() async {
        await performForSelectedTargets { target in
            try await self.testingManager.setLocation(target: target, latitude: self.locationLatitude, longitude: self.locationLongitude)
        }
    }

    func runGPXLocation() async {
        guard let gpxPath = await router.pickFile(allowedFileTypes: ["gpx"]) else {
            return
        }
        await performForSelectedTargets { target in
            try await self.testingManager.runGPX(target: target, gpxPath: gpxPath)
        }
    }

    func setAppearance(_ mode: AppearanceMode) async {
        selectedAppearance = mode
        await performForSelectedTargets { target in
            try await self.testingManager.setAppearance(target: target, mode: mode)
        }
    }

    func setContentSize(_ size: ContentSizeCategory) async {
        contentSizeCategory = size
        await performForSelectedTargets { target in
            try await self.testingManager.setContentSize(target: target, size: size)
        }
    }

    func setAccessibilityOverride(_ key: AccessibilityOverride, enabled: Bool) async {
        accessibilityOverrideStates[key] = enabled
        await performForSelectedTargets { target in
            try await self.testingManager.setAccessibility(target: target, key: key, enabled: enabled)
        }
    }

    func applyLanguageLocale() async {
        await performForSelectedTargets { target in
            try await self.testingManager.setLanguageAndLocale(
                target: target,
                languageCode: self.languageCode,
                localeIdentifier: self.localeIdentifier
            )
        }
        await refresh(forceRescan: false)
    }

    func setPrivacy(grant: Bool) async {
        guard let app = selectedApp else {
            return
        }
        await performForTargets(of: app) { target in
            try await self.testingManager.setPrivacy(target: target, bundleID: app.bundleID, service: self.selectedPrivacyService, grant: grant)
        }
    }

    func sendPushPayload() async {
        guard let app = selectedApp else {
            return
        }
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("payload-\(UUID().uuidString).apns")
        do {
            try pushPayloadJSON.write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await performForTargets(of: app) { target in
            try await self.testingManager.sendPush(target: target, bundleID: app.bundleID, apnsPath: tempFile.path)
        }
    }

    func openDeepLink() async {
        guard !deepLink.isEmpty else {
            return
        }
        await performForSelectedTargets { target in
            try await self.testingManager.openDeepLink(target: target, value: self.deepLink)
        }
    }

    func applyStatusBarOverride() async {
        let payload = StatusBarOverride(
            time: statusBarTime,
            dataNetwork: statusBarDataNetwork,
            wifiMode: statusBarWiFiMode,
            batteryLevel: Int(statusBarBattery),
            batteryState: statusBarBatteryState,
            wifiBars: Int(statusBarWiFiBars),
            cellularMode: statusBarCellularMode,
            cellularBars: Int(statusBarCellularBars),
            operatorName: statusBarOperator
        )
        await performForSelectedTargets { target in
            try await self.testingManager.overrideStatusBar(target: target, value: payload)
        }
    }

    func setAppleStatusBarTime() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 41
        components.second = 0
        let appleTime = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        statusBarTime = formatter.string(from: appleTime)
    }

    func clearStatusBar() async {
        await performForSelectedTargets { target in
            try await self.testingManager.clearStatusBar(target: target)
        }
        statusBarOperator = "Carrier"
        statusBarDataNetwork = .wifi
        statusBarWiFiMode = .active
        statusBarBattery = "100"
        statusBarBatteryState = .charged
        statusBarWiFiBars = "3"
        statusBarCellularMode = .active
        statusBarCellularBars = "4"
    }

    func copyTextToSimulatorClipboard() async {
        await performForSelectedTargets { target in
            try await self.testingManager.copyClipboard(target: target, value: self.clipboardText)
        }
    }

    func pasteTextFromSimulatorClipboard() async {
        guard let target = selectedTargets.first else {
            return
        }
        errorMessage = nil
        do {
            pastedClipboardText = try await self.testingManager.pasteClipboard(target: target)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startLogs() async {
        guard let target = selectedTargets.first else {
            return
        }
        logsTask?.cancel()
        if let activeLogStreamID {
            await logManager.stop(streamID: activeLogStreamID)
        }
        let stream = await logManager.start(target: target, bundleID: selectedApp?.bundleID)
        activeLogStreamID = stream.id
        isStreamingLogs = true
        logLines.removeAll()
        logsTask = Task {
            do {
                for try await line in stream.lines {
                    if Task.isCancelled {
                        break
                    }
                    await MainActor.run {
                        self.logLines.append(line)
                        if self.logLines.count > 1500 {
                            self.logLines.removeFirst(self.logLines.count - 1500)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isStreamingLogs = false
            }
        }
    }

    func stopLogs() async {
        logsTask?.cancel()
        logsTask = nil
        if let activeLogStreamID {
            await logManager.stop(streamID: activeLogStreamID)
        }
        activeLogStreamID = nil
        isStreamingLogs = false
    }

    func exportLogs() async {
        guard let path = await router.savePanel(defaultName: "simulator-logs.txt", allowedFileTypes: ["txt"]) else {
            return
        }
        do {
            try logLines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            actionMessage = "Logs exported."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func clearActionMessage() {
        actionMessage = nil
    }

    private func targetSimulator(for app: IndexedApp) -> InstalledOnSimulator? {
        if let selected = selectedSimulatorIDs.first {
            return app.installedOn.first(where: { $0.simulatorID == selected })
        }
        if let selectedSimulatorID {
            return app.installedOn.first(where: { $0.simulatorID == selectedSimulatorID })
        }
        if let booted = app.installedOn.first(where: { $0.state == "Booted" }) {
            return booted
        }
        return app.installedOn.first
    }

    private func applyFilters() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let simulatorCandidates = simulators.filter { simulator in
            let isMatchingOSVersion = selectedOSVersionFilter == "All Versions" || simulator.osVersion == selectedOSVersionFilter
            let isMatchingType = selectedDeviceTypeFilter.matches(simulator.deviceType)
            return isMatchingOSVersion && isMatchingType
        }

        if query.isEmpty {
            filteredSimulators = sortSimulators(simulatorCandidates)
        } else {
            let scoredSimulators: [(simulator: SimulatorDevice, score: Int)] = simulatorCandidates.compactMap { simulator in
                let relatedApps = allApps.filter { app in
                    app.installedOn.contains(where: { $0.simulatorID == simulator.id })
                }
                let score = fuzzyScore(query: query, simulator: simulator, relatedApps: relatedApps)
                guard score > 0 else {
                    return nil
                }
                return (simulator: simulator, score: score)
            }
            filteredSimulators = scoredSimulators
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score {
                        return lhs.score > rhs.score
                    }
                    return compareSimulator(lhs.simulator, rhs.simulator)
                }
                .map(\.simulator)
        }

        let appCandidates: [IndexedApp]
        if !selectedSimulatorIDs.isEmpty {
            appCandidates = allApps.filter { app in
                app.installedOn.contains(where: { selectedSimulatorIDs.contains($0.simulatorID) })
            }
        } else if let selectedSimulatorID {
            appCandidates = allApps.filter { app in
                app.installedOn.contains(where: { $0.simulatorID == selectedSimulatorID })
            }
        } else {
            appCandidates = allApps
        }

        if query.isEmpty {
            filteredApps = appCandidates
        } else {
            let scoredApps: [(app: IndexedApp, score: Int)] = appCandidates.compactMap { app in
                let score = fuzzyScore(query: query, app: app)
                guard score > 0 else {
                    return nil
                }
                return (app: app, score: score)
            }
            filteredApps = scoredApps
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score {
                        return lhs.score > rhs.score
                    }
                    return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
                }
                .map(\.app)
        }

        if let selectedAppID, !filteredApps.contains(where: { $0.id == selectedAppID }) {
            self.selectedAppID = filteredApps.first?.id
        } else if selectedAppID == nil {
            selectedAppID = filteredApps.first?.id
        }
    }

    private func performForTargets(of app: IndexedApp, operation: @escaping (SimulatorCommandTarget) async throws -> Void) async {
        var targets: [SimulatorCommandTarget] = []
        if !selectedSimulatorIDs.isEmpty {
            targets = app.installedOn
                .filter { selectedSimulatorIDs.contains($0.simulatorID) }
                .map { SimulatorCommandTarget(simulatorID: $0.simulatorID, simulatorName: $0.simulatorName, state: $0.state) }
        } else if let selectedSimulatorID {
            targets = app.installedOn
                .filter { $0.simulatorID == selectedSimulatorID }
                .map { SimulatorCommandTarget(simulatorID: $0.simulatorID, simulatorName: $0.simulatorName, state: $0.state) }
        } else {
            targets = app.installedOn.map { SimulatorCommandTarget(simulatorID: $0.simulatorID, simulatorName: $0.simulatorName, state: $0.state) }
        }
        await perform(targets: targets, operation: operation)
    }

    private func targetedSimulatorIDs(for app: IndexedApp) -> Set<String> {
        if !selectedSimulatorIDs.isEmpty {
            return Set(
                app.installedOn
                    .filter { selectedSimulatorIDs.contains($0.simulatorID) }
                    .map(\.simulatorID)
            )
        }
        if let selectedSimulatorID {
            return Set(
                app.installedOn
                    .filter { $0.simulatorID == selectedSimulatorID }
                    .map(\.simulatorID)
            )
        }
        return Set(app.installedOn.map(\.simulatorID))
    }

    private func pruneAppFromLocalState(bundleID: String, removedFrom removedSimulatorIDs: Set<String>) {
        guard !removedSimulatorIDs.isEmpty else { return }
        allApps = allApps.compactMap { app in
            guard app.bundleID == bundleID else { return app }
            let remainingInstalls = app.installedOn.filter { !removedSimulatorIDs.contains($0.simulatorID) }
            guard !remainingInstalls.isEmpty else { return nil }
            return IndexedApp(
                name: app.name,
                bundleID: app.bundleID,
                version: app.version,
                build: app.build,
                bundlePath: app.bundlePath,
                installDate: app.installDate,
                sizeInBytes: app.sizeInBytes,
                installedOn: remainingInstalls
            )
        }
        applyFilters()
    }

    private func performForSelectedTargets(operation: @escaping (SimulatorCommandTarget) async throws -> Void) async {
        await perform(targets: selectedTargets, operation: operation)
    }

    private func perform(targets: [SimulatorCommandTarget], operation: @escaping (SimulatorCommandTarget) async throws -> Void) async {
        guard !targets.isEmpty else {
            return
        }
        errorMessage = nil
        actionMessage = nil
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for target in targets {
                    group.addTask {
                        try await operation(target)
                    }
                }
                try await group.waitForAll()
            }
            actionMessage = "Completed on \(targets.count) simulator(s)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func debounceApplyFilters() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard let self, !Task.isCancelled else {
                return
            }
            self.applyFilters()
        }
    }

    private func fuzzyScore(query: String, app: IndexedApp) -> Int {
        var fields = [app.name.lowercased(), app.bundleID.lowercased()]
        fields.append(app.bundlePath.lowercased())
        fields.append(contentsOf: app.installedOn.map(\.simulatorName).map { $0.lowercased() })
        fields.append(contentsOf: app.installedOn.map(\.simulatorID).map { $0.lowercased() })
        fields.append(contentsOf: app.installedOn.compactMap(\.dataPath).map { $0.lowercased() })
        fields.append(contentsOf: app.installedOn.compactMap(\.documentsPath).map { $0.lowercased() })
        fields.append(contentsOf: app.installedOn.flatMap(\.indexedFileNames).map { $0.lowercased() })

        var best = 0
        for value in fields {
            best = max(best, score(query: query, value: value))
        }
        return best
    }

    private func fuzzyScore(query: String, simulator: SimulatorDevice, relatedApps: [IndexedApp]) -> Int {
        var fields = [
            simulator.id.lowercased(),
            simulator.name.lowercased(),
            simulator.runtimeName.lowercased(),
            simulator.runtimeIdentifier.lowercased(),
            simulator.osVersion.lowercased(),
            simulator.deviceType.rawValue.lowercased()
        ]
        for app in relatedApps {
            fields.append(app.name.lowercased())
            fields.append(app.bundleID.lowercased())
            fields.append(app.bundlePath.lowercased())
            fields.append(contentsOf: app.installedOn.flatMap(\.indexedFileNames).map { $0.lowercased() })
            fields.append(contentsOf: app.installedOn.compactMap(\.documentsPath).map { $0.lowercased() })
            fields.append(contentsOf: app.installedOn.compactMap(\.dataPath).map { $0.lowercased() })
        }

        var best = 0
        for value in fields {
            best = max(best, score(query: query, value: value))
        }
        return best
    }

    private func sortSimulators(_ simulators: [SimulatorDevice]) -> [SimulatorDevice] {
        simulators.sorted(by: compareSimulator)
    }

    private func compareSimulator(_ lhs: SimulatorDevice, _ rhs: SimulatorDevice) -> Bool {
        switch selectedSortOption {
        case .lastUsed:
            let lhsValue = lhs.lastUsedAt ?? .distantPast
            let rhsValue = rhs.lastUsedAt ?? .distantPast
            if lhsValue != rhsValue {
                return lhsValue > rhsValue
            }
        case .creationDate:
            let lhsValue = lhs.createdAt ?? .distantPast
            let rhsValue = rhs.createdAt ?? .distantPast
            if lhsValue != rhsValue {
                return lhsValue > rhsValue
            }
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func score(query: String, value: String) -> Int {
        if value.contains(query) {
            return 200 + min(80, query.count)
        }

        var queryIndex = query.startIndex
        var matches = 0
        var streak = 0
        var bestStreak = 0

        for character in value {
            guard queryIndex < query.endIndex else {
                break
            }
            if character == query[queryIndex] {
                matches += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
                query.formIndex(after: &queryIndex)
            } else {
                streak = 0
            }
        }

        guard queryIndex == query.endIndex else {
            return 0
        }
        return (matches * 10) + (bestStreak * 20)
    }
}

enum SimulatorModuleBuilder {
    @MainActor
    static func build() -> SimulatorPresenter {
        let simctlService = SimctlService()
        let simulatorService = SimulatorService(simctlService: simctlService)
        return SimulatorPresenter(
            simulatorService: simulatorService,
            scannerService: AppScannerService(),
            router: SimulatorRouter(),
            appManager: AppOperationsManager(simulatorService: simulatorService),
            dataManager: DataOperationsManager(simulatorService: simulatorService),
            testingManager: TestingOperationsManager(simulatorService: simulatorService),
            logManager: LogOperationsManager(simulatorService: simulatorService)
        )
    }
}
