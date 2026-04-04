import Foundation

struct SimulatorDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let runtimeIdentifier: String
    let state: String
    let isAvailable: Bool
    let availabilityError: String?
    let deviceTypeIdentifier: String?
    let createdAt: Date?
    let lastUsedAt: Date?

    var runtimeName: String {
        let rawValue = runtimeIdentifier.split(separator: ".").last.map(String.init) ?? runtimeIdentifier
        let parts = rawValue.split(separator: "-").map(String.init)

        guard let platform = parts.first else {
            return runtimeIdentifier
        }

        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? platform : "\(platform) \(version)"
    }

    var osVersion: String {
        let rawValue = runtimeIdentifier.split(separator: ".").last.map(String.init) ?? runtimeIdentifier
        let parts = rawValue.split(separator: "-").map(String.init)
        guard parts.count >= 2 else {
            return runtimeName
        }
        return parts.dropFirst().joined(separator: ".")
    }

    var statusDescription: String {
        if isAvailable {
            return state
        }

        return availabilityError ?? "Unavailable"
    }

    var isBooted: Bool {
        state.caseInsensitiveCompare("Booted") == .orderedSame
    }

    var deviceType: SimulatorDeviceType {
        SimulatorDeviceType.resolve(
            deviceTypeIdentifier: deviceTypeIdentifier,
            name: name,
            runtimeIdentifier: runtimeIdentifier
        )
    }
}

enum SimulatorDeviceType: String, CaseIterable, Identifiable, Sendable {
    case iphone = "iPhone"
    case ipad = "iPad"
    case iwatch = "iWatch"
    case tv = "Apple TV"
    case vision = "Vision"
    case other = "Other"

    var id: String { rawValue }

    static func resolve(deviceTypeIdentifier: String?, name: String, runtimeIdentifier: String) -> SimulatorDeviceType {
        let resolvedValue = [deviceTypeIdentifier, name, runtimeIdentifier]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if resolvedValue.contains("iphone") {
            return .iphone
        }
        if resolvedValue.contains("ipad") {
            return .ipad
        }
        if resolvedValue.contains("watch") {
            return .iwatch
        }
        if resolvedValue.contains("appletv") || resolvedValue.contains("apple tv") || resolvedValue.contains("tvos") {
            return .tv
        }
        if resolvedValue.contains("vision") {
            return .vision
        }
        return .other
    }
}

struct InstalledOnSimulator: Hashable, Sendable {
    let simulatorID: String
    let simulatorName: String
    let osVersion: String
    let state: String
    let bundlePath: String
    let dataPath: String?
    let documentsPath: String?
    let indexedFileNames: [String]
}

struct IndexedApp: Identifiable, Hashable, Sendable {
    var id: String { bundleID }
    let name: String
    let bundleID: String
    let version: String?
    let build: String?
    let bundlePath: String
    let installDate: Date?
    let sizeInBytes: Int64?
    let installedOn: [InstalledOnSimulator]
}

struct AppScanSnapshot: Sendable {
    let apps: [IndexedApp]
    let scannedAt: Date
}

enum AppContainerKind: String, CaseIterable, Codable, Sendable {
    case app
    case data
    case groups
}

enum AppearanceMode: String, CaseIterable, Codable, Sendable {
    case dark
    case light
}

enum PrivacyService: String, CaseIterable, Codable, Sendable {
    case camera
    case microphone
    case photos
    case location = "location"
    case contacts
    case calendar
    case notifications
}

struct StatusBarOverride: Codable, Hashable, Sendable {
    var time: String?
    var dataNetwork: StatusBarDataNetwork?
    var wifiMode: StatusBarWiFiMode?
    var batteryLevel: Int?
    var batteryState: StatusBarBatteryState?
    var wifiBars: Int?
    var cellularMode: StatusBarCellularMode?
    var cellularBars: Int?
    var operatorName: String?
}

