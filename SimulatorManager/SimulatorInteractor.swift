import Foundation

actor SimctlService: SimctlServiceing {
    private var simulatorCache: (devices: [SimulatorDevice], timestamp: Date)?
    private var recordingProcesses: [String: Process] = [:]
    private var logProcesses: [UUID: Process] = [:]

    func run(command: [String]) async throws -> String {
        let result = try await execute(executablePath: "/usr/bin/xcrun", arguments: ["simctl"] + command)
        guard result.terminationStatus == 0 else {
            throw mapFailure(stderr: result.error, fallback: "simctl command failed.")
        }
        return result.output
    }

    func runJSON<T: Decodable>(command: [String], as type: T.Type) async throws -> T {
        let output = try await run(command: command)
        let data = Data(output.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    func listSimulators() async throws -> [SimulatorDevice] {
        if let simulatorCache, Date().timeIntervalSince(simulatorCache.timestamp) < 3 {
            return simulatorCache.devices
        }

        let response: SimulatorDeviceResponse = try await runJSON(command: ["list", "devices", "--json"], as: SimulatorDeviceResponse.self)
        let devices = response.devices
            .flatMap { runtimeIdentifier, devices in
                devices.map { device in
                    let dates = simulatorDates(for: device.udid)
                    return SimulatorDevice(
                        id: device.udid,
                        name: device.name,
                        runtimeIdentifier: runtimeIdentifier,
                        state: device.state,
                        isAvailable: device.isAvailable ?? false,
                        availabilityError: device.availabilityError,
                        deviceTypeIdentifier: device.deviceTypeIdentifier,
                        createdAt: dates.createdAt,
                        lastUsedAt: dates.lastUsedAt
                    )
                }
            }
            .sorted(by: sortOrder)
        simulatorCache = (devices, Date())
        return devices
    }

    func boot(udid: String) async throws {
        _ = try await runSimctl(command: ["boot", udid], allowKnownFailure: true)
    }

    func shutdown(udid: String) async throws {
        _ = try await runSimctl(command: ["shutdown", udid], allowKnownFailure: true)
    }

    func erase(udid: String) async throws {
        _ = try await runSimctl(command: ["erase", udid])
    }

    func openSimulator(udid: String) async throws {
        try await boot(udid: udid)
        let result = try await execute(executablePath: "/usr/bin/open", arguments: ["-a", "Simulator", "--args", "-CurrentDeviceUDID", udid])
        guard result.terminationStatus == 0 else {
            throw mapFailure(stderr: result.error, fallback: "Unable to open Simulator app.")
        }
    }

    func installApp(path: String, simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["install", simulatorUDID, path])
    }

    func uninstallApp(bundleID: String, simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["uninstall", simulatorUDID, bundleID])
    }

    func launchApp(bundleID: String, simulatorUDID: String) async throws {
        try await boot(udid: simulatorUDID)
        _ = try await runSimctl(command: ["launch", simulatorUDID, bundleID])
    }

    func terminateApp(bundleID: String, simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["terminate", simulatorUDID, bundleID], allowKnownFailure: true)
    }

    func reinstallApp(path: String, bundleID: String, simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["uninstall", simulatorUDID, bundleID], allowKnownFailure: true)
        _ = try await runSimctl(command: ["install", simulatorUDID, path])
    }

    func appContainer(bundleID: String, simulatorUDID: String) async throws -> String {
        try await appContainer(bundleID: bundleID, simulatorUDID: simulatorUDID, kind: .data)
    }

    func appContainer(bundleID: String, simulatorUDID: String, kind: AppContainerKind) async throws -> String {
        let output = try await runSimctl(command: ["get_app_container", simulatorUDID, bundleID, kind.rawValue])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func pushFile(simulatorUDID: String, bundleID: String, localPath: String, remotePath: String) async throws {
        _ = try await runSimctl(command: ["push", simulatorUDID, bundleID, localPath, remotePath])
    }

    func addMedia(simulatorUDID: String, filePath: String) async throws {
        _ = try await runSimctl(command: ["addmedia", simulatorUDID, filePath])
    }

    func takeScreenshot(simulatorUDID: String, outputPath: String) async throws {
        _ = try await runSimctl(command: ["io", simulatorUDID, "screenshot", outputPath])
    }

    func startVideoRecording(simulatorUDID: String, outputPath: String) async throws {
        if let existing = recordingProcesses[simulatorUDID], existing.isRunning {
            throw SimulatorFeatureError.commandFailed("A recording is already running for this simulator.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "io", simulatorUDID, "recordVideo", outputPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.terminationHandler = { [simulatorUDID] _ in
            Task {
                await self.clearRecordingProcess(simulatorUDID: simulatorUDID)
            }
        }
        try process.run()
        recordingProcesses[simulatorUDID] = process
    }

    func stopVideoRecording(simulatorUDID: String) async throws {
        guard let process = recordingProcesses[simulatorUDID], process.isRunning else {
            throw SimulatorFeatureError.commandFailed("No active recording for the selected simulator.")
        }
        process.terminate()
        _ = await waitForProcess(process)
        recordingProcesses[simulatorUDID] = nil
    }

    func setLocation(simulatorUDID: String, latitude: String, longitude: String) async throws {
        _ = try await runSimctl(command: ["location", simulatorUDID, "set", latitude, longitude])
    }

    func runLocationGPX(simulatorUDID: String, gpxPath: String) async throws {
        _ = try await runSimctl(command: ["location", simulatorUDID, "run", gpxPath])
    }

    func setAppearance(simulatorUDID: String, mode: AppearanceMode) async throws {
        _ = try await runSimctl(command: ["ui", simulatorUDID, "appearance", mode.rawValue])
    }

    func setContentSize(simulatorUDID: String, size: ContentSizeCategory) async throws {
        _ = try await runSimctl(command: ["ui", simulatorUDID, "content_size", size.simctlValue])
    }

    func setAccessibility(simulatorUDID: String, key: AccessibilityOverride, enabled: Bool) async throws {
        let value = enabled ? "TRUE" : "FALSE"
        _ = try await runSimctl(
            command: [
                "spawn",
                simulatorUDID,
                "defaults",
                "write",
                "com.apple.Accessibility",
                key.rawValue,
                "-bool",
                value
            ]
        )
    }

    func setLanguageAndLocale(simulatorUDID: String, languageCode: String, localeIdentifier: String) async throws {
        let sanitizedLanguage = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedLocale = localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedLanguage.isEmpty, !sanitizedLocale.isEmpty else {
            throw SimulatorFeatureError.commandFailed("Language and locale are required.")
        }
        _ = try await runSimctl(
            command: ["spawn", simulatorUDID, "defaults", "write", ".GlobalPreferences", "AppleLanguages", "-array", sanitizedLanguage]
        )
        _ = try await runSimctl(
            command: ["spawn", simulatorUDID, "defaults", "write", ".GlobalPreferences", "AppleLocale", "-string", sanitizedLocale]
        )
    }

    func triggeriCloudSync(simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["icloud_sync", simulatorUDID])
    }

    func resetKeychain(simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["keychain", simulatorUDID, "reset"])
    }

    func setPrivacy(simulatorUDID: String, bundleID: String, service: PrivacyService, grant: Bool) async throws {
        let command = grant ? "grant" : "revoke"
        _ = try await runSimctl(command: ["privacy", simulatorUDID, command, service.rawValue, bundleID])
    }

    func sendPush(simulatorUDID: String, bundleID: String, apnsFilePath: String) async throws {
        _ = try await runSimctl(command: ["push", simulatorUDID, bundleID, apnsFilePath])
    }

    func openURL(simulatorUDID: String, url: String) async throws {
        _ = try await runSimctl(command: ["openurl", simulatorUDID, url])
    }

    func overrideStatusBar(simulatorUDID: String, value: StatusBarOverride) async throws {
        var args = ["status_bar", simulatorUDID, "override"]
        if let time = value.time, !time.isEmpty {
            args += ["--time", time]
        }
        if let dataNetwork = value.dataNetwork {
            args += ["--dataNetwork", dataNetwork.rawValue]
        }
        if let wifiMode = value.wifiMode {
            args += ["--wifiMode", wifiMode.rawValue]
        }
        if let batteryLevel = value.batteryLevel {
            args += ["--batteryLevel", "\(batteryLevel)"]
        }
        if let batteryState = value.batteryState {
            args += ["--batteryState", batteryState.rawValue]
        }
        if let wifiBars = value.wifiBars {
            args += ["--wifiBars", "\(wifiBars)"]
        }
        if let cellularMode = value.cellularMode {
            args += ["--cellularMode", cellularMode.rawValue]
        }
        if let cellularBars = value.cellularBars {
            args += ["--cellularBars", "\(cellularBars)"]
        }
        if let operatorName = value.operatorName?.trimmingCharacters(in: .whitespacesAndNewlines), !operatorName.isEmpty {
            args += ["--operatorName", operatorName]
        }
        _ = try await runSimctl(command: args)
    }

    func clearStatusBar(simulatorUDID: String) async throws {
        _ = try await runSimctl(command: ["status_bar", simulatorUDID, "clear"])
    }

    func pbcopy(simulatorUDID: String, value: String) async throws {
        let result = try await execute(executablePath: "/usr/bin/xcrun", arguments: ["simctl", "pbcopy", simulatorUDID], stdin: value)
        guard result.terminationStatus == 0 else {
            throw mapFailure(stderr: result.error, fallback: "Unable to copy text to simulator clipboard.")
        }
    }

    func pbpaste(simulatorUDID: String) async throws -> String {
        let output = try await runSimctl(command: ["pbpaste", simulatorUDID])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func logs(simulatorUDID: String, bundleID: String?) async -> SimctlLogStream {
        let id = UUID()
        let stream = AsyncThrowingStream<String, Error> { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            var args = ["simctl", "spawn", simulatorUDID, "log", "stream", "--style", "compact"]
            if let bundleID, !bundleID.isEmpty {
                args += ["--predicate", "senderImagePath contains \"\(bundleID)\""]
            }
            process.arguments = args
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var buffer = ""
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let chunk = String(decoding: data, as: UTF8.self)
                buffer.append(chunk)
                let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                if !buffer.hasSuffix("\n"), let last = lines.last {
                    buffer = last
                    for line in lines.dropLast() {
                        continuation.yield(line)
                    }
                } else {
                    buffer = ""
                    for line in lines where !line.isEmpty {
                        continuation.yield(line)
                    }
                }
            }

            process.terminationHandler = { _ in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                if !buffer.isEmpty {
                    continuation.yield(buffer)
                }
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                if stderr.isEmpty {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: SimulatorFeatureError.commandFailed(stderr))
                }
                Task {
                    await self.stopLogs(streamID: id)
                }
            }

            do {
                try process.run()
                Task {
                    await self.storeLogProcess(id: id, process: process)
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return SimctlLogStream(id: id, lines: stream)
    }

    func stopLogs(streamID: UUID) {
        guard let process = logProcesses[streamID] else {
            return
        }
        if process.isRunning {
            process.terminate()
        }
        logProcesses[streamID] = nil
    }

    private func sortOrder(lhs: SimulatorDevice, rhs: SimulatorDevice) -> Bool {
        if lhs.isAvailable != rhs.isAvailable {
            return lhs.isAvailable && !rhs.isAvailable
        }
        if lhs.isBooted != rhs.isBooted {
            return lhs.isBooted && !rhs.isBooted
        }
        if lhs.runtimeName != rhs.runtimeName {
            return lhs.runtimeName < rhs.runtimeName
        }
        return lhs.name < rhs.name
    }

    private func simulatorDates(for udid: String) -> (createdAt: Date?, lastUsedAt: Date?) {
        let deviceFolderPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices")
            .appendingPathComponent(udid)
            .path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: deviceFolderPath) else {
            return (nil, nil)
        }
        return (
            attributes[.creationDate] as? Date,
            attributes[.modificationDate] as? Date
        )
    }

    private func runSimctl(command: [String], allowKnownFailure: Bool = false) async throws -> String {
        let result = try await execute(executablePath: "/usr/bin/xcrun", arguments: ["simctl"] + command)
        if allowKnownFailure && result.terminationStatus != 0 {
            let lowerError = result.error.lowercased()
            let knownMessages = [
                "current state: booted",
                "unable to shutdown device in current state",
                "found nothing to terminate",
                "not installed",
                "already shutdown"
            ]
            if knownMessages.contains(where: { lowerError.contains($0) }) {
                return result.output
            }
        }
        guard result.terminationStatus == 0 else {
            throw mapFailure(stderr: result.error, fallback: "Simulator command failed.")
        }
        return result.output
    }

    private func execute(executablePath: String, arguments: [String], stdin: String? = nil) async throws -> SimctlExecutionResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        if stdin != nil {
            let standardInput = Pipe()
            process.standardInput = standardInput
            standardInput.fileHandleForWriting.write(Data((stdin ?? "").utf8))
            try? standardInput.fileHandleForWriting.close()
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let output = String(decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let error = String(decoding: standardError.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                continuation.resume(returning: SimctlExecutionResult(output: output, error: error, terminationStatus: process.terminationStatus))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func mapFailure(stderr: String, fallback: String) -> SimulatorFeatureError {
        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return .commandFailed(message.isEmpty ? fallback : message)
    }

    private func waitForProcess(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            if !process.isRunning {
                continuation.resume(returning: process.terminationStatus)
                return
            }
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
        }
    }

    private func clearRecordingProcess(simulatorUDID: String) {
        recordingProcesses[simulatorUDID] = nil
    }

    private func storeLogProcess(id: UUID, process: Process) {
        logProcesses[id] = process
    }
}

actor SimulatorService: SimulatorServiceing {
    private let simctlService: SimctlServiceing

    init(simctlService: SimctlServiceing) {
        self.simctlService = simctlService
    }

    func allSimulators() async throws -> [SimulatorDevice] {
        try await simctlService.listSimulators()
    }

    func boot(udid: String) async throws {
        try await simctlService.boot(udid: udid)
    }

    func shutdown(udid: String) async throws {
        try await simctlService.shutdown(udid: udid)
    }

    func erase(udid: String) async throws {
        try await simctlService.erase(udid: udid)
    }

    func openInSimulator(udid: String) async throws {
        try await simctlService.openSimulator(udid: udid)
    }

    func installApp(path: String, simulatorUDID: String) async throws {
        try await simctlService.installApp(path: path, simulatorUDID: simulatorUDID)
    }

    func uninstallApp(bundleID: String, simulatorUDID: String) async throws {
        try await simctlService.uninstallApp(bundleID: bundleID, simulatorUDID: simulatorUDID)
    }

    func launchApp(bundleID: String, simulatorUDID: String) async throws {
        try await simctlService.launchApp(bundleID: bundleID, simulatorUDID: simulatorUDID)
    }

    func terminateApp(bundleID: String, simulatorUDID: String) async throws {
        try await simctlService.terminateApp(bundleID: bundleID, simulatorUDID: simulatorUDID)
    }

    func reinstallApp(path: String, bundleID: String, simulatorUDID: String) async throws {
        try await simctlService.reinstallApp(path: path, bundleID: bundleID, simulatorUDID: simulatorUDID)
    }

    func appContainer(bundleID: String, simulatorUDID: String) async throws -> String {
        try await simctlService.appContainer(bundleID: bundleID, simulatorUDID: simulatorUDID)
    }

    func appContainer(bundleID: String, simulatorUDID: String, kind: AppContainerKind) async throws -> String {
        try await simctlService.appContainer(bundleID: bundleID, simulatorUDID: simulatorUDID, kind: kind)
    }

    func pushFile(simulatorUDID: String, bundleID: String, localPath: String, remotePath: String) async throws {
        try await simctlService.pushFile(simulatorUDID: simulatorUDID, bundleID: bundleID, localPath: localPath, remotePath: remotePath)
    }

    func addMedia(simulatorUDID: String, filePath: String) async throws {
        try await simctlService.addMedia(simulatorUDID: simulatorUDID, filePath: filePath)
    }

    func takeScreenshot(simulatorUDID: String, outputPath: String) async throws {
        try await simctlService.takeScreenshot(simulatorUDID: simulatorUDID, outputPath: outputPath)
    }

    func startVideoRecording(simulatorUDID: String, outputPath: String) async throws {
        try await simctlService.startVideoRecording(simulatorUDID: simulatorUDID, outputPath: outputPath)
    }

    func stopVideoRecording(simulatorUDID: String) async throws {
        try await simctlService.stopVideoRecording(simulatorUDID: simulatorUDID)
    }

    func setLocation(simulatorUDID: String, latitude: String, longitude: String) async throws {
        try await simctlService.setLocation(simulatorUDID: simulatorUDID, latitude: latitude, longitude: longitude)
    }

    func runLocationGPX(simulatorUDID: String, gpxPath: String) async throws {
        try await simctlService.runLocationGPX(simulatorUDID: simulatorUDID, gpxPath: gpxPath)
    }

    func setAppearance(simulatorUDID: String, mode: AppearanceMode) async throws {
        try await simctlService.setAppearance(simulatorUDID: simulatorUDID, mode: mode)
    }

    func setContentSize(simulatorUDID: String, size: ContentSizeCategory) async throws {
        try await simctlService.setContentSize(simulatorUDID: simulatorUDID, size: size)
    }

    func setAccessibility(simulatorUDID: String, key: AccessibilityOverride, enabled: Bool) async throws {
        try await simctlService.setAccessibility(simulatorUDID: simulatorUDID, key: key, enabled: enabled)
    }

    func setLanguageAndLocale(simulatorUDID: String, languageCode: String, localeIdentifier: String) async throws {
        try await simctlService.setLanguageAndLocale(simulatorUDID: simulatorUDID, languageCode: languageCode, localeIdentifier: localeIdentifier)
    }

    func triggeriCloudSync(simulatorUDID: String) async throws {
        try await simctlService.triggeriCloudSync(simulatorUDID: simulatorUDID)
    }

    func resetKeychain(simulatorUDID: String) async throws {
        try await simctlService.resetKeychain(simulatorUDID: simulatorUDID)
    }

    func setPrivacy(simulatorUDID: String, bundleID: String, service: PrivacyService, grant: Bool) async throws {
        try await simctlService.setPrivacy(simulatorUDID: simulatorUDID, bundleID: bundleID, service: service, grant: grant)
    }

    func sendPush(simulatorUDID: String, bundleID: String, apnsFilePath: String) async throws {
        try await simctlService.sendPush(simulatorUDID: simulatorUDID, bundleID: bundleID, apnsFilePath: apnsFilePath)
    }

    func openURL(simulatorUDID: String, url: String) async throws {
        try await simctlService.openURL(simulatorUDID: simulatorUDID, url: url)
    }

    func overrideStatusBar(simulatorUDID: String, value: StatusBarOverride) async throws {
        try await simctlService.overrideStatusBar(simulatorUDID: simulatorUDID, value: value)
    }

    func clearStatusBar(simulatorUDID: String) async throws {
        try await simctlService.clearStatusBar(simulatorUDID: simulatorUDID)
    }

    func pbcopy(simulatorUDID: String, value: String) async throws {
        try await simctlService.pbcopy(simulatorUDID: simulatorUDID, value: value)
    }

    func pbpaste(simulatorUDID: String) async throws -> String {
        try await simctlService.pbpaste(simulatorUDID: simulatorUDID)
    }

    func logs(simulatorUDID: String, bundleID: String?) async -> SimctlLogStream {
        await simctlService.logs(simulatorUDID: simulatorUDID, bundleID: bundleID)
    }

    func stopLogs(streamID: UUID) async {
        await simctlService.stopLogs(streamID: streamID)
    }
}

actor AppScannerService: AppScannerServiceing {
    private var cache: AppScanSnapshot?

    func scanApps(simulators: [SimulatorDevice], forceRefresh: Bool) async throws -> AppScanSnapshot {
        if let cache, !forceRefresh {
            return cache
        }

        let snapshot = try scan(simulators: simulators)
        cache = snapshot
        return snapshot
    }

    private func scan(simulators: [SimulatorDevice]) throws -> AppScanSnapshot {
        let simulatorsByID = Dictionary(uniqueKeysWithValues: simulators.map { ($0.id, $0) })
        let fileManager = FileManager.default
        let devicesRoot = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        let dataContainers = indexDataContainers(devicesRoot: devicesRoot, simulatorIDs: Set(simulatorsByID.keys))
        guard let enumerator = fileManager.enumerator(at: devicesRoot, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            return AppScanSnapshot(apps: [], scannedAt: Date())
        }

        var aggregate: [String: MutableIndexedApp] = [:]

        for case let appURL as URL in enumerator {
            guard appURL.pathExtension == "app" else {
                continue
            }
            guard appURL.path.contains("/data/Containers/Bundle/Application/") else {
                continue
            }

            let pathComponents = appURL.pathComponents
            guard let devicesIndex = pathComponents.firstIndex(of: "Devices"), pathComponents.indices.contains(devicesIndex + 1) else {
                continue
            }
            let simulatorID = pathComponents[devicesIndex + 1]
            guard let simulator = simulatorsByID[simulatorID] else {
                continue
            }

            let appInfo = readAppInfo(at: appURL)
            guard !appInfo.bundleIdentifier.isEmpty else {
                continue
            }
            let dataContainer = dataContainers[containerKey(simulatorID: simulatorID, bundleID: appInfo.bundleIdentifier)]

            var entry = aggregate[appInfo.bundleIdentifier] ?? MutableIndexedApp(
                name: appInfo.displayName,
                bundleID: appInfo.bundleIdentifier,
                version: appInfo.version,
                build: appInfo.build,
                bundlePath: appURL.path,
                installDate: appInfo.installDate,
                sizeInBytes: appInfo.size,
                installedOn: []
            )

            entry.installedOn.append(
                InstalledOnSimulator(
                    simulatorID: simulator.id,
                    simulatorName: simulator.name,
                    osVersion: simulator.osVersion,
                    state: simulator.state,
                    bundlePath: appURL.path,
                    dataPath: dataContainer?.dataPath,
                    documentsPath: dataContainer?.documentsPath,
                    indexedFileNames: dataContainer?.indexedFileNames ?? []
                )
            )
            if let version = appInfo.version, !version.isEmpty {
                entry.version = version
            }
            if let build = appInfo.build, !build.isEmpty {
                entry.build = build
            }
            entry.name = appInfo.displayName
            entry.bundlePath = appURL.path
            entry.installDate = appInfo.installDate ?? entry.installDate
            entry.sizeInBytes = appInfo.size ?? entry.sizeInBytes
            aggregate[appInfo.bundleIdentifier] = entry
        }

        let apps = aggregate.values.map { mutable in
            IndexedApp(
                name: mutable.name,
                bundleID: mutable.bundleID,
                version: mutable.version,
                build: mutable.build,
                bundlePath: mutable.bundlePath,
                installDate: mutable.installDate,
                sizeInBytes: mutable.sizeInBytes,
                installedOn: mutable.installedOn.sorted { lhs, rhs in
                    if lhs.state != rhs.state {
                        return lhs.state == "Booted"
                    }
                    return lhs.simulatorName < rhs.simulatorName
                }
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return AppScanSnapshot(apps: apps, scannedAt: Date())
    }

    private func indexDataContainers(devicesRoot: URL, simulatorIDs: Set<String>) -> [String: DataContainerInfo] {
        let fileManager = FileManager.default
        var mapping: [String: DataContainerInfo] = [:]

        for simulatorID in simulatorIDs {
            let appContainersRoot = devicesRoot
                .appendingPathComponent(simulatorID)
                .appendingPathComponent("data/Containers/Data/Application")
            guard let containerFolders = try? fileManager.contentsOfDirectory(
                at: appContainersRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for containerFolder in containerFolders {
                let metadataURL = containerFolder.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                guard
                    let data = try? Data(contentsOf: metadataURL),
                    let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                    let bundleID = (plist["MCMMetadataIdentifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !bundleID.isEmpty
                else {
                    continue
                }

                let documentsURL = containerFolder.appendingPathComponent("Documents")
                let documentsPath = fileManager.fileExists(atPath: documentsURL.path) ? documentsURL.path : nil
                let indexedFileNames = sampleFileNames(root: containerFolder, maxFiles: 220)
                let key = containerKey(simulatorID: simulatorID, bundleID: bundleID)

                if mapping[key] == nil {
                    mapping[key] = DataContainerInfo(
                        dataPath: containerFolder.path,
                        documentsPath: documentsPath,
                        indexedFileNames: indexedFileNames
                    )
                }
            }
        }

        return mapping
    }

    private func sampleFileNames(root: URL, maxFiles: Int) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var names: [String] = []
        names.reserveCapacity(maxFiles)

        for case let fileURL as URL in enumerator {
            guard names.count < maxFiles else {
                break
            }
            let fileName = fileURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fileName.isEmpty else {
                continue
            }
            names.append(fileName.lowercased())
        }

        return names
    }

    private func containerKey(simulatorID: String, bundleID: String) -> String {
        "\(simulatorID)|\(bundleID.lowercased())"
    }

    private func readAppInfo(at appURL: URL) -> AppInfo {
        let plistURL = appURL.appendingPathComponent("Info.plist")
        let attributes = try? FileManager.default.attributesOfItem(atPath: appURL.path)
        let installDate = attributes?[.modificationDate] as? Date
        let size = attributes?[.size] as? NSNumber

        guard
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return AppInfo(
                displayName: appURL.deletingPathExtension().lastPathComponent,
                bundleIdentifier: "",
                version: nil,
                build: nil,
                installDate: installDate,
                size: size?.int64Value
            )
        }

        let displayName = ((plist["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines))
        let bundleName = ((plist["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines))
        let bundleIdentifier = ((plist["CFBundleIdentifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        let version = (plist["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (plist["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedDisplayName: String
        if let displayName, !displayName.isEmpty {
            resolvedDisplayName = displayName
        } else if let bundleName, !bundleName.isEmpty {
            resolvedDisplayName = bundleName
        } else {
            resolvedDisplayName = appURL.deletingPathExtension().lastPathComponent
        }

        return AppInfo(
            displayName: resolvedDisplayName,
            bundleIdentifier: bundleIdentifier,
            version: version,
            build: build,
            installDate: installDate,
            size: size?.int64Value
        )
    }
}

private struct SimulatorDeviceResponse: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool?
    let availabilityError: String?
    let deviceTypeIdentifier: String?
}

private struct AppInfo {
    let displayName: String
    let bundleIdentifier: String
    let version: String?
    let build: String?
    let installDate: Date?
    let size: Int64?
}

private struct MutableIndexedApp {
    var name: String
    let bundleID: String
    var version: String?
    var build: String?
    var bundlePath: String
    var installDate: Date?
    var sizeInBytes: Int64?
    var installedOn: [InstalledOnSimulator]
}

private struct DataContainerInfo {
    let dataPath: String
    let documentsPath: String?
    let indexedFileNames: [String]
}

private struct SimctlExecutionResult {
    let output: String
    let error: String
    let terminationStatus: Int32
}
