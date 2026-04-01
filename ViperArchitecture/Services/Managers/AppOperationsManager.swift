import Foundation

actor AppOperationsManager: AppOperationsManaging {
    private let simulatorService: SimulatorServiceing

    init(simulatorService: SimulatorServiceing) {
        self.simulatorService = simulatorService
    }

    func launch(bundleID: String, target: SimulatorCommandTarget) async throws {
        try await simulatorService.openInSimulator(udid: target.simulatorID)
        try await simulatorService.launchApp(bundleID: bundleID, simulatorUDID: target.simulatorID)
    }

    func terminate(bundleID: String, target: SimulatorCommandTarget) async throws {
        try await simulatorService.terminateApp(bundleID: bundleID, simulatorUDID: target.simulatorID)
    }

    func install(path: String, target: SimulatorCommandTarget) async throws {
        try await simulatorService.installApp(path: path, simulatorUDID: target.simulatorID)
    }

    func uninstall(bundleID: String, target: SimulatorCommandTarget) async throws {
        try await simulatorService.uninstallApp(bundleID: bundleID, simulatorUDID: target.simulatorID)
    }

    func reinstall(path: String, bundleID: String, target: SimulatorCommandTarget) async throws {
        try await simulatorService.reinstallApp(path: path, bundleID: bundleID, simulatorUDID: target.simulatorID)
    }
}
