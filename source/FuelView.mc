import Toybox.Activity;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// FuelCue: shows the next feed with a countdown, beeps once and pops up an alert when it is due.
// Schedule is a string like "0:20 Caff gel; 0:55 Gel; 1:30 Gel". Times are ride (timer) time.
class FuelView extends WatchUi.DataField {

    // ---- Built-in plans (Ride Joburg 2026 build): month, day, schedule ----
    // Used when no settings slot matches today.
    const PLANS = [
        [10,  3, "0:30 Bar; 1:15 Gel; 1:30 Water top-up; 2:00 Bar; 2:45 Gel; 3:30 Gel if riding"],
        [10, 10, "0:20 Caff gel; 1:00 Gel; 1:40 Gel; 1:55 Refill drill; 2:20 Bar; 3:00 Gel"],
        [10, 17, "0:20 Caff gel; 0:55 Gel; 1:30 Gel; 1:55 Refill; 2:05 Caff gel; 2:40 Bar"],
        [11,  7, "0:20 Caff gel; 0:55 Gel; 1:30 Gel; 1:55 Refill Gold Reef City; 2:05 Caff gel; 2:40 Gel; 3:15 Gel; 3:50 Gel"],
        [11, 22, "0:20 Caff gel; 0:55 Gel; 1:30 Gel; 1:55 Refill Gold Reef City; 2:05 Caff gel; 2:40 Gel; 3:15 Gel; 3:50 Gel"],
        [11, 14, "0:45 Bar"]
    ];
    const SLOTS = 5;   // plan slots in the phone settings (n1/d1/s1 .. n5/d5/s5)
    const MONTHS = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";
    const DAYS = "SUNMONTUEWEDTHUFRISAT";
    const MARK = 6;       // width of the colour marker down the left edge

    private var mTimes as Array<Number> = [] as Array<Number>;
    private var mLabels as Array<String> = [] as Array<String>;
    private var mTypes as Array<Number> = [] as Array<Number>;
    private var mPlanName as String = "";
    private var mPlanWhy as String = "";      // why this plan was picked: SET, a date, a weekday, or empty
    private var mToday as Number = 0;         // month * 100 + day
    private var mOverride as Boolean = false; // plan was forced by the "Use now" setting
    private var mStamped as Boolean = false;  // override has been recorded as ridden today
    private var mNext as Number = 0;          // index of the next feed not yet alerted
    private var mAlertIdx as Number = -1;     // feed currently due: shown full-field, like a pop-up
    private var mAlertUntil as Number = 0;    // ride second when the due feed stops showing
    private var mAlertSecs as Number = 10;
    private var mT as Number = 0;             // current ride time, seconds
    private var mLastT as Number = 0;

    function initialize() {
        DataField.initialize();
        loadSchedule();
    }

    // ---------- schedule ----------
    // Order: "Use now" override, slot dated today, slot for today's weekday, built-in plan dated
    // today, then the default schedule.
    function loadSchedule() as Void {
        var secs = Application.Properties.getValue("alertSecs");
        mAlertSecs = (secs instanceof Number) ? secs : 10;

        var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var m = d.month as Number;
        var day = d.day as Number;
        var dow = DAYS.substring(((d.day_of_week as Number) - 1) * 3, (d.day_of_week as Number) * 3) as String;
        mToday = m * 100 + day;
        mStamped = false;

        var today = day + " " + MONTHS.substring((m - 1) * 3, m * 3);
        var use = overrideSlot();
        mOverride = (use != 0);
        mPlanWhy = "SET";
        var pick = (use >= 1 && use <= SLOTS) ? use : 0;
        if (use == 0) {
            for (var i = 1; i <= SLOTS && pick == 0; i += 1) {
                var md = parseDate(prop("d" + i));
                if (md != null && md[0] == m && md[1] == day && prop("s" + i).length() > 0) { pick = i; }
            }
            mPlanWhy = today;
            for (var i = 1; i <= SLOTS && pick == 0; i += 1) {
                var when = prop("d" + i).toUpper();
                if (!hasDigit(when) && when.find(dow) != null && prop("s" + i).length() > 0) {
                    pick = i;
                    mPlanWhy = dow;
                }
            }
        }

        var text = null;
        if (pick > 0 && prop("s" + pick).length() > 0) {
            text = prop("s" + pick);
            mPlanName = prop("n" + pick).toUpper();
            if (mPlanName.length() == 0) { mPlanName = "PLAN " + pick; }
        }
        for (var i = 0; i < PLANS.size() && text == null && use == 0; i += 1) {
            if (PLANS[i][0] == m && PLANS[i][1] == day) {
                text = PLANS[i][2];
                mPlanName = today;
                mPlanWhy = "BUILT-IN";
            }
        }
        if (text == null) {
            text = prop("custom");
            mPlanName = "DEFAULT";
            if (!mOverride) { mPlanWhy = ""; }
        }
        parse(text as String);
        resetProgress();
    }

