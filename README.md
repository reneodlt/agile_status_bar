<div align="center">

<img src="docs/icon.png" width="120" alt="">

# Agile Bar

**The current Octopus Agile electricity price, in your macOS menu bar.**

</div>

Agile Octopus prices change every half hour. Agile Bar keeps the live unit rate
in the menu bar and, on click, answers the question that actually matters — *is
now a good time to put the washing on?*

<div align="center">
<img src="docs/screenshot-light.png" width="340" alt="The popover in light mode">
<img src="docs/screenshot-dark.png" width="340" alt="The popover in dark mode">
</div>

## What it shows

**In the menu bar** — the current half-hour unit rate, with a coloured dot
showing how it compares with the rest of the day.

**On click**

- the live price, how long is left in the slot, and a plain-English verdict
- the next slot and the change from now
- every published half hour as a bar chart, hover for exact figures
- the cheapest and priciest slots ahead, and the average
- the **cheapest contiguous two hours** — for the dishwasher, the EV, the dryer

It updates itself: the displayed slot rolls over within 30 seconds of each half
hour, prices are re-fetched every 15 minutes, and it catches up immediately when
your Mac wakes.

### About that 24 hours

Octopus publishes the next day's prices in the late afternoon. Before then, less
than 24 hours is actually known — so the app says how far ahead it can really
see ("next 20h 31m") rather than implying a full day of data it doesn't have.

## Colour

Prices are coloured on a **diverging scale around the middle of the visible
window**: blue for cheaper than usual, grey for typical, red for dearer. It
re-bases itself every day, so it stays meaningful as the wholesale market moves
instead of relying on thresholds that go stale.

Both arms are single-hue ramps, monotone in lightness, validated for
colour-vision deficiency and for contrast against the light and dark surfaces
separately. Colour never carries meaning on its own — every use is paired with a
text label, and the chart's extremes are marked as well as coloured.

Negative prices get their own treatment: Agile really does go below zero, and the
chart keeps a true zero baseline so those slots read as what they are.

## Installing

Requires macOS 14 or later.

```sh
git clone https://github.com/<you>/octo_status_bar.git
cd octo_status_bar
./Tools/make-icon.sh     # generates the app icon
./build.sh               # builds build/OctoStatusBar.app
open build/OctoStatusBar.app
```

Then open the popover and click the gear — the card flips over — and set your
region, either by picking it from the list or by typing a postcode and letting
the app look the region up.

<div align="center">
<img src="docs/screenshot-settings.png" width="340" alt="The settings side of the card">
</div>

To develop without bundling, `swift build && swift run`. Note that "Open at
login" needs a real app bundle, so it is inert under `swift run`.

## Data and privacy

Prices come from the [Octopus Energy public
API](https://developer.octopus.energy/rest/guides/endpoints). Everything the app
uses is public and unauthenticated — **no account, API key, or MPAN is needed or
collected**, and there is no analytics or tracking of any kind. See
[PRIVACY.md](PRIVACY.md).

The app resolves the current Agile product code at runtime rather than hardcoding
it, so it keeps working when Octopus supersedes the tariff.

## Distribution

Day-to-day builds use the Swift package (`./build.sh`). Mac App Store archives
use an Xcode project generated from [`project.yml`](project.yml), compiling the
same sources:

```sh
brew install xcodegen
xcodegen generate
open OctoStatusBar.xcodeproj
```

Set your Team ID in the target's Signing & Capabilities, then Product → Archive.
The app is sandboxed with a single entitlement,
`com.apple.security.network.client`.

The generated `.xcodeproj`, the `.icns`, and everything under `build/` are
gitignored — they are build artefacts, and the drawing code and package manifest
are the source of truth.

## Referral link

Settings contains an Octopus Energy referral link. If you sign up through it,
Octopus credits both you and the author of this app — that is disclosed in the
app itself, and it is tucked away on the settings pane rather than put in front
of the prices. Nothing about the app changes if you ignore it, and no referral
or tracking data reaches this project either way.

## Licence

MIT — see [LICENSE](LICENSE).

## Disclaimer

This is an independent, unofficial project. It is **not affiliated with,
endorsed by, or supported by Octopus Energy**. "Octopus Energy" and "Agile
Octopus" are trademarks of Octopus Energy Ltd, used here only to describe what
the app displays.

Prices shown are for information only. Always check your Octopus account for
what you are actually billed.