enum StatusBarDataNetwork: String, CaseIterable, Codable, Sendable {
    case wifi
    case threeG = "3g"
    case fourG = "4g"
    case fiveG = "5g"
    case fiveGPlus = "5g+"
    case fiveGUWB = "5g-uwb"
    case lte
    case lteA = "lte-a"
    case ltePlus = "lte+"
}

enum StatusBarWiFiMode: String, CaseIterable, Codable, Sendable {
    case searching
    case failed
    case active
}

enum StatusBarCellularMode: String, CaseIterable, Codable, Sendable {
    case notSupported
    case searching
    case failed
    case active
}

enum StatusBarBatteryState: String, CaseIterable, Codable, Sendable {
    case charging
    case charged
    case discharging
}

enum ContentSizeCategory: String, CaseIterable, Codable, Sendable {
    case extraSmall = "Extra Small"
    case small = "Small"
    case medium = "Regular"
    case large = "Large"
    case extraLarge = "Extra Large"
    case extraExtraLarge = "Extra Extra Large"
    case extraExtraExtraLarge = "Extra Extra Extra Large"
    case accessibilityMedium = "Accessibility Medium"
    case accessibilityLarge = "Accessibility Large"
    case accessibilityExtraLarge = "Accessibility Extra Large"
    case accessibilityExtraExtraLarge = "Accessibility Extra Extra Large"
    case accessibilityExtraExtraExtraLarge = "Accessibility Extra Extra Extra Large"

    var simctlValue: String {
        switch self {
        case .extraSmall:
            return "extra-small"
        case .small:
            return "small"
        case .medium:
            return "medium"
        case .large:
            return "large"
        case .extraLarge:
            return "extra-large"
        case .extraExtraLarge:
            return "extra-extra-large"
        case .extraExtraExtraLarge:
            return "extra-extra-extra-large"
        case .accessibilityMedium:
            return "accessibility-medium"
        case .accessibilityLarge:
            return "accessibility-large"
        case .accessibilityExtraLarge:
            return "accessibility-extra-large"
        case .accessibilityExtraExtraLarge:
            return "accessibility-extra-extra-large"
        case .accessibilityExtraExtraExtraLarge:
            return "accessibility-extra-extra-extra-large"
        }
    }
}

enum AccessibilityOverride: String, CaseIterable, Codable, Sendable, Identifiable {
    case enhanceTextLegibility = "EnhancedTextLegibilityEnabled"
    case showButtonShapes = "ButtonShapesEnabled"
    case showOnOffLabels = "IncreaseButtonLegibilityEnabled"
    case reduceTransparency = "EnhancedBackgroundContrastEnabled"
    case increaseContrast = "DarkenSystemColors"
    case differentiateWithoutColor = "DifferentiateWithoutColor"
    case smartInvert = "InvertColorsEnabled"
    case reduceMotion = "ReduceMotionEnabled"
    case preferCrossFadeTransitions = "ReduceMotionReduceSlideTransitionsPreference"

    var id: String { rawValue }
}

struct LocationPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let latitude: String
    let longitude: String
}

struct SimctlResult: Sendable {
    let output: String
    let error: String
}

struct SimctlLogStream: Sendable {
    let id: UUID
    let lines: AsyncThrowingStream<String, Error>
}

struct SimulatorCommandTarget: Identifiable, Hashable, Sendable {
    let simulatorID: String
    let simulatorName: String
    let state: String

    var id: String { simulatorID }
}

