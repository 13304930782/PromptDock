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

    @StateObject private var bootstrap: AppBootstrapController

    init() {
        AppPreferences.registerDefaults()
        _bootstrap = StateObject(wrappedValue: AppBootstrapController())
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup("PromptDock", id: "main") {
            BootstrapMainView(bootstrap: bootstrap)
                .environment(\.locale, selectedLanguage.locale)
        }
        .defaultSize(width: 1_080, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            PromptCommands()
        }

        Settings {
            BootstrapSettingsView(bootstrap: bootstrap)
                .environment(\.locale, selectedLanguage.locale)
        }
    }
}

private struct BootstrapMainView: View {
    @ObservedObject var bootstrap: AppBootstrapController

    var body: some View {
        Group {
            switch bootstrap.state {
            case .loading:
                ProgressView("Opening PromptDock…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready(let container, let runtime):
                MainView()
                    .modelContainer(container)
                    .onAppear { runtime.start() }
            case .failed(let failure):
                StartupFailureView(
                    failure: failure,
                    onRetry: bootstrap.retry
                )
            }
        }
    }
}

private struct BootstrapSettingsView: View {
    @ObservedObject var bootstrap: AppBootstrapController

    var body: some View {
        Group {
            switch bootstrap.state {
            case .loading:
                ProgressView("Opening PromptDock…")
                    .frame(width: 580, height: 450)
            case .ready(let container, let runtime):
                SettingsView(runtime: runtime)
                    .modelContainer(container)
            case .failed(let failure):
                StartupFailureView(
                    failure: failure,
                    onRetry: bootstrap.retry
                )
                .frame(width: 580, height: 450)
            }
        }
    }
}
