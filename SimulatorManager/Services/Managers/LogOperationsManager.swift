import Foundation

actor LogOperationsManager: LogOperationsManaging {
    private let simulatorService: SimulatorServiceing

    init(simulatorService: SimulatorServiceing) {
        self.simulatorService = simulatorService
    }

    func start(target: SimulatorCommandTarget, bundleID: String?) async -> SimctlLogStream {
        await simulatorService.logs(simulatorUDID: target.simulatorID, bundleID: bundleID)
    }

    func stop(streamID: UUID) async {
        await simulatorService.stopLogs(streamID: streamID)
    }
}
