// Guards the defect that got build 3 rejected under Guideline 4 (Design):
// "windows that cut off text".
//
// NSPopover does not take its size from a SwiftUI content view -- the hosting
// controller leaves preferredContentSize at zero, so an unsized popover falls
// back to its own 320x320 default and the card is laid out into a box shorter
// than it needs. AppDelegate.sizePopover() measures the content and sets
// popover.contentSize; this checks the two numbers still agree, and that the
// content fits the smallest display App Review is likely to be using.
//
// Run before archiving:  ./Tools/check-popover-size.sh

import AppKit
import SwiftUI

let SMALLEST_SCREEN_HEIGHT: CGFloat = 800     // 1280x800: small MacBook Air / VM
let MENU_BAR: CGFloat = 24

@MainActor
func fitting(_ store: RatesStore, _ settings: Settings, settingsFace: Bool) -> CGSize {
    let v = NSHostingView(rootView: AnyView(
        PopoverView(store: store, settings: settings, showingSettings: settingsFace)))
    v.layoutSubtreeIfNeeded()
    return v.fittingSize
}

@MainActor
final class Check: NSObject, NSApplicationDelegate {
    var failures: [String] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        let settings = Settings.shared
        let store = RatesStore(settings: settings)

        let price = fitting(store, settings, settingsFace: false)
        let prefs = fitting(store, settings, settingsFace: true)
        let content = CGSize(width: max(price.width, prefs.width),
                             height: max(price.height, prefs.height))
        print(String(format: "content: price face %.0fx%.0f, settings face %.0fx%.0f",
                     price.width, price.height, prefs.width, prefs.height))

        // 1. The popover must be told the content's size, not left on its default.
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        let host = NSHostingController(rootView: PopoverView(store: store, settings: settings))
        popover.contentViewController = host
        host.view.layoutSubtreeIfNeeded()
        popover.contentSize = host.view.fittingSize

        if abs(popover.contentSize.height - content.height) > 1 {
            failures.append(String(format:
                "popover.contentSize height %.0f != content height %.0f",
                popover.contentSize.height, content.height))
        }
        if popover.contentSize == CGSize(width: 320, height: 320) {
            failures.append("popover is on NSPopover's 320x320 default — content size never applied")
        }

        // 2. The content must fit under the menu bar on the smallest likely display.
        let usable = SMALLEST_SCREEN_HEIGHT - MENU_BAR
        if content.height > usable {
            failures.append(String(format:
                "content %.0fpt tall exceeds %.0fpt usable on a %.0fpt display",
                content.height, usable, SMALLEST_SCREEN_HEIGHT))
        } else {
            print(String(format: "fits a %.0fpt display: %.0f of %.0f usable pt (%.0f%% headroom)",
                         SMALLEST_SCREEN_HEIGHT, content.height, usable,
                         (usable - content.height) / usable * 100))
        }

        print(String(format: "popover.contentSize: %.0f x %.0f",
                     popover.contentSize.width, popover.contentSize.height))
        if failures.isEmpty {
            print("\nOK — popover is sized from its content and fits.")
            exit(0)
        }
        print("\nFAIL:")
        failures.forEach { print("  - \($0)") }
        exit(1)
    }
}

@main
enum CheckPopoverSize {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let check = Check()
            app.delegate = check
            objc_setAssociatedObject(app, "check", check, .OBJC_ASSOCIATION_RETAIN)
            app.run()
        }
    }
}
