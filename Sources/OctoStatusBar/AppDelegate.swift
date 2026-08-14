import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private let settings = Settings.shared
    private lazy var store = RatesStore(settings: settings)

    private var heartbeat: Timer?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// What the menu bar currently shows, so a heartbeat that changes nothing
    /// doesn't rebuild the image and title 2,880 times a day.
    private struct Rendered: Equatable {
        var title: String
        var band: PriceBand?
        var coloured: Bool
    }
    private var rendered: Rendered?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.imagePosition = .imageLeading

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(store: store, settings: settings))

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &cancellables)
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &cancellables)

        updateStatusItem()
        store.refresh()
        scheduleTimers()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        heartbeat?.invalidate()
        refreshTimer?.invalidate()
    }

    // MARK: - Timers

    private func scheduleTimers() {
        // A short heartbeat rather than one long timer aimed at the next
        // half-hour boundary: App Nap and system sleep both stretch long
        // timers unpredictably, and a missed boundary would leave a stale
        // price in the menu bar. Polling the clock costs nothing and the slot
        // flips within 30s of the real boundary regardless.
        heartbeat = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        heartbeat?.tolerance = 10

        // Agile publishes tomorrow's prices in the late afternoon, and
        // corrections occasionally land later, so keep pulling through the day.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.refresh() }
        }
        refreshTimer?.tolerance = 60
    }

    private func tick() {
        let previousSlot = store.currentRate?.validFrom
        store.tick()

        // Crossed into a half hour we have no price for — the series has run
        // out, so go and get more rather than showing a dash until the next
        // scheduled poll.
        if store.currentRate == nil && previousSlot != nil {
            store.refresh()
        }
    }

    @objc private func systemDidWake() {
        Task { @MainActor in
            store.tick()
            store.refresh()
        }
    }

    // MARK: - Menu bar

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let current = store.currentRate
        let band = current.map { store.band(for: $0) }
        let title: String
        if let current {
            let value = store.price(current)
            title = settings.showPenceSuffix
                ? String(format: "%.1fp", value)
                : String(format: "%.1f", value)
        } else {
            title = "—"
        }

        let next = Rendered(title: title, band: band, coloured: settings.colourMenuBar)
        guard next != rendered else { return }
        rendered = next

        let dotColor: NSColor
        if let band, settings.colourMenuBar {
            dotColor = NSColor(band.color)
        } else if band != nil {
            dotColor = .labelColor
        } else {
            dotColor = .tertiaryLabelColor
        }

        button.image = Self.dotImage(color: dotColor)
        button.title = " \(title)"

        if let current, let band {
            button.toolTip = """
            Agile Octopus · \(settings.region.name)
            \(Fmt.range(current.validFrom, current.end)) — \(Fmt.pence(store.price(current), decimals: 2))/kWh
            \(band.label): \(band.verdict)
            """
        } else {
            button.toolTip = "Agile Octopus — no price for the current half hour"
        }
    }

    /// A small filled dot carries the band colour; the price itself stays in
    /// the system label colour so it never loses contrast against whatever
    /// wallpaper happens to be behind the menu bar.
    private static func dotImage(color: NSColor) -> NSImage {
        let diameter: CGFloat = 8
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        store.tick()
        store.refresh()

        // An .accessory app is never frontmost on its own. Without activating,
        // a transient popover loses key the instant it appears — and the
        // postcode field in Settings could never take focus.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