protocol SimctlServiceing {
    func run(command: [String]) async throws -> String
    func runJSON<T: Decodable>(command: [String], as type: T.Type) async throws -> T
    func listSimulators() async throws -> [SimulatorDevice]
    func boot(udid: String) async throws
    func shutdown(udid: String) async throws
    func erase(udid: String) async throws
    func openSimulator(udid: String) async throws
    func installApp(path: String, simulatorUDID: String) async throws
    func uninstallApp(bundleID: String, simulatorUDID: String) async throws
    func launchApp(bundleID: String, simulatorUDID: String) async throws
    func terminateApp(bundleID: String, simulatorUDID: String) async throws
    func reinstallApp(path: String, bundleID: String, simulatorUDID: String) async throws
    func appContainer(bundleID: String, simulatorUDID: String) async throws -> String
    func appContainer(bundleID: String, simulatorUDID: String, kind: AppContainerKind) async throws -> String
    func pushFile(simulatorUDID: String, bundleID: String, localPath: String, remotePath: String) async throws
    func addMedia(simulatorUDID: String, filePath: String) async throws
    func takeScreenshot(simulatorUDID: String, outputPath: String) async throws
    func startVideoRecording(simulatorUDID: String, outputPath: String) async throws
    func stopVideoRecording(simulatorUDID: String) async throws
    func setLocation(simulatorUDID: String, latitude: String, longitude: String) async throws
    func runLocationGPX(simulatorUDID: String, gpxPath: String) async throws
    func setAppearance(simulatorUDID: String, mode: AppearanceMode) async throws
    func setContentSize(simulatorUDID: String, size: ContentSizeCategory) async throws
    func setAccessibility(simulatorUDID: String, key: AccessibilityOverride, enabled: Bool) async throws
    func setLanguageAndLocale(simulatorUDID: String, languageCode: String, localeIdentifier: String) async throws
    func triggeriCloudSync(simulatorUDID: String) async throws
    func resetKeychain(simulatorUDID: String) async throws
    func setPrivacy(simulatorUDID: String, bundleID: String, service: PrivacyService, grant: Bool) async throws
    func sendPush(simulatorUDID: String, bundleID: String, apnsFilePath: String) async throws
    func openURL(simulatorUDID: String, url: String) async throws
    func overrideStatusBar(simulatorUDID: String, value: StatusBarOverride) async throws
    func clearStatusBar(simulatorUDID: String) async throws
    func pbcopy(simulatorUDID: String, value: String) async throws
    func pbpaste(simulatorUDID: String) async throws -> String
    func logs(simulatorUDID: String, bundleID: String?) async -> SimctlLogStream
    func stopLogs(streamID: UUID) async
}

protocol SimulatorServiceing {
    func allSimulators() async throws -> [SimulatorDevice]
    func boot(udid: String) async throws
    func shutdown(udid: String) async throws
    func erase(udid: String) async throws
    func openInSimulator(udid: String) async throws
    func installApp(path: String, simulatorUDID: String) async throws
    func uninstallApp(bundleID: String, simulatorUDID: String) async throws
    func launchApp(bundleID: String, simulatorUDID: String) async throws
    func terminateApp(bundleID: String, simulatorUDID: String) async throws
    func reinstallApp(path: String, bundleID: String, simulatorUDID: String) async throws
    func appContainer(bundleID: String, simulatorUDID: String) async throws -> String
    func appContainer(bundleID: String, simulatorUDID: String, kind: AppContainerKind) async throws -> String
    func pushFile(simulatorUDID: String, bundleID: String, localPath: String, remotePath: String) async throws
    func addMedia(simulatorUDID: String, filePath: String) async throws
    func takeScreenshot(simulatorUDID: String, outputPath: String) async throws
    func startVideoRecording(simulatorUDID: String, outputPath: String) async throws
    func stopVideoRecording(simulatorUDID: String) async throws
    func setLocation(simulatorUDID: String, latitude: String, longitude: String) async throws
    func runLocationGPX(simulatorUDID: String, gpxPath: String) async throws
    func setAppearance(simulatorUDID: String, mode: AppearanceMode) async throws
    func setContentSize(simulatorUDID: String, size: ContentSizeCategory) async throws
    func setAccessibility(simulatorUDID: String, key: AccessibilityOverride, enabled: Bool) async throws
    func setLanguageAndLocale(simulatorUDID: String, languageCode: String, localeIdentifier: String) async throws
    func triggeriCloudSync(simulatorUDID: String) async throws
    func resetKeychain(simulatorUDID: String) async throws
    func setPrivacy(simulatorUDID: String, bundleID: String, service: PrivacyService, grant: Bool) async throws
    func sendPush(simulatorUDID: String, bundleID: String, apnsFilePath: String) async throws
    func openURL(simulatorUDID: String, url: String) async throws
    func overrideStatusBar(simulatorUDID: String, value: StatusBarOverride) async throws
    func clearStatusBar(simulatorUDID: String) async throws
    func pbcopy(simulatorUDID: String, value: String) async throws
    func pbpaste(simulatorUDID: String) async throws -> String
    func logs(simulatorUDID: String, bundleID: String?) async -> SimctlLogStream
    func stopLogs(streamID: UUID) async
}

