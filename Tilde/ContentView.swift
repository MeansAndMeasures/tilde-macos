// Copyright (C) 2026 Means+Measures LLC. GPL-3.0-or-later.
import AppKit
import SwiftTerm

final class EditorWindow: NSWindowController, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    private let surface: LocalProcessTerminalView
    private let executable: String
    private let file: URL?
    private(set) var isRunning = false
    var onClose: (() -> Void)?
    init(file: URL?) throws {
        let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
        let executable = contents.appendingPathComponent("Helpers/tilde").path
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw NSError(domain: "Tilde", code: 1, userInfo: [NSLocalizedDescriptionKey: "The app’s embedded editor is missing. Rebuild Tilde.app before launching it."])
        }
        self.executable = executable; self.file = file
        let rect = NSRect(x: 0, y: 0, width: 1000, height: 680)
        surface = LocalProcessTerminalView(frame: rect)
        surface.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = file?.lastPathComponent ?? "Untitled — Tilde"
        window.representedURL = file
        window.contentView = surface
        window.minSize = NSSize(width: 480, height: 300)
        window.center()
        super.init(window: window)
        window.delegate = self; surface.processDelegate = self
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    func start() {
        isRunning = true
        window?.makeFirstResponder(surface)
        surface.startProcess(executable: executable, args: file.map { [$0.path] } ?? [],
                             currentDirectory: file?.deletingLastPathComponent().path ?? NSHomeDirectory())
    }
    func stop() { if isRunning { surface.terminate(); isRunning = false } }
    func save() { if isRunning { surface.send(txt: "\u{13}") } }
    func requestClose() { if isRunning { surface.send(txt: "\u{11}") } }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isRunning {
            requestClose()
            return false
        }
        return true
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            if exitCode == 0 { self.window?.close() }
            else { self.window?.title = "Tilde — editor exited (\(exitCode.map(String.init) ?? "unknown"))" }
        }
    }
}
