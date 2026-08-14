# App Store listing copy

Paste-ready metadata for the App Store Connect **macOS App › App Information**
and **Version Information** panes. Kept here so the wording is reviewed in pull
requests like everything else, rather than living only in a web form.

Apple's limits are noted against each field. The description is plain text —
App Store Connect renders no Markdown, so the bullets below are literal `•`
characters and the line breaks are meaningful.

---

## Name (30 max)

The name is the highest-weighted field in App Store search, so it carries both
terms people actually type. "for Octopus" rather than "Octopus" outright: the
construction signals compatibility rather than endorsement, which is the point
Guideline 5.2.1 turns on. *WattSaver for Octopus Energy*, *Octopus Energy Agile
Watcher* and *OctopusAgilePrice* are all on the store under the same reasoning.

Note this need not match `CFBundleName` ("Agile Bar") — a store name that
extends the app's own name is normal, and the shorter one is what sits under
the icon.

```
Agile Bar for Octopus
```

## Subtitle (30 max)

Deliberately shares no word with the name. Name and subtitle are indexed
separately, so repeating "Agile" or "Octopus" here would buy nothing.

```
Half-hourly electricity prices
```

## Promotional text (170 max)

Sits above the description on the product page and can be changed without
resubmitting for review — the one field that can follow the season or the
market. Use it; a stale line here is a wasted 170 characters.

Launch:

```
Free, open source, and asks for nothing — no account, no API key, no meter hardware. Just the live Agile rate in your menu bar, and the cheapest two hours ahead.
```

Rotations to swap in later:

- *Winter, when plunge pricing gets common* — "Agile goes below zero more often
  than you would think. The chart keeps a true zero baseline, so the slots that
  pay you to use power read as exactly that."
- *Late afternoon publish* — "Tomorrow's prices land around 16:00. Agile Bar
  picks them up on its own and tells you how far ahead it can actually see."

## Description (4000 max)

The first line carries the differentiator deliberately: every competing Octopus
menu bar app is gated behind an account, an API key, or an Octopus Mini, and
that is the single strongest reason to pick this one. It is also the answer to
a Guideline 4.3 "duplicate app" query, so it must not be buried.

The disclaimer at the foot is reproduced verbatim from the README. Reviewers
assessing third-party trademark use under Guideline 5.2.1 look for exactly this.

```
No account. No API key. No hardware.

Agile Bar puts the live Octopus Agile unit rate in your Mac's menu bar and answers the question that actually matters — is now a good time to put the washing on?

Agile prices change every half hour. Rather than making you go and look them up, Agile Bar keeps the current rate in front of you and colours it against the rest of the day, so a cheap slot is obvious at a glance.

IN THE MENU BAR

The current half-hour unit rate, with a coloured dot showing how it compares with the rest of the day.

ON CLICK

• The live price, how long is left in the slot, and a plain-English verdict
• The next slot, and what it changes to
• Every published half hour as a bar chart — hover for exact figures
• The cheapest and priciest slots ahead, and the average
• The cheapest contiguous two hours, for the dishwasher, the EV, the dryer

IT KEEPS ITSELF CURRENT

The displayed slot rolls over within 30 seconds of each half hour, prices are re-fetched every 15 minutes, and it catches up immediately when your Mac wakes.

Octopus publishes tomorrow's prices in the late afternoon. Before then, less than 24 hours is genuinely known — so the app tells you how far ahead it can actually see rather than implying a full day of data it does not have.

COLOUR THAT MEANS SOMETHING

Prices are coloured on a diverging scale around the middle of the visible window: blue for cheaper than usual, grey for typical, red for dearer. It re-bases every day, so it stays meaningful as the wholesale market moves instead of relying on thresholds that go stale.

Both arms are single-hue ramps, monotone in lightness, validated for colour-vision deficiency and for contrast in light and dark mode separately. Colour never carries meaning on its own — every use is paired with a text label, and the chart's extremes are marked as well as coloured.

Agile really does go below zero. The chart keeps a true zero baseline so those slots read as what they are.

SETTINGS

Pick your grid region from the list, or type a postcode and let the app look it up. Show prices with or without VAT, colour the menu bar dot or keep it plain, and open at login if you want it always there.

PRIVACY

Prices come from the Octopus Energy public API. Everything the app uses is public and unauthenticated — no account, API key, or MPAN is needed or collected. There is no analytics and no tracking of any kind. The app resolves the current Agile product code at runtime rather than hardcoding it, so it keeps working when Octopus supersedes the tariff.

Agile Bar is free, has no in-app purchases, and is open source under the MIT licence.

Most useful on an Agile Octopus tariff, but because it needs no account it works just as well if you are still deciding whether to switch. UK electricity regions only.

—

This is an independent, unofficial project. It is not affiliated with, endorsed by, or supported by Octopus Energy. "Octopus Energy" and "Agile Octopus" are trademarks of Octopus Energy Ltd, used here only to describe what the app displays.

Prices shown are for information only. Always check your Octopus account for what you are actually billed.
```

## Keywords (100 max, comma-separated, no spaces after commas)

Nothing here repeats the Name or Subtitle — "agile", "bar", "octopus",
"electricity" and "prices" are already indexed from those fields, so spending
the budget on them again buys nothing. Singulars only, for the same reason
Apple's search does its own stemming.

```
energy,tariff,smart,meter,unit,rate,kwh,cheap,ev,charging,bill,power,grid,usage,menubar
```

## Support URL

```
https://github.com/reneodlt/agile_status_bar
```

## Privacy policy URL

```
https://github.com/reneodlt/agile_status_bar/blob/main/PRIVACY.md
```

## Category

Primary **Utilities**, matching `LSApplicationCategoryType` in
[`Resources/Info.plist`](../Resources/Info.plist). No secondary category.

## App Privacy questionnaire

**Data Not Collected.** The app makes unauthenticated GETs to
`api.octopus.energy` and stores preferences in its own sandboxed defaults.
Nothing leaves the machine. See [PRIVACY.md](../PRIVACY.md).

## Review notes

`LSUIElement` apps open no window and show no Dock icon, and reviewers have
reported such apps as failing to launch. Say so explicitly:

```
Agile Bar is a menu bar accessory. It deliberately opens no window and shows no Dock icon on launch (LSUIElement).

TO TEST: after launching, look at the right-hand end of the macOS menu bar at the top of the screen. You will see a price in pence, such as "24.3p", with a small coloured dot. Click it to open the full interface, and click the gear inside that popover for settings.

The app shows electricity prices for the UK "Agile Octopus" tariff, fetched from the Octopus Energy public API. It requires no account, no API key and no login, so there is no demo credential to provide — it works immediately on first launch. It defaults to grid region C (London); the settings pane changes this.

Prices are UK-only, so the data will look correct but will not be locally relevant if tested outside the UK.

There is a referral link on the settings pane. It is disclosed in the interface as benefiting both the user and the developer, and is not required to use any feature of the app.
```