protocol AppScannerServiceing {
    func scanApps(simulators: [SimulatorDevice], forceRefresh: Bool) async throws -> AppScanSnapshot
}

protocol AppOperationsManaging {
    func launch(bundleID: String, target: SimulatorCommandTarget) async throws
    func terminate(bundleID: String, target: SimulatorCommandTarget) async throws
    func install(path: String, target: SimulatorCommandTarget) async throws
    func uninstall(bundleID: String, target: SimulatorCommandTarget) async throws
    func reinstall(path: String, bundleID: String, target: SimulatorCommandTarget) async throws
}

protocol DataOperationsManaging {
    func openContainer(bundleID: String, target: SimulatorCommandTarget, kind: AppContainerKind) async throws -> String
    func pushFile(bundleID: String, target: SimulatorCommandTarget, localPath: String, remotePath: String) async throws
    func addMedia(target: SimulatorCommandTarget, filePath: String) async throws
}

protocol TestingOperationsManaging {
    func screenshot(target: SimulatorCommandTarget, path: String) async throws
    func startRecording(target: SimulatorCommandTarget, path: String) async throws
    func stopRecording(target: SimulatorCommandTarget) async throws
    func setLocation(target: SimulatorCommandTarget, latitude: String, longitude: String) async throws
    func runGPX(target: SimulatorCommandTarget, gpxPath: String) async throws
    func setAppearance(target: SimulatorCommandTarget, mode: AppearanceMode) async throws
    func setContentSize(target: SimulatorCommandTarget, size: ContentSizeCategory) async throws
    func setAccessibility(target: SimulatorCommandTarget, key: AccessibilityOverride, enabled: Bool) async throws
    func setLanguageAndLocale(target: SimulatorCommandTarget, languageCode: String, localeIdentifier: String) async throws
    func triggeriCloudSync(target: SimulatorCommandTarget) async throws
    func resetKeychain(target: SimulatorCommandTarget) async throws
    func setPrivacy(target: SimulatorCommandTarget, bundleID: String, service: PrivacyService, grant: Bool) async throws
    func sendPush(target: SimulatorCommandTarget, bundleID: String, apnsPath: String) async throws
    func openDeepLink(target: SimulatorCommandTarget, value: String) async throws
    func overrideStatusBar(target: SimulatorCommandTarget, value: StatusBarOverride) async throws
    func clearStatusBar(target: SimulatorCommandTarget) async throws
    func copyClipboard(target: SimulatorCommandTarget, value: String) async throws
    func pasteClipboard(target: SimulatorCommandTarget) async throws -> String
}

protocol LogOperationsManaging {
    func start(target: SimulatorCommandTarget, bundleID: String?) async -> SimctlLogStream
    func stop(streamID: UUID) async
}

protocol SimulatorRouting {
    func openFolder(path: String) throws
    func copyToClipboard(_ value: String)
    func pickFile(allowedFileTypes: [String]) async -> String?
    func pickFolder() async -> String?
    func savePanel(defaultName: String, allowedFileTypes: [String]) async -> String?
}

enum SimulatorFeatureError: LocalizedError {
    case commandFailed(String)
    case invalidSimulatorResponse

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .invalidSimulatorResponse:
            return "The simulator command returned an unexpected response."
        }
    }
}
