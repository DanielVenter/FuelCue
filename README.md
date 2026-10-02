# FuelCue: fuelling reminder data field for Edge 540

A fuelling plan on your Edge: it counts down to the next feed and alerts you when it is due.

## What it shows

- **Before the ride (timer at 0:00):** which plan is loaded and why (`FUEL PLAN - SAT`, `- 28 NOV`, `- SET`, `- BUILT-IN`), then the whole plan with ride-clock times. Check it before you roll out.
- **During the ride, full page:** `NEXT FEED`, its name and a big countdown, then the next three feeds below.
- **During the ride, small slot:** feed name over the countdown.
- **When a feed is due:** one beep, and the field fills with an alert screen (EAT or REFILL, an icon, the feed name) for 10 s, then moves on to the next feed. The length is the *Alert shows for* setting.
- **After the last feed:** `DONE`.
- Times are **ride timer time**: they pause when the Edge auto-pauses, so they match the timer on your screen.
- A feed missed by more than the alert length (for example the field was loaded mid-ride) is skipped silently.

Each feed gets a colour and an alert icon from the words in its label:

| Label contains | Colour | Icon |
|---|---|---|
| `CAFF` | plum | gel sachet with a bolt |
| `GEL` | amber | gel sachet |
| `BAR` | brown | wrapped bar |
| `REFILL` or `WATER` | blue | bottle, alert says REFILL |
| anything else | slate | dot |

Change them in `FuelStyle` at the bottom of `source/FuelView.mc`.

## Alerts on other data pages

The alert screen above is drawn by the field, so you only see it on a page that has FuelCue on it. To cover other pages (map, power), FuelCue also asks the Edge for one of its own pop-up alerts. The Edge only shows those if alerts are enabled for FuelCue: ride profile, *Alerts*, *Connect IQ*. The simulator never shows them, so this part is **untested until tried on a real Edge**. The beep plays either way.

## Which plan loads

First match wins:

1. *Use now* override from the settings.
2. A settings plan dated today.
3. A settings plan for today's weekday.
4. A built-in plan dated today (table at the bottom).
5. The default schedule (feed every 30 min).

The plan is picked when the field loads, and again if the date changes while the timer is still at 0:00.

## Build and install (one time, ~1 hour)

1. Install **VS Code** and the **Monkey C** extension (by Garmin).
2. Install the **Connect IQ SDK Manager** from developer.garmin.com/connect-iq/sdk. Sign in, download the latest SDK, and under *Devices* download **Edge 540**.
3. In VS Code: Command Palette, then **Monkey C: Generate a Developer Key**. Save it somewhere safe.
4. Open this `FuelCue` folder in VS Code.
5. **Test in the simulator:** Command Palette, then **Monkey C: Run** and pick Edge 540. The plan preview shows straight away. Start the timer with *Data Fields > Timer > Start Activity* to see the countdown; change settings with *File > Edit Persistent Storage > Edit Application.Properties*.
6. **Build for the Edge:** Command Palette, then **Monkey C: Build for Device**, pick Edge 540. You get `FuelCue.prg`.
7. Plug the Edge into your computer by USB and copy `FuelCue.prg` into `GARMIN/APPS/` on the Edge. Unplug.
8. On the Edge: open your ride profile, then *Data Screens*, pick a screen, pick a slot, choose *Connect IQ*, then *FuelCue*. Optionally add a second data screen with FuelCue as the only field.

## Changing plans

**From your phone (needs a store install, see below):** Connect IQ app, FuelCue, Settings.

- **Plan 1 to 5:** each has a name, a *when* and a schedule (`0:20 Caff gel; 0:55 Gel; 1:30 Bar`).
  - *When* = a date (`28 Nov` or `28/11`, year ignored): loads on that date. Use for race-build weeks.
  - *When* = weekdays (`Sat`, or `Tue, Thu`): loads every such day. Use for a steady training block.
  - *When* blank: only loads through *Use now*.
  - A dated plan beats a weekday plan, and both beat the built-in plans.
  - Anything with a number in it is read as a date. A date that cannot be read is ignored.
- **Use now:** forces one plan (or the default schedule) whatever the day. It holds until the day after a ride was started with it, then returns to Auto by itself.
- **Default schedule:** used on any day with no plan.
- Change settings before starting the ride: a change resets progress through the plan.

**In code:** add a `[month, day, "schedule"]` line to `PLANS` at the top of `source/FuelView.mc`, rebuild, reinstall.

## Getting settings: upload as a private beta app

Settings only appear for apps installed from the Connect IQ store. A `.prg` copied over USB always uses the built-in plans and the default schedule.

1. In VS Code: Command Palette, then **Monkey C: Export Project**. You get `FuelCue.iq`.
2. Go to apps.garmin.com/developer, sign in, **Upload an App**, and choose the `.iq`.
3. Tick **Beta App**. Beta apps are only visible to your own Garmin account.
4. Fill in the required title, description and images, then submit.
5. Delete any sideloaded `FuelCue.prg` from `GARMIN/APPS/` on the Edge.
6. In the Connect IQ phone app, find FuelCue under your apps, install it to the Edge and sync.
7. To release a code change: export again and upload it as a new version of the same app.

## Built-in plans

| Date | Schedule |
|---|---|
| 3 Oct | 0:30 Bar · 1:15 Gel · 1:30 Water top-up · 2:00 Bar · 2:45 Gel · 3:30 Gel if riding |
| 10 Oct | 0:20 Caff gel · 1:00 Gel · 1:40 Gel · 1:55 Refill drill · 2:20 Bar · 3:00 Gel |
| 17 Oct | 0:20 Caff gel · 0:55 Gel · 1:30 Gel · 1:55 Refill · 2:05 Caff gel · 2:40 Bar |
| 7 Nov, 22 Nov | 0:20 Caff gel · 0:55 Gel · 1:30 Gel · 1:55 Refill Gold Reef City · 2:05 Caff gel · 2:40 Gel · 3:15 Gel · 3:50 Gel |
| 14 Nov | 0:45 Bar |

## Status

Checked in the Edge 540 simulator: plan picking (override, date, weekday, built-in, default, override expiring the next day), the preview, countdown, alert screens, small and half-height slots, long plans and long labels. Not yet tested on a real Edge: beep sound, the Edge's own pop-up on other pages, and settings sync from the phone.
