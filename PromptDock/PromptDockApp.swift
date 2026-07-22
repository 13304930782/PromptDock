import AppKit
import SwiftUI
import SwiftData

private final class PromptDockAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldSaveSecureApplicationState(
        _ app: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldRestoreSecureApplicationState(
        _ app: NSApplication
    ) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Self.wasLaunchedAtLogin else { return }

        // A main-app login item still creates the SwiftUI WindowGroup during launch.
        // Hide that initial window after services have started so login remains quiet.
        DispatchQueue.main.async {
            NSApp.windows
                .filter { !($0 is NSPanel) }
                .forEach { $0.orderOut(nil) }
        }
    }

    private static var wasLaunchedAtLogin: Bool {
        if UserDefaults.standard.bool(forKey: "NSApplicationLaunchIsDefaultLaunchKey") {
            return true
        }

        return ProcessInfo.processInfo.arguments.contains(
            "-NSApplicationLaunchIsDefaultLaunch"
        )
    }
}

@main
struct PromptDockApp: App {
    @NSApplicationDelegateAdaptor(PromptDockAppDelegate.self)
    private var appDelegate

    @AppStorage(AppLanguage.storageKey)
    private var languageRawValue = AppLanguage.system.rawValue

    private let modelContainer: ModelContainer
    @StateObject private var runtime: AppRuntime

    init() {
        AppPreferences.registerDefaults()
        do {
            let container = try DataService.makeModelContainer()
            modelContainer = container
            _runtime = StateObject(
                wrappedValue: AppRuntime(modelContainer: container)
            )
        } catch {
            fatalError("Unable to create the PromptDock model container: \(error)")
        }

    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup("PromptDock", id: "main") {
            MainView()
                .environment(\.locale, selectedLanguage.locale)
                .onAppear { runtime.start() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1_080, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            PromptCommands()
        }

        Settings {
            SettingsView(runtime: runtime)
                .environment(\.locale, selectedLanguage.locale)
        }
        .modelContainer(modelContainer)
    }
}
