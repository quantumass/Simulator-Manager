import Foundation

actor TestingOperationsManager: TestingOperationsManaging {
    private let simulatorService: SimulatorServiceing

    init(simulatorService: SimulatorServiceing) {
        self.simulatorService = simulatorService
    }

    func screenshot(target: SimulatorCommandTarget, path: String) async throws {
        try await simulatorService.takeScreenshot(simulatorUDID: target.simulatorID, outputPath: path)
    }

    func startRecording(target: SimulatorCommandTarget, path: String) async throws {
        try await simulatorService.startVideoRecording(simulatorUDID: target.simulatorID, outputPath: path)
    }

    func stopRecording(target: SimulatorCommandTarget) async throws {
        try await simulatorService.stopVideoRecording(simulatorUDID: target.simulatorID)
    }

    func setLocation(target: SimulatorCommandTarget, latitude: String, longitude: String) async throws {
        try await simulatorService.setLocation(simulatorUDID: target.simulatorID, latitude: latitude, longitude: longitude)
    }

    func runGPX(target: SimulatorCommandTarget, gpxPath: String) async throws {
        try await simulatorService.runLocationGPX(simulatorUDID: target.simulatorID, gpxPath: gpxPath)
    }

    func setAppearance(target: SimulatorCommandTarget, mode: AppearanceMode) async throws {
        try await simulatorService.setAppearance(simulatorUDID: target.simulatorID, mode: mode)
    }

    func setPrivacy(target: SimulatorCommandTarget, bundleID: String, service: PrivacyService, grant: Bool) async throws {
        try await simulatorService.setPrivacy(simulatorUDID: target.simulatorID, bundleID: bundleID, service: service, grant: grant)
    }

    func sendPush(target: SimulatorCommandTarget, bundleID: String, apnsPath: String) async throws {
        try await simulatorService.sendPush(simulatorUDID: target.simulatorID, bundleID: bundleID, apnsFilePath: apnsPath)
    }

    func openDeepLink(target: SimulatorCommandTarget, value: String) async throws {
        try await simulatorService.openURL(simulatorUDID: target.simulatorID, url: value)
    }

    func overrideStatusBar(target: SimulatorCommandTarget, value: StatusBarOverride) async throws {
        try await simulatorService.overrideStatusBar(simulatorUDID: target.simulatorID, value: value)
    }

    func clearStatusBar(target: SimulatorCommandTarget) async throws {
        try await simulatorService.clearStatusBar(simulatorUDID: target.simulatorID)
    }

    func copyClipboard(target: SimulatorCommandTarget, value: String) async throws {
        try await simulatorService.pbcopy(simulatorUDID: target.simulatorID, value: value)
    }

    func pasteClipboard(target: SimulatorCommandTarget) async throws -> String {
        try await simulatorService.pbpaste(simulatorUDID: target.simulatorID)
    }
}
