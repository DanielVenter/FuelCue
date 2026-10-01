# FuelCue: fuelling reminder data field for Edge 540

Shows the next feed with a countdown. When a feed is due it **beeps twice and pops up a full-screen EAT: CAFF GEL alert over whatever page you're on** (like Garmin's own alerts). The field itself also flashes orange/red for 60 s.

- **Small slot:** label on top, countdown below (e.g. `GEL` / `12:40`).
- **Full page (one-field layout):** plan name, next feed, big countdown, and the next 3 feeds with their times.
- **Plans are built in and picked by date:** 3 Oct, 10 Oct, 17 Oct, 7 Nov + 22 Nov (race), 14 Nov. Any other day uses the default "Feed every 30 min" schedule. No settings needed.
- Times count **ride timer time** (they pause when the Edge auto-pauses), so they match the timer on your screen.

## Build and install (one time, ~1 hour)

1. Install **VS Code** and the **Monkey C** extension (by Garmin).
2. Install the **Connect IQ SDK Manager** from developer.garmin.com/connect-iq/sdk. Sign in, download the latest SDK, and under *Devices* download **Edge 540**.
3. In VS Code: Command Palette, then **Monkey C: Generate a Developer Key**. Save it somewhere safe.
4. Open this `FuelCue` folder in VS Code.
5. **Test in the simulator:** Command Palette, then **Monkey C: Run** and pick Edge 540. In the simulator, use *Simulation > Activity Data* to start a fake ride and fast-forward the timer. Check the beep and the flashing EAT banner.
6. **Build for the Edge:** Command Palette, then **Monkey C: Build for Device**, pick Edge 540. You get `FuelCue.prg`.
7. Plug the Edge into your computer by USB and copy `FuelCue.prg` into `GARMIN/APPS/` on the Edge. Unplug.
8. On the Edge: open your ride profile, then *Data Screens*, pick a screen, pick a slot, choose *Connect IQ*, then *FuelCue*. Optionally add a second data screen with FuelCue as the only field.

## Changing plans

- **Easiest:** edit the `PLAN_...` lines at the top of `source/FuelView.mc`, rebuild, and copy the `.prg` again. Format: `"0:20 Caff gel; 0:55 Gel; 1:30 Gel"`.
- **From your phone:** settings (plan picker, custom schedule) only work if the app is installed through the Connect IQ store. You can upload it as a private **beta app**, which only you can see. Sideloaded copies use the built-in plans and the date picker.

## Built-in plans

| Date | Schedule |
|---|---|
| 3 Oct | 0:30 Bar · 1:15 Gel · 1:30 Water top-up · 2:00 Bar · 2:45 Gel · 3:30 Gel if riding |
| 10 Oct | 0:20 Caff gel · 1:00 Gel · 1:40 Gel · 1:55 Refill drill · 2:20 Bar · 3:00 Gel |
| 17 Oct | 0:20 Caff gel · 0:55 Gel · 1:30 Gel · 1:55 Refill · 2:05 Caff gel · 2:40 Bar |
| 7 Nov, 22 Nov | 0:20 Caff gel · 0:55 Gel · 1:30 Gel · 1:55 Refill GRC · 2:05 Caff gel · 2:40 Gel · 3:15 Gel · 3:50 Gel |
| 14 Nov | 0:45 Bar |

Not compiled or tested yet. Run it in the simulator before relying on it on a ride.
