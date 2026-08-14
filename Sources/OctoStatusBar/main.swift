import AppKit

// Top-level code isn't main-actor isolated, but everything below runs on the
// main thread by definition — the process has no other threads yet.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    // Held for the process lifetime; NSApplication's delegate is unowned.
    objc_setAssociatedObject(app, Unmanaged.passUnretained(app).toOpaque(),
                             delegate, .OBJC_ASSOCIATION_RETAIN)
    app.delegate = delegate
    // Menu bar only — no Dock icon, no main window.
    app.setActivationPolicy(.accessory)
    app.run()
}
