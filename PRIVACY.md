# Privacy Policy

**Agile Bar** (`io.reneo.OctoStatusBar`)
Last updated: 14 August 2026

## The short version

Agile Bar collects nothing, sends nothing, and has no server.

## What the app does on the network

The app makes read-only HTTPS requests to one host, `api.octopus.energy`, to
fetch:

- the list of public Octopus Energy tariff products,
- published half-hourly unit rates for the grid region you select,
- optionally, the grid region for a postcode you type into Settings.

These are Octopus Energy's public, unauthenticated pricing endpoints. The app
never asks for, stores, or transmits an Octopus account number, API key, meter
identifier (MPAN), or any other account credential.

If you use the postcode lookup, the postcode you type is sent to Octopus Energy
solely to resolve it to a grid region letter. It is not stored by this app — only
the resulting region letter (a single character, `A`–`P`) is saved.

## What is stored on your Mac

Inside the app's sandbox container, and nowhere else:

- your chosen region and display preferences (macOS user defaults),
- a cached copy of the most recently fetched prices, so the menu bar shows a
  price immediately at login and keeps working through a brief network outage.

Deleting the app removes both.

## What is not collected

No analytics. No crash reporting. No advertising identifiers. No tracking of any
kind. No data is shared with, or sold to, anybody.

## Contact

Questions about this policy: open an issue on the project's GitHub repository.
