import Foundation

actor DataOperationsManager: DataOperationsManaging {
    private let simulatorService: SimulatorServiceing

    init(simulatorService: SimulatorServiceing) {
        self.simulatorService = simulatorService
    }

    func openContainer(bundleID: String, target: SimulatorCommandTarget, kind: AppContainerKind) async throws -> String {
        try await simulatorService.appContainer(bundleID: bundleID, simulatorUDID: target.simulatorID, kind: kind)
    }

    func pushFile(bundleID: String, target: SimulatorCommandTarget, localPath: String, remotePath: String) async throws {
        try await simulatorService.pushFile(simulatorUDID: target.simulatorID, bundleID: bundleID, localPath: localPath, remotePath: remotePath)
    }

    func addMedia(target: SimulatorCommandTarget, filePath: String) async throws {
        try await simulatorService.addMedia(simulatorUDID: target.simulatorID, filePath: filePath)
    }
}