    // The "Use now" setting: 0 auto, 1..SLOTS a plan slot, SLOTS+1 the default schedule.
    // It lasts until the day after a ride was started with it, then goes back to auto.
    function overrideSlot() as Number {
        var use = Application.Properties.getValue("use");
        var u = (use instanceof Number) ? use : 0;
        if (u == 0) { return 0; }
        var val = Application.Storage.getValue("ovVal");
        var stamp = Application.Storage.getValue("ovDay");
        if (!(val instanceof Number) || val != u) {
            // Newly chosen override: not ridden yet
            Application.Storage.setValue("ovVal", u);
            Application.Storage.deleteValue("ovDay");
        } else if (stamp instanceof Number && stamp != mToday) {
            Application.Properties.setValue("use", 0);
            Application.Storage.deleteValue("ovVal");
            Application.Storage.deleteValue("ovDay");
            return 0;
        }
        return u;
    }

    // A "when" with a number in it is meant as a date, never as a weekday list.
    function hasDigit(s as String) as Boolean {
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i += 1) {
            if (chars[i] >= '0' && chars[i] <= '9') { return true; }
        }
        return false;
    }

    function prop(key as String) as String {
        var v = Application.Properties.getValue(key);
        return (v instanceof String) ? trim(v) : "";
    }

    // "28 Nov", "28 November" or "28/11" -> [month, day]; null if it cannot be read.
    function parseDate(s as String) as Array<Number>? {
        var t = trim(s).toUpper();
        var sep = t.find("/");
        if (sep == null) { sep = t.find(" "); }
        if (sep == null) { return null; }
        var day = (t.substring(0, sep) as String).toNumber();
        var mPart = trim(t.substring(sep + 1, t.length()) as String);
        var month = mPart.toNumber();
        if (month == null && mPart.length() >= 3) {
            var at = MONTHS.find(mPart.substring(0, 3) as String);
            if (at != null && at % 3 == 0) { month = at / 3 + 1; }
        }
        if (day == null || month == null) { return null; }
        return [month, day] as Array<Number>;
    }

    function parse(text as String) as Void {
        mTimes = [] as Array<Number>;
        mLabels = [] as Array<String>;
        mTypes = [] as Array<Number>;
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
        var h = ((timePart as String).substring(0, colon) as String).toNumber();
        var mm = ((timePart as String).substring(colon + 1, (timePart as String).length()) as String).toNumber();
        if (h == null || mm == null) { return; }
        mTimes.add(h * 3600 + mm * 60);
        mLabels.add(label.toUpper());
        mTypes.add(FuelStyle.typeOf(label.toUpper()));
    }

    function trim(s as String) as String {
        var a = 0;
        var b = s.length();
        while (a < b && (s.substring(a, a + 1) as String).equals(" ")) { a += 1; }
        while (b > a && (s.substring(b - 1, b) as String).equals(" ")) { b -= 1; }
        return s.substring(a, b) as String;
    }

    function resetProgress() as Void {
        mNext = 0;
        mAlertIdx = -1;
        mAlertUntil = 0;
    }

    // ---------- timing ----------
    function compute(info as Activity.Info) as Void {
        var ms = info.timerTime;
        mT = (ms == null) ? 0 : (ms / 1000);

        // Still before the ride and the date has changed (Edge left on overnight): pick the plan again
        if (mT == 0 && mLastT == 0) {
            var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            if ((d.month as Number) * 100 + (d.day as Number) != mToday) { loadSchedule(); }
        }

        // A ride has started on the override: from tomorrow it goes back to auto
        if (mOverride && !mStamped && mT > 0) {
            Application.Storage.setValue("ovDay", mToday);
            mStamped = true;
        }

        // New activity / timer reset
        if (mT + 5 < mLastT) { resetProgress(); }
        mLastT = mT;

        // Fire any feed that is due. Feeds missed by more than the alert window are skipped silently.
        while (mNext < mTimes.size() && mT >= mTimes[mNext]) {
            if (mT - mTimes[mNext] <= mAlertSecs) {
                mAlertIdx = mNext;
                mAlertUntil = mTimes[mNext] + mAlertSecs;
                beep();
                popup(mLabels[mNext], mTypes[mNext]);
            }
            mNext += 1;
        }
        if (mAlertIdx >= 0 && mT >= mAlertUntil) { mAlertIdx = -1; }
    }

    // Garmin's own alert over whatever page is showing (API 3.2+). The Edge only shows it if alerts
    // are enabled for this field, so the field also draws its own take-over in onUpdate().
    function popup(label as String, type as Number) as Void {
        if (WatchUi.DataField has :showAlert) {
            WatchUi.DataField.showAlert(new FuelAlert(label, type));
        }
    }

    function beep() as Void {
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_LOUD_BEEP);
        }
    }

    // ---------- drawing ----------
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        // Always black, also in the Edge's day (white) colour mode
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (mTimes.size() == 0) {
            drawFit(dc, w / 2, h / 2, "NO PLAN", w - 6, 0, [Graphics.FONT_SMALL, Graphics.FONT_XTINY]);
            return;
        }
        // A feed that has just fired is shown until its alert window ends
        var first = (mAlertIdx >= 0) ? mAlertIdx : mNext;
        if (first >= mTimes.size()) {
            // Whole plan eaten: laid out like a native field, caption over value
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawFit(dc, w / 2, h * 30 / 100, "FUEL PLAN", w - 6, 0, [Graphics.FONT_XTINY]);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawFit(dc, w / 2, h * 58 / 100, "DONE", w - 6, h * 50 / 100,
                [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY]);
            return;
        }

        if (h < 120) {
            drawSlot(dc, w, h, first);
        } else if (mAlertIdx >= 0) {
            FuelStyle.drawAlert(dc, mTypes[mAlertIdx], mLabels[mAlertIdx]);
        } else if (mT == 0) {
            drawPreview(dc, w, h);
        } else {
            // Full page: next feed as a block on top, upcoming feeds as rows below
            var rows = (h >= 240) ? 3 : ((h >= 180) ? 2 : 1);
            var rh = (h >= 240) ? (h * 20 / 100) : 40;
            var topH = h - rows * rh;
            drawNext(dc, w, topH, first);
            for (var r = 0; r < rows && first + 1 + r < mTimes.size(); r += 1) {
                drawRow(dc, topH + r * rh, w, rh, first + 1 + r, timeText(first + 1 + r));
            }
        }
    }

    // Normal slot, laid out like a native field: small label on top, big value below.
    // Before the timer starts it shows the plan name and feed count instead.
    function drawSlot(dc as Graphics.Dc, w as Number, h as Number, idx as Number) as Void {
        var label = mLabels[idx];
        var value = timeText(idx);
        if (mT == 0) {
            var n = mTimes.size();
            label = mPlanName;
            value = n + ((n == 1) ? " FEED" : " FEEDS");
        }
        var due = (idx == mAlertIdx);
        dc.setColor(FuelStyle.color(mTypes[idx]), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, due ? w : MARK, h);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawFit(dc, w / 2, h * 26 / 100, label, w - 2 * MARK - 4, 0,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawFit(dc, w / 2, h * 66 / 100, value, w - 2 * MARK - 4, h * 64 / 100,
            (due || mT == 0) ? [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY]
                : [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
    }

    // Top block of the full page: caption, feed name, big countdown.
    function drawNext(dc as Graphics.Dc, w as Number, h as Number, idx as Number) as Void {
        dc.setColor(FuelStyle.color(mTypes[idx]), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, MARK, h);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "NEXT FEED", Graphics.TEXT_JUSTIFY_CENTER);
        var top = 3 + dc.getFontHeight(Graphics.FONT_XTINY);
        var body = h - top;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawFit(dc, w / 2, top + body * 20 / 100, mLabels[idx], w - 2 * MARK - 8, body * 40 / 100,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawFit(dc, w / 2, top + body * 68 / 100, timeText(idx), w - 2 * MARK - 8, body * 62 / 100,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE, Graphics.FONT_MEDIUM]);
    }

    // Before the timer starts: which plan is loaded and why, then the whole plan with ride-clock times,
    // so it can be checked before rolling out.
    function drawPreview(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var n = mTimes.size();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "FUEL PLAN" + ((mPlanWhy.length() > 0) ? " - " + mPlanWhy : ""),
            Graphics.TEXT_JUSTIFY_CENTER);
        var capH = 3 + dc.getFontHeight(Graphics.FONT_XTINY);
        var nameH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawFit(dc, w / 2, capH + nameH / 2, mPlanName, w - 8, 0,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        var head = capH + nameH + 4;
        var rh = (h - head) / n;
        if (rh > 40) { rh = 40; }
        if (rh < 20) { rh = 20; }
        for (var i = 0; i < n && head + (i + 1) * rh <= h; i += 1) {
            drawRow(dc, head + i * rh, w, rh, i, clock(mTimes[i]));
        }
    }

    // One upcoming feed: hairline on top, colour marker, time-till, then the feed name.
    function drawRow(dc as Graphics.Dc, y as Number, w as Number, h as Number, idx as Number, time as String) as Void {
        var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var x = MARK + 8;
        var tw = w * 36 / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y, w, y);
        dc.setColor(FuelStyle.color(mTypes[idx]), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, y + 1, MARK, h - 1);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + h / 2, pickFont(dc, time, tw - 6, h - 4, fonts), time,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + tw, y + h / 2, pickFont(dc, mLabels[idx], w - x - tw - 4, h - 4, fonts), mLabels[idx],
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Largest of the fonts that fits maxW (and maxH, if not 0); the last one if none does.
    function pickFont(dc as Graphics.Dc, text as String, maxW as Number, maxH as Number,
                      fonts as Array<Graphics.FontType>) as Graphics.FontType {
        for (var i = 0; i < fonts.size(); i += 1) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxW && (maxH == 0 || dc.getFontHeight(fonts[i]) <= maxH)) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    // Draws text centred at (x,y) in the largest font that fits maxW (and maxH, if not 0).
    function drawFit(dc as Graphics.Dc, x as Number, y as Number, text as String, maxW as Number, maxH as Number,
                     fonts as Array<Graphics.FontType>) as Void {
        dc.drawText(x, y, pickFont(dc, text, maxW, maxH, fonts), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Time-till for a feed: "NOW" while it is due, else the countdown.
    function timeText(idx as Number) as String {
        return (idx == mAlertIdx) ? "NOW" : fmt(mTimes[idx] - mT);
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
    private var mLabel as String;
    private var mType as Number;

    function initialize(label as String, type as Number) {
        DataFieldAlert.initialize();
        mLabel = label;
        mType = type;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        FuelStyle.drawAlert(dc, mType, mLabel);
    }
}

// Feed types: colour and alert icon are picked from the words in the label.
module FuelStyle {
    const OTHER = 0;
    const GEL = 1;
    const CAFF = 2;
    const BAR = 3;
    const REFILL = 4;

    function typeOf(label as String) as Number {
        if (label.find("CAFF") != null) { return CAFF; }
        if (label.find("GEL") != null) { return GEL; }
        if (label.find("BAR") != null) { return BAR; }
        if (label.find("REFILL") != null || label.find("WATER") != null) { return REFILL; }
        return OTHER;
    }

    // Muted tones: distinct at a glance without shouting next to the other data fields.
    function color(type as Number) as Number {
        if (type == GEL)    { return 0xC9772B; }   // amber
        if (type == CAFF)   { return 0x7A4FA3; }   // plum
        if (type == BAR)    { return 0x8C6A45; }   // oat brown
        if (type == REFILL) { return 0x2E6F9E; }   // steel blue
        return 0x4A4F55;                           // slate
    }

    function textColor(type as Number) as Number {
        return Graphics.COLOR_WHITE;
    }

    function verb(type as Number) as String {
        return (type == REFILL) ? "REFILL" : "EAT";
    }

    // The alert screen, shared by the Edge's pop-up and the field's own take-over:
    // EAT / REFILL on top, icon in the middle, feed name below, on the feed type's colour.
    function drawAlert(dc as Graphics.Dc, type as Number, label as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bg = color(type);
        var fg = textColor(type);
        dc.setColor(fg, bg);
        dc.clear();
        dc.drawText(w / 2, h * 16 / 100, Graphics.FONT_LARGE, verb(type),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var s = ((w < h) ? w : h) * 45 / 100;
        drawIcon(dc, type, w / 2, h * 48 / 100, s, fg, bg);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        // Do not repeat the title in the label: REFILL / REFILL GRC reads as REFILL / GRC
        var title = verb(type);
        if (label.find(title) == 0) {
            label = label.substring(title.length(), label.length()) as String;
            while (label.length() > 0 && (label.substring(0, 1) as String).equals(" ")) {
                label = label.substring(1, label.length()) as String;
            }
        }
        var f = Graphics.FONT_LARGE;
        if (dc.getTextWidthInPixels(label, f) > w - 8) { f = Graphics.FONT_MEDIUM; }
        if (dc.getTextWidthInPixels(label, f) > w - 8) { f = Graphics.FONT_SMALL; }
        if (dc.getTextWidthInPixels(label, f) > w - 8) { f = Graphics.FONT_TINY; }
        if (dc.getTextWidthInPixels(label, f) > w - 8) { f = Graphics.FONT_XTINY; }
        dc.drawText(w / 2, h * 82 / 100, f, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draws the type's icon centred at (cx,cy) in a box of size s. fg is the icon, bg its cut-out detail.
    function drawIcon(dc as Graphics.Dc, type as Number, cx as Number, cy as Number, s as Number,
                      fg as Number, bg as Number) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        if (type == GEL || type == CAFF) {
            // Sachet: flat pouch with a torn-off corner, crimp lines top and bottom, a drop of gel at the tear
            dc.fillPolygon([[cx - s * 19 / 100, cy - s * 46 / 100], [cx + s * 5 / 100, cy - s * 46 / 100],
                            [cx + s * 19 / 100, cy - s * 30 / 100], [cx + s * 19 / 100, cy + s * 46 / 100],
                            [cx - s * 19 / 100, cy + s * 46 / 100]]);
            dc.fillCircle(cx + s * 21 / 100, cy - s * 45 / 100, s * 5 / 100);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - s * 19 / 100, cy - s * 27 / 100, s * 38 / 100, s * 3 / 100);
            dc.fillRectangle(cx - s * 19 / 100, cy + s * 36 / 100, s * 38 / 100, s * 3 / 100);
            if (type == CAFF) {
                // Lightning bolt cut out of the body (two triangles)
                dc.fillPolygon([[cx + s * 5 / 100, cy - s * 17 / 100], [cx - s * 11 / 100, cy + s * 9 / 100],
                                [cx + s * 3 / 100, cy + s * 9 / 100]]);
                dc.fillPolygon([[cx - s * 5 / 100, cy + s * 29 / 100], [cx + s * 11 / 100, cy + s * 1 / 100],
                                [cx - s * 3 / 100, cy + s * 1 / 100]]);
            }
        } else if (type == BAR) {
            // Wrapped bar with crimped ends
            dc.fillRectangle(cx - s * 36 / 100, cy - s * 17 / 100, s * 72 / 100, s * 34 / 100);
            dc.fillPolygon([[cx - s * 40 / 100, cy - s * 12 / 100], [cx - s * 50 / 100, cy - s * 21 / 100],
                            [cx - s * 45 / 100, cy], [cx - s * 50 / 100, cy + s * 21 / 100],
                            [cx - s * 40 / 100, cy + s * 12 / 100]]);
            dc.fillPolygon([[cx + s * 40 / 100, cy - s * 12 / 100], [cx + s * 50 / 100, cy - s * 21 / 100],
                            [cx + s * 45 / 100, cy], [cx + s * 50 / 100, cy + s * 21 / 100],
                            [cx + s * 40 / 100, cy + s * 12 / 100]]);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - s * 39 / 100, cy - s * 17 / 100, s * 3 / 100, s * 34 / 100);
            dc.fillRectangle(cx + s * 36 / 100, cy - s * 17 / 100, s * 3 / 100, s * 34 / 100);
        } else if (type == REFILL) {
            // Bottle: body, neck, cap, label band
            dc.fillRoundedRectangle(cx - s * 20 / 100, cy - s * 20 / 100, s * 40 / 100, s * 70 / 100, s * 8 / 100);
            dc.fillRectangle(cx - s * 11 / 100, cy - s * 36 / 100, s * 22 / 100, s * 20 / 100);
            dc.fillRectangle(cx - s * 6 / 100, cy - s * 50 / 100, s * 12 / 100, s * 11 / 100);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - s * 20 / 100, cy + s * 6 / 100, s * 40 / 100, s * 8 / 100);
        } else {
            dc.fillCircle(cx, cy, s * 30 / 100);
        }
    }
}
