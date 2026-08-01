import AppKit
import SwiftData
import SwiftUI

private final class QuickSearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}

@MainActor
final class MenuBarController: NSObject {
    private let modelContainer: ModelContainer
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        popover.behavior = .transient
        popover.animates = true
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else {
            popover.performClose(nil)
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "text.bubble",
                accessibilityDescription: "PromptDock"
            )
            button.imagePosition = .imageOnly
            button.toolTip = "PromptDock"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        statusItem = item
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        let language = AppPreferences.selectedLanguage
        popover.contentSize = NSSize(width: 410, height: 88)
        popover.contentViewController = NSHostingController(
            rootView: QuickSearchView(
                onClose: { [weak self] in
                    self?.popover.performClose(nil)
                },
                onPreferredHeightChange: { [weak self] height in
                    self?.popover.contentSize = NSSize(
                        width: 410,
                        height: height
                    )
                }
            )
            .modelContainer(modelContainer)
            .environment(\.locale, language.locale)
            .id(UUID())
        )
        popover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .minY
        )
    }
}

@MainActor
final class QuickSearchPanelController: NSObject, NSWindowDelegate {
    private let modelContainer: ModelContainer
    private var panel: NSPanel?
    private var eventMonitor: Any?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    func show() {
        let panel = makePanelIfNeeded()
        let language = AppPreferences.selectedLanguage
        resize(panel, to: 88, animated: false)
        panel.contentViewController = NSHostingController(
            rootView: QuickSearchView(
                onClose: { [weak panel] in
                    panel?.orderOut(nil)
                },
                onPreferredHeightChange: { [weak self, weak panel] height in
                    guard let panel else { return }
                    self?.resize(panel, to: height, animated: panel.isVisible)
                }
            )
            .modelContainer(modelContainer)
            .environment(\.locale, language.locale)
            .id(UUID())
        )

        position(panel)
        installDismissMonitorIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func resize(
        _ panel: NSPanel,
        to requestedHeight: CGFloat,
        animated: Bool
    ) {
        let height = min(max(requestedHeight, 88), 480)
        guard abs(panel.frame.height - height) > 0.5 else { return }

        let frame = NSRect(
            x: panel.frame.minX,
            y: panel.frame.maxY - height,
            width: 410,
            height: height
        )
        panel.setFrame(frame, display: true, animate: animated)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = QuickSearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: 390),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.delegate = self
        self.panel = panel
        return panel
    }

    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
    }

    private func installDismissMonitorIfNeeded() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown
            ]
        ) { [weak self] event in
            guard let self,
                  let panel = self.panel,
                  panel.isVisible
            else { return event }

            if event.window !== panel {
                panel.orderOut(nil)
            }
            return event
        }
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.maxY - panel.frame.height - 90
        )
        panel.setFrameOrigin(origin)
    }
}

@MainActor
final class AppRuntime: ObservableObject {
    let hotKeyService: GlobalHotKeyService

    private let menuBarController: MenuBarController
    private let quickSearchPanelController: QuickSearchPanelController
    private var hasStarted = false

    init(modelContainer: ModelContainer) {
        hotKeyService = GlobalHotKeyService()
        menuBarController = MenuBarController(modelContainer: modelContainer)
        quickSearchPanelController = QuickSearchPanelController(
            modelContainer: modelContainer
        )
        hotKeyService.onTrigger = { [weak quickSearchPanelController] in
            quickSearchPanelController?.show()
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        menuBarController.setVisible(
            AppPreferences.isMenuBarVisible
        )
        hotKeyService.setEnabled(
            AppPreferences.isGlobalQuickSearchEnabled
        )
    }

    func setGlobalQuickSearchEnabled(_ enabled: Bool) {
        AppPreferences.isGlobalQuickSearchEnabled = enabled
        hotKeyService.setEnabled(enabled)
    }

    func setMenuBarVisible(_ isVisible: Bool) {
        AppPreferences.isMenuBarVisible = isVisible
        menuBarController.setVisible(isVisible)
    }

    func showQuickSearch() {
        quickSearchPanelController.show()
    }
}
