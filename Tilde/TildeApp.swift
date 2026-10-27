	// Copyright (C) 2026 Means+Measures LLC. GPL-3.0-or-later.
	import AppKit

	@main
	final class TildeApp: NSObject, NSApplicationDelegate {
		private var editors: [EditorWindow] = []

		static func main() {
			let app = NSApplication.shared
			let delegate = TildeApp()
			app.delegate = delegate
			app.servicesProvider = delegate
			app.setActivationPolicy(.regular)
			withExtendedLifetime(delegate) { app.run() }
		}

		func applicationDidFinishLaunching(_ notification: Notification) {
			let main = NSMenu()
			let appMenu = NSMenu()
			appMenu.addItem(
				withTitle: "Quit Tilde",
				action: #selector(NSApplication.terminate(_:)),
				keyEquivalent: "q"
			)

			let appItem = NSMenuItem()
			appItem.submenu = appMenu
			main.addItem(appItem)

			let file = NSMenu(title: "File")
			file.addItem(
				withTitle: "New",
				action: #selector(newDocument(_:)),
				keyEquivalent: "n"
			).target = self
			file.addItem(
				withTitle: "Open…",
				action: #selector(openDocument(_:)),
				keyEquivalent: "o"
			).target = self
			file.addItem(
				withTitle: "Save",
				action: #selector(saveDocument(_:)),
				keyEquivalent: "s"
			).target = self
			file.addItem(
				withTitle: "Close",
				action: #selector(NSWindow.performClose(_:)),
				keyEquivalent: "w"
			)

			let fileItem = NSMenuItem(
				title: "File",
				action: nil,
				keyEquivalent: ""
			)
			fileItem.submenu = file
			main.addItem(fileItem)
			NSApp.mainMenu = main

			if editors.isEmpty {
				let paths = CommandLine.arguments.dropFirst().filter {
					!$0.hasPrefix("-psn_")
				}

				if paths.isEmpty {
					showEditor(nil)
				} else {
					paths.forEach {
						showEditor(URL(fileURLWithPath: $0))
					}
				}
			}

			NSApp.activate(ignoringOtherApps: true)
		}

		// Normal document opens and custom URL opens both arrive here.
		func application(_ sender: NSApplication, open urls: [URL]) {
			for url in urls {
				do {
					try openIncomingURL(url)
				} catch {
					sender.presentError(error)
				}
			}

			sender.activate(ignoringOtherApps: true)
		}

		private func openIncomingURL(_ url: URL) throws {
			if url.isFileURL {
				showEditor(url)
				return
			}

			guard let scheme = url.scheme?.lowercased(),
				  ["tilde-macos", "x-macos-tilde"].contains(scheme),
				  let components = URLComponents(
					  url: url,
					  resolvingAgainstBaseURL: false
				  ) else {
				throw invalidLink("Unsupported Tilde URL.")
			}

			switch components.host?.lowercased() {
			case "new":
				showEditor(nil)

			case "open":
				let paths = (components.queryItems ?? []).filter {
					$0.name == "path"
				}

				guard paths.count == 1,
					  let path = paths.first?.value,
					  path.hasPrefix("/"),
					  !path.contains("\u{0}") else {
					throw invalidLink(
						"An open URL must contain one absolute file path: " +
						"tilde-macos://open?path=/Users/you/document.txt"
					)
				}

				showEditor(URL(fileURLWithPath: path))

			default:
				throw invalidLink(
					"Use tilde-macos://new or " +
					"tilde-macos://open?path=/absolute/path."
				)
			}
		}

		private func invalidLink(_ message: String) -> NSError {
			NSError(
				domain: "Tilde.URL",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: message]
			)
		}

		// Finder Services → Open in Tilde.
		@objc(openInTilde:userData:error:)
		private func openInTilde(
			_ pasteboard: NSPasteboard,
			userData: String?,
			error: AutoreleasingUnsafeMutablePointer<NSString?>
		) {
			error.pointee = nil

			var files = (
				pasteboard.readObjects(
					forClasses: [NSURL.self],
					options: [.urlReadingFileURLsOnly: true]
				) as? [NSURL] ?? []
			).map { $0 as URL }

			if files.isEmpty,
			   let paths = pasteboard.propertyList(
				   forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
			   ) as? [String] {
				files = paths.map {
					URL(fileURLWithPath: $0)
				}
			}

			guard !files.isEmpty else {
				error.pointee =
					"Open in Tilde did not receive any files." as NSString
				return
			}

			files.forEach { showEditor($0) }
			NSApp.activate(ignoringOtherApps: true)
		}

		@objc private func newDocument(_ sender: Any?) {
			showEditor(nil)
		}

		@objc private func saveDocument(_ sender: Any?) {
			editors.first {
				$0.window === NSApp.keyWindow
			}?.save()
		}

		@objc private func openDocument(_ sender: Any?) {
			let panel = NSOpenPanel()
			panel.allowsMultipleSelection = true
			panel.canChooseDirectories = false

			if panel.runModal() == .OK {
				panel.urls.forEach { showEditor($0) }
			}
		}

		private func showEditor(_ file: URL?) {
			do {
				let editor = try EditorWindow(file: file)
				editor.onClose = { [weak self, weak editor] in
					self?.editors.removeAll { $0 === editor }
				}

				editors.append(editor)
				editor.showWindow(nil)
				editor.start()
			} catch {
				NSApp.presentError(error)
			}
		}

		func applicationShouldTerminate(
			_ sender: NSApplication
		) -> NSApplication.TerminateReply {
			if editors.contains(where: { $0.isRunning }) {
				editors.forEach { $0.requestClose() }
				return .terminateCancel
			}

			return .terminateNow
		}

		func applicationShouldTerminateAfterLastWindowClosed(
			_ sender: NSApplication
		) -> Bool {
			true
		}
	}
