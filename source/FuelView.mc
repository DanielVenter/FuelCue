import Toybox.Activity;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// FuelCue: shows the next feed with a countdown, beeps and flashes "EAT" when it is due.
// Schedule is a string like "0:20 Caff gel; 0:55 Gel; 1:30 Gel". Times are ride (timer) time.
class FuelView extends WatchUi.DataField {

    // ---- Built-in plans (Ride Joburg 2026 build) ----
    const PLAN_3OCT  = "0:30 Bar; 1:15 Gel; 1:30 Water top-up; 2:00 Bar; 2:45 Gel; 3:30 Gel if riding";
    const PLAN_10OCT = "0:20 Caff gel; 1:00 Gel; 1:40 Gel; 1:55 Refill drill; 2:20 Bar; 3:00 Gel";
    const PLAN_17OCT = "0:20 Caff gel; 0:55 Gel; 1:30 Gel; 1:55 Refill; 2:05 Caff gel; 2:40 Bar";
    const PLAN_RACE  = "0:20 Caff gel; 0:55 Gel; 1:30 Gel; 1:55 Refill GRC; 2:05 Caff gel; 2:40 Gel; 3:15 Gel; 3:50 Gel";
    const PLAN_14NOV = "0:45 Bar";

    private var mTimes as Array<Number> = [] as Array<Number>;
    private var mLabels as Array<String> = [] as Array<String>;
    private var mPlanName as String = "";
    private var mNext as Number = 0;          // index of the next feed not yet alerted
    private var mAlertIdx as Number = -1;     // feed currently being shown as "EAT"
    private var mAlertUntil as Number = 0;    // ride second when the EAT banner ends
    private var mAlertSecs as Number = 60;
    private var mRepeatToneAt as Number = -1;
    private var mT as Number = 0;             // current ride time, seconds
    private var mLastT as Number = 0;

    function initialize() {
        DataField.initialize();
        loadSchedule();
    }

    // ---------- schedule ----------
    function loadSchedule() as Void {
        var plan = Application.Properties.getValue("plan");
        var custom = Application.Properties.getValue("custom");
        var secs = Application.Properties.getValue("alertSecs");
        mAlertSecs = (secs instanceof Number) ? secs : 60;

        var p = (plan instanceof Number) ? plan : 0;
        if (p == 0) { p = planForToday(); }

        var text = "";
        if (p == 1)      { text = PLAN_3OCT;  mPlanName = "3 OCT"; }
        else if (p == 2) { text = PLAN_10OCT; mPlanName = "10 OCT"; }
        else if (p == 3) { text = PLAN_17OCT; mPlanName = "17 OCT"; }
        else if (p == 4) { text = PLAN_RACE;  mPlanName = "RACE"; }
        else if (p == 5) { text = PLAN_14NOV; mPlanName = "14 NOV"; }
        else {
            text = (custom instanceof String) ? custom : "";
            mPlanName = "CUSTOM";
        }
        parse(text);
        resetProgress();
    }

    // Picks the plan from today's date, so a sideloaded copy needs no settings at all.
    function planForToday() as Number {
        var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var m = d.month as Number;
        var day = d.day as Number;
        if (m == 10 && day == 3)  { return 1; }
        if (m == 10 && day == 10) { return 2; }
        if (m == 10 && day == 17) { return 3; }
        if (m == 11 && (day == 7 || day == 22)) { return 4; }
        if (m == 11 && day == 14) { return 5; }
        return 6; // any other day: custom / default schedule
    }

    function parse(text as String) as Void {
        mTimes = [] as Array<Number>;
        mLabels = [] as Array<String>;
        var rest = text;
        while (rest.length() > 0) {
            var semi = rest.find(";");
            var item = (semi == null) ? rest : rest.substring(0, semi);
            rest = (semi == null) ? "" : rest.substring(semi + 1, rest.length());
            addItem(trim(item as String));
        }
    }

    function addItem(item as String) as Void {
        if (item.length() == 0) { return; }
        var sp = item.find(" ");
        var timePart = (sp == null) ? item : item.substring(0, sp);
        var label = (sp == null) ? "FEED" : trim(item.substring(sp + 1, item.length()) as String);
        var colon = (timePart as String).find(":");
        if (colon == null) { return; }
        var h = (timePart as String).substring(0, colon).toNumber();
        var mm = (timePart as String).substring(colon + 1, (timePart as String).length()).toNumber();
        if (h == null || mm == null) { return; }
        mTimes.add(h * 3600 + mm * 60);
        mLabels.add(label.toUpper());
    }

    function trim(s as String) as String {
        var a = 0;
        var b = s.length();
        while (a < b && s.substring(a, a + 1).equals(" ")) { a += 1; }
        while (b > a && s.substring(b - 1, b).equals(" ")) { b -= 1; }
        return s.substring(a, b) as String;
    }

    function resetProgress() as Void {
        mNext = 0;
        mAlertIdx = -1;
        mAlertUntil = 0;
        mRepeatToneAt = -1;
    }

