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
        let stagedFilePath = try stageMediaFile(at: filePath)
        defer {
            try? FileManager.default.removeItem(atPath: stagedFilePath)
        }
        // addmedia is more reliable when the destination simulator is booted.
        try await simulatorService.boot(udid: target.simulatorID)
        try await simulatorService.addMedia(simulatorUDID: target.simulatorID, filePath: stagedFilePath)
    }

    private func stageMediaFile(at sourcePath: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let fileManager = FileManager.default
        let stagingRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SimulatorManager-Media", isDirectory: true)

        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

        let destinationURL = stagingRoot
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }
}
