import AppKit
import UniformTypeIdentifiers

actor SimulatorRouter: SimulatorRouting {
    @MainActor
    func openFolder(path: String) throws {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @MainActor
    func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @MainActor
    func pickFile(allowedFileTypes: [String]) async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }

    @MainActor
    func pickFolder() async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }

    @MainActor
    func savePanel(defaultName: String, allowedFileTypes: [String]) async -> String? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }
}