    // ---------- timing ----------
    function compute(info as Activity.Info) as Void {
        var ms = info.timerTime;
        mT = (ms == null) ? 0 : (ms / 1000);

        // New activity / timer reset
        if (mT + 5 < mLastT) { resetProgress(); }
        mLastT = mT;

        // Fire any feed that is due. Feeds missed by more than the alert window are skipped silently.
        while (mNext < mTimes.size() && mT >= mTimes[mNext]) {
            if (mT - mTimes[mNext] <= mAlertSecs) {
                mAlertIdx = mNext;
                mAlertUntil = mTimes[mNext] + mAlertSecs;
                beep();
                popup(mLabels[mNext]);
                mRepeatToneAt = mT + 4;
            }
            mNext += 1;
        }
        if (mRepeatToneAt >= 0 && mT >= mRepeatToneAt) {
            beep();
            mRepeatToneAt = -1;
        }
        if (mAlertIdx >= 0 && mT >= mAlertUntil) { mAlertIdx = -1; }
    }

    // Full-screen alert over whatever page is showing, like Garmin's own alerts (API 3.2+).
    function popup(label as String) as Void {
        if (WatchUi.DataField has :showAlert) {
            WatchUi.DataField.showAlert(new FuelAlert("EAT", label));
        }
    }

    function beep() as Void {
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }

    // ---------- drawing ----------
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bg = getBackgroundColor();
        var fg = (bg == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        if (mAlertIdx >= 0) {
            // Flash orange/red once a second
            var flash = (mT % 2 == 0) ? Graphics.COLOR_ORANGE : Graphics.COLOR_RED;
            dc.setColor(Graphics.COLOR_WHITE, flash);
            dc.clear();
            var text = "EAT: " + mLabels[mAlertIdx];
            drawFit(dc, w / 2, h / 2, text, w - 6,
                [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
            return;
        }

        dc.setColor(fg, bg);
        dc.clear();

        if (mTimes.size() == 0) {
            drawFit(dc, w / 2, h / 2, "NO PLAN", w - 6, [Graphics.FONT_SMALL, Graphics.FONT_XTINY]);
            return;
        }
        if (mNext >= mTimes.size()) {
            drawFit(dc, w / 2, h / 2, "FUEL DONE", w - 6, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_XTINY]);
            return;
        }

        var label = mLabels[mNext];
        var cd = fmt(mTimes[mNext] - mT);

        if (h < 120) {
            // Normal slot: label on top, countdown below
            drawFit(dc, w / 2, h * 30 / 100, label, w - 6,
                [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
            drawFit(dc, w / 2, h * 68 / 100, cd, w - 6,
                [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        } else {
            // Full page: plan name, next feed, big countdown, then the following feeds
            dc.drawText(w / 2, 4, Graphics.FONT_XTINY, "FUEL - " + mPlanName, Graphics.TEXT_JUSTIFY_CENTER);
            drawFit(dc, w / 2, h * 22 / 100, label, w - 6,
                [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
            drawFit(dc, w / 2, h * 44 / 100, cd, w - 6,
                [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_LARGE]);
            var y = h * 64 / 100;
            for (var i = mNext + 1; i < mTimes.size() && i <= mNext + 3; i += 1) {
                dc.drawText(w / 2, y, Graphics.FONT_SMALL,
                    clock(mTimes[i]) + "  " + mLabels[i], Graphics.TEXT_JUSTIFY_CENTER);
                y += dc.getFontHeight(Graphics.FONT_SMALL) + 2;
            }
        }
    }

    // Draws text centred at (x,y) in the largest font that fits maxW.
    function drawFit(dc as Graphics.Dc, x as Number, y as Number, text as String, maxW as Number,
                     fonts as Array<Graphics.FontType>) as Void {
        var f = fonts[fonts.size() - 1];
        for (var i = 0; i < fonts.size(); i += 1) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxW) { f = fonts[i]; break; }
        }
        dc.drawText(x, y, f, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Countdown mm:ss (or h:mm:ss)
    function fmt(s as Number) as String {
        if (s < 0) { s = 0; }
        var hh = s / 3600;
        var mm = (s % 3600) / 60;
        var ss = s % 60;
        if (hh > 0) { return hh.format("%d") + ":" + mm.format("%02d") + ":" + ss.format("%02d"); }
        return mm.format("%d") + ":" + ss.format("%02d");
    }

    // Ride clock h:mm
    function clock(s as Number) as String {
        return (s / 3600).format("%d") + ":" + ((s % 3600) / 60).format("%02d");
    }
}

// The pop-up shown by showAlert(). The Edge dismisses it after a few seconds or on a button press.
class FuelAlert extends WatchUi.DataFieldAlert {
    private var mTitle as String;
    private var mLabel as String;

    function initialize(title as String, label as String) {
        DataFieldAlert.initialize();
        mTitle = title;
        mLabel = label;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_ORANGE);
        dc.clear();
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_LARGE, mTitle,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var f = Graphics.FONT_LARGE;
        if (dc.getTextWidthInPixels(mLabel, f) > w - 8) { f = Graphics.FONT_MEDIUM; }
        if (dc.getTextWidthInPixels(mLabel, f) > w - 8) { f = Graphics.FONT_SMALL; }
        dc.drawText(w / 2, h * 60 / 100, f, mLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
