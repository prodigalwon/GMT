# GMT Watch Face for Garmin Fenix 7X

A traveler's instrument. Not a fitness tracker. Every element earns its place.


<img width="531" height="740" alt="image" src="https://github.com/user-attachments/assets/f2cb8112-9fd0-4da6-8dd9-0a737c41da85" />



## Center Time

Large stacked hours (white) and minutes (blue) dominate the face. Readable at a glance under any condition. Follows your device's 12/24-hour preference.

## GMT Complications

Two configurable timezone slots sit on the left side of the face:

- **GMT 1** (upper, 10 o'clock) — your primary tracking timezone
- **GMT 2** (lower, 9 o'clock) — secondary timezone

Each slot shows:
- Current time in that zone (always 12-hour AM/PM for instant readability)
- Day of week in that zone (critical for trans-dateline travel)
- Timezone label and relative offset from your current local time (e.g., "CDT +5")

**Automatic DST detection.** When you select a city like "Central US" or "Sydney," the watch automatically applies daylight saving time adjustments based on the current date. No manual toggling — the offset updates itself when clocks spring forward or fall back. Supports US/Canada, EU/UK, Australia, New Zealand, and Chile rules. Cities that don't observe DST (Hawaii, Arizona, Japan, etc.) are listed separately.

**55 city-based timezone presets** accessible from the on-watch settings menu (hold UP/MENU on the Fenix 7X).

## Daylight Arc

A colored arc traces the remaining daylight along the watch bezel, from the current sun position to sunset. The sun dot rides the arc in real time.

**Color shifts as sunset approaches:**
- More than 90 minutes to sunset: gold
- 90 to 30 minutes: gold fades to lilac
- 30 to 0 minutes: lilac deepens to violet
- At the exact sunset moment: green flash (the real optical phenomenon)

A small sunset marker dot appears in the last 2 hours, showing exactly where sunset falls on the bezel.

After sunset, the arc disappears. The sunrise/sunset time display below the sun icon swaps to show the next relevant event: sunset during daytime, sunrise at night, with a 20-minute grace period after each transition.

## Moon Phase

Calculated mathematically from the J2000 epoch — no API or connectivity required. Works offline from the moment you install it.

**Latitude-aware tilt.** The crescent tilts based on your GPS latitude:
- At the equator: symmetric crescent (horns at equal heights)
- Northern hemisphere: left horn rises higher
- Southern hemisphere: right horn rises higher

The tilt updates automatically as you travel.

**Blood moon.** On dates matching a total lunar eclipse, the moon icon turns red. Covers all confirmed total lunar eclipses from 2026 through 2040, sourced from NASA's eclipse catalog.

## Weather

A drawn weather icon sits below the center time, showing the current condition from your phone's weather data: clear (sun with rays), partly cloudy, overcast, rain, snow (snowflake), storm (lightning bolt), fog, or wind.

## Heart Rate

A pulsing heart icon with your current BPM below it. The heart beats every second when the display is active. Heart rate data comes from the wrist sensor or sensor history.

## Sunrise / Sunset

A half-sun icon with rays above the horizon, paired with the time of the next solar event. During the day it shows sunset; after sunset it shows tomorrow's sunrise.

## Battery

A horizontal battery cell icon with proportional fill and percentage below. Color-coded:
- Green: above 30%
- Amber: 15-30%
- Red: below 15%

## Steps Bar

A vertical segmented bar to the right of the center time. Ten segments fill from bottom to top as you approach your daily step goal. Bright blue for completed segments, dark blue for remaining.

## Tick Marks

60 tick marks around the bezel edge (major marks at 5-minute intervals) provide an analog clock reference. The daylight arc draws behind the tick marks so both are visible simultaneously.

## Design Principles

- **Information density done right.** Every complication is legible at arm's length.
- **Palette-exact colors.** All colors are chosen from the Garmin MIP 64-color palette (RGB222) so what you see in the simulator is what you get on the watch.
- **Vector typography.** RobotoBlack vector fonts at calibrated sizes for maximum legibility on the transflective MIP display.
- **No clutter.** Temperature (no ambient sensor), notifications (just a count — useless), compass (use the app), and chronograph (built-in activity) were intentionally omitted.

## Settings

Access via the on-watch menu:
1. Hold **UP/MENU** on the Fenix 7X
2. Navigate to the watch face settings
3. Select **Set GMT 1** or **Set GMT 2**
4. Choose from 55 city-based timezone presets

Timezone presets with DST support are marked with `*` in the picker. The watch handles DST transitions automatically.

## Compatibility

Currently built for the **Garmin Fenix 7X** (280x280 MIP display, Connect IQ 4.1+).

## Build

Requires the Garmin Connect IQ SDK 9.1+ and Java (from Android Studio or standalone JDK).

```
monkeyc -d fenix7x -o GMT.prg -f monkey.jungle -y <developer_key.der>
```

Sideload to the watch by copying `GMT.prg` to `<Garmin drive>/GARMIN/APPS/`.
