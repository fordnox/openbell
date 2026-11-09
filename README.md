# OpenBell

A native macOS app that shows how long until stock markets open or close, with live countdowns in the app, the menu bar, and desktop widgets.

## Features

- **Menu bar countdown**: shows `● NYSE 01:14`, a red or green dot plus hours and minutes until the next open or close. Click it to open the full panel, and choose which market it tracks at the bottom of that panel.
- **List view**: each market's local time, its offset from your time zone, whether it's open, and a live `Opens in` / `Closes in` countdown.
- **Dial view**: a 24-hour clock in your local time. Each market's trading session is drawn as a coloured ring, and a hand marks the current time.
- **Widgets**
  - **Small**: one market with a big countdown. Right-click → *Edit Widget* to pick the market.
  - **Medium**: all markets with countdowns and status.
  - **Large**: the sessions dial with countdown cards.

## Markets

| Market | Hours (exchange time) | Time zone |
|---|---|---|
| NYSE | 09:30–16:00 | America/New_York |
| NASDAQ | 09:30–16:00 | America/New_York |
| LSE | 08:00–16:30 | Europe/London |
| CRYPTO | 24/7 | — |

Weekends and the 2026–2027 exchange holidays (US and UK) are taken into account. Daylight-saving changes are handled through real time zones. Early-close days (half sessions) aren't modelled yet.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), needed only if you change the project structure

## Build & run

```sh
xcodegen generate          # regenerate OpenBell.xcodeproj from project.yml
open OpenBell.xcodeproj    # then Run the "OpenBell" scheme
```

Or from the command line:

```sh
xcodebuild -project OpenBell.xcodeproj -scheme OpenBell -configuration Release -derivedDataPath build build
open build/Build/Products/Release/OpenBell.app
```

### Widgets not showing up?

macOS loads widgets only from properly signed apps. In Xcode, open **Signing & Capabilities** and select your **Team** for both the `OpenBell` and `OpenBellWidget` targets. Then run the app once and copy it to `/Applications`. The widgets will appear in the widget gallery under **OpenBell**.

## Project structure

```
App/        App entry point, window, list and dial screens, menu bar item
Widget/     Widget extension: small, medium and large widgets
Shared/     Market data and schedule logic, dial view, shared UI pieces (compiled into both targets)
project.yml XcodeGen project definition
```

### Adding a market

Add a `Market` in `Shared/Market.swift` with its time zone, open and close times, holidays and colour. Then include it in `Market.all`, `Market.dialOrder` and `Market.cardOrder`, and add a case to `MarketChoice` in `Widget/OpenBellWidget.swift` so the small widget can select it.

## Disclaimer

Session times and holiday calendars are hard-coded. Check them against your exchange's official calendar before you rely on them for trading.
