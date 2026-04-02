import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Weather;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.SensorHistory;

class HanoiWatchFaceView extends WatchUi.WatchFace {

    // Screen dimensions - Forerunner 955 = 260x260px
    var screenW  = 260;
    var screenH  = 260;
    var cx       = 130; // center X
    var cy       = 130; // center Y

    // Heart rate history buffer (12 points for chart)
    var hrHistory as Array<Number> = new Array<Number>[12];
    var hrHistoryIndex as Number   = 0;

    function initialize() {
        WatchFace.initialize();
        for (var i = 0; i < 12; i++) {
            hrHistory[i] = 0;
        }
    }

    function onLayout(dc as Dc) as Void {
        screenW = dc.getWidth();
        screenH = dc.getHeight();
        cx = screenW / 2;
        cy = screenH / 2;
    }

    function onShow() as Void {}

    function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var now       = Time.now();
        var info      = Gregorian.info(now, Time.FORMAT_SHORT);

        var sysStats  = System.getSystemStats();
        var battery   = sysStats.battery.toNumber();

        var actInfo   = ActivityMonitor.getInfo();
        var steps     = actInfo.steps;
        var stepGoal  = actInfo.stepGoal;
        var floors    = 0;
        if (actInfo has :floorsClimbed && actInfo.floorsClimbed != null) {
            floors = actInfo.floorsClimbed;
        }

        var hrVal   = 0;
        var actData = Activity.getActivityInfo();
        if (actData != null && actData.currentHeartRate != null) {
            hrVal = actData.currentHeartRate;
        }

        if (hrVal > 0) {
            hrHistory[hrHistoryIndex % 12] = hrVal;
            hrHistoryIndex++;
        }

        var tempC      = 0;
        var conditions = null;
        if (Weather has :getCurrentConditions) {
            conditions = Weather.getCurrentConditions();
        }
        if (conditions != null) {
            tempC = conditions.temperature != null ? conditions.temperature.toNumber() : 0;
        }

        var sunriseStr = "5:49a";
        var sunsetStr  = "6:11p";

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawOuterRing(dc);
        drawProgressArcs(dc, steps, stepGoal);
        drawSunriseSunset(dc, sunriseStr, sunsetStr);
        drawDateRow(dc, info);
        drawTime(dc, clockTime);
        drawWeatherTemp(dc, tempC);
        drawLocation(dc);
        drawFloors(dc, floors);
        drawHeartRate(dc, hrVal);
        drawBattery(dc, battery);
        drawSteps(dc, steps, stepGoal);
        drawHRChart(dc);
    }

    // ---- Outer tick ring ----
    function drawOuterRing(dc as Dc) as Void {
        var r1 = cx - 4;
        var r2 = cx - 10;
        for (var i = 0; i < 60; i++) {
            var angle    = (i * 6 - 90) * Math.PI / 180.0;
            var isHour   = (i % 5 == 0);
            var r_inner  = isHour ? r2 : r2 + 3;
            var x1 = (cx + r1 * Math.cos(angle)).toNumber();
            var y1 = (cy + r1 * Math.sin(angle)).toNumber();
            var x2 = (cx + r_inner * Math.cos(angle)).toNumber();
            var y2 = (cy + r_inner * Math.sin(angle)).toNumber();
            dc.setColor(isHour ? 0x888888 : 0x404040, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(isHour ? 2 : 1);
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    // ---- Progress arc (steps) ----
    function drawProgressArcs(dc as Dc, steps as Number, stepGoal as Number) as Void {
        var r = cx - 7;
        dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 140, 40);

        if (stepGoal != null && stepGoal > 0) {
            var pct = steps.toFloat() / stepGoal.toFloat();
            if (pct > 1.0) { pct = 1.0; }
            var endAngle = (140 - pct * 260).toNumber();
            if (pct > 0) {
                dc.setColor(0x00AA44, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 140, endAngle);
            }
        }
    }

    // ---- Sunrise / Sunset row ----
    function drawSunriseSunset(dc as Dc, sunrise as String, sunset as String) as Void {
        var y = cy - 100; // raised up (47)

        // Sunrise icon + text
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 62, y + 4, 4);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 40, y, Graphics.FONT_XTINY, sunrise, Graphics.TEXT_JUSTIFY_CENTER);

        // Center separator dot
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, y + 4, 2);

        // Sunset text + icon
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 40, y, Graphics.FONT_XTINY, sunset, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 62, y + 4, 4);
    }

    // ---- Gregorian to Julian Day Number ----
    function jdFromDate(dd as Number, mm as Number, yy as Number) as Number {
        var a = (14 - mm) / 12;
        var y = yy + 4800 - a;
        var m = mm + 12 * a - 3;
        return dd + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045;
    }

    // ---- New moon JDN (Vietnam UTC+7) ----
    function lunarNewMoon(k as Number) as Number {
        var T   = k.toFloat() / 1236.85f;
        var T2  = T * T;
        var T3  = T2 * T;
        var dr  = Math.PI / 180.0f;
        var Jd1 = 2415020.75933f + 29.53058868f * k.toFloat() + 0.0001178f * T2 - 0.000000155f * T3;
        Jd1 += 0.00033f * Math.sin((166.56f + 132.87f * T - 0.009173f * T2) * dr);
        var M   = 359.2242f   + 29.10535608f  * k.toFloat() - 0.0000333f  * T2 - 0.00000347f  * T3;
        var Mpr = 306.0253f   + 385.81691806f * k.toFloat() + 0.0107306f  * T2 + 0.00001236f  * T3;
        var F   = 21.2964f    + 390.67050646f * k.toFloat() - 0.0016528f  * T2 - 0.00000239f  * T3;
        var C1  = (0.1734f - 0.000393f * T) * Math.sin(M * dr)
                + 0.0021f  * Math.sin(2.0f * M * dr)
                - 0.4068f  * Math.sin(Mpr * dr)
                + 0.0161f  * Math.sin(2.0f * Mpr * dr)
                - 0.0004f  * Math.sin(3.0f * Mpr * dr)
                + 0.0104f  * Math.sin(2.0f * F * dr)
                - 0.0051f  * Math.sin((M + Mpr) * dr)
                - 0.0074f  * Math.sin((M - Mpr) * dr)
                + 0.0004f  * Math.sin((2.0f * F + M) * dr)
                - 0.0004f  * Math.sin((2.0f * F - M) * dr)
                - 0.0006f  * Math.sin((2.0f * F + Mpr) * dr)
                + 0.0010f  * Math.sin((2.0f * F - Mpr) * dr)
                + 0.0005f  * Math.sin((2.0f * Mpr + M) * dr);
        var deltat;
        if (T < -11.0f) {
            deltat = 0.001f + 0.000839f * T + 0.0002261f * T2 - 0.00000845f * T3 - 0.000000081f * T * T3;
        } else {
            deltat = -0.000278f + 0.000265f * T + 0.000262f * T2;
        }
        return (Jd1 + C1 - deltat + 0.5f + 7.0f / 24.0f).toNumber();
    }

    // ---- Sun longitude sector 0-11 ----
    function lunarSunLon(jdn as Number) as Number {
        var T  = (jdn.toFloat() - 2451545.0f) / 36525.0f;
        var T2 = T * T;
        var dr = Math.PI / 180.0f;
        var M  = 357.5291f + 35999.0503f * T - 0.0001559f * T2 - 0.00000048f * T2 * T;
        var L0 = 280.46645f + 36000.76983f * T + 0.0003032f * T2;
        var DL = (1.9146f - 0.004817f * T - 0.000014f * T2) * Math.sin(dr * M)
               + (0.019993f - 0.000101f * T) * Math.sin(dr * 2.0f * M)
               + 0.00029f * Math.sin(dr * 3.0f * M);
        var omega = 125.04f - 1934.136f * T;
        var theta = (L0 + DL - 0.00569f - 0.00478f * Math.sin(omega * dr)) * dr;
        var twoPi = Math.PI * 2.0f;
        theta = theta - twoPi * (theta / twoPi).toNumber().toFloat();
        if (theta < 0.0f) { theta += twoPi; }
        return (theta / Math.PI * 6.0f).toNumber();
    }

    // ---- JDN of new moon of 11th lunar month in year yy ----
    function lunarGetMonth11(yy as Number) as Number {
        var offs = jdFromDate(31, 12, yy) - 2415021;
        var k    = (offs.toFloat() / 29.530588853f).toNumber();
        var nm   = lunarNewMoon(k);
        if (lunarSunLon(nm) >= 9) { nm = lunarNewMoon(k - 1); }
        return nm;
    }

    // ---- Leap month offset ----
    function lunarLeapOffset(a11 as Number) as Number {
        var k    = (0.5f + (a11.toFloat() - 2415021.076998695f) / 29.530588853f).toNumber();
        var i    = 1;
        var arc  = lunarSunLon(lunarNewMoon(k + i));
        var last = 0;
        do {
            last = arc;
            i++;
            arc = lunarSunLon(lunarNewMoon(k + i));
        } while (arc != last && i < 14);
        return i - 1;
    }

    // ---- Convert Gregorian to Lunar [day, month] ----
    function solarToLunar(dd as Number, mm as Number, yy as Number) as Array {
        var dayNumber  = jdFromDate(dd, mm, yy);
        var k          = (0.5f + (dayNumber.toFloat() - 2415021.076998695f) / 29.530588853f).toNumber();
        var monthStart = lunarNewMoon(k + 1);
        if (monthStart > dayNumber) { monthStart = lunarNewMoon(k); }

        var a11 = lunarGetMonth11(yy);
        var b11;
        if (a11 >= monthStart) {
            b11 = a11;
            a11 = lunarGetMonth11(yy - 1);
        } else {
            b11 = lunarGetMonth11(yy + 1);
        }

        var lunarDay   = dayNumber - monthStart + 1;
        var diff       = (0.5f + (monthStart.toFloat() - a11.toFloat()) / 29.530588853f).toNumber();
        var lunarMonth = diff + 11;

        if (b11 - a11 > 365) {
            var leapOff = lunarLeapOffset(a11);
            if (diff >= leapOff) { lunarMonth = diff + 10; }
        }

        if (lunarMonth > 12) { lunarMonth -= 12; }
        return [lunarDay, lunarMonth];
    }

    // ---- Date row + lunar date (same line) ----
    function drawDateRow(dc as Dc, info as Gregorian.Info) as Void {
        var dayNames = ["CN", "Thu 2", "Thu 3", "Thu 4", "Thu 5", "Thu 6", "Thu 7"];
        var dayStr   = dayNames[info.day_of_week - 1];
        var dateStr  = dayStr + ", " + info.day.toString() + " Thg " + info.month.toString();

        var lunar    = solarToLunar(info.day, info.month, info.year);
        var lunarStr = lunar[0].toString() + "/" + lunar[1].toString() + " AL";

        var y = cy - 65;

        // Date flush left
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(15, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Lunar date flush right
        dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 15, y, Graphics.FONT_XTINY, lunarStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Large time (y top = 88) ----
    function drawTime(dc as Dc, clockTime as ClockTime) as Void {
        var hour   = clockTime.hour;
        var minute = clockTime.min;

        var is24h  = System.getDeviceSettings().is24Hour;
        var suffix = "";
        if (!is24h) {
            suffix = hour >= 12 ? "p" : "a";
            if (hour > 12) { hour = hour - 12; }
            if (hour == 0) { hour = 12; }
        }

        var minuteStr = minute < 10 ? "0" + minute.toString() : minute.toString();
        var timeStr   = hour.toString() + ":" + minuteStr;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Center horizontally at cx-28 (slightly left of screen center)
        dc.drawText(cx - 28, cy - 42, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // AM/PM suffix below time, right side
        if (!is24h) {
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 38, cy + 20, Graphics.FONT_XTINY, suffix, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ---- Temperature (right side) ----
    function drawWeatherTemp(dc as Dc, temp as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 15, cy - 35, Graphics.FONT_SMALL, temp.toString() + "\u00B0C", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- "Hanoi" label ----
    function drawLocation(dc as Dc) as Void {
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 15, cy + 5, Graphics.FONT_XTINY, "Hanoi", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Stats row: floors (left) | heart+HR (center) | battery (right)  y = 160 ----

    function drawFloors(dc as Dc, floors as Number) as Void {
        var y = cy + 30;
        // Triangle icon flush left
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        var pts = [[15, y + 10], [21, y + 2], [27, y + 10]];
        dc.fillPolygon(pts);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(30, y + 1, Graphics.FONT_SMALL, floors.toString(), Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawHeartRate(dc as Dc, hr as Number) as Void {
        var y     = cy + 30;
        var hrStr = hr > 0 ? hr.toString() : "--";
        // Heart icon + value centered
        drawHeart(dc, cx - 14, y + 8, 6);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 4, y + 1, Graphics.FONT_SMALL, hrStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawHeart(dc as Dc, x as Number, y as Number, size as Number) as Void {
        dc.setColor(0xCC0000, Graphics.COLOR_TRANSPARENT);
        var s = size;
        dc.fillCircle(x - s/2, y - s/4, s/2);
        dc.fillCircle(x + s/2, y - s/4, s/2);
        var pts = [[x - s, y - s/4], [x + s, y - s/4], [x, y + s]];
        dc.fillPolygon(pts);
    }

    function drawBattery(dc as Dc, battery as Number) as Void {
        var y  = cy + 30;
        var bw = 18;
        var bh = 10;
        // Battery icon flush right (nub needs 2px extra)
        var bx = screenW - 17 - bw;
        var by = y + 7;
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(bx, by - bh/2, bw, bh);
        dc.fillRectangle(bx + bw, by - 2, 2, 4);
        var fillW     = ((battery.toFloat() / 100.0) * (bw - 2)).toNumber();
        var fillColor = battery > 30 ? 0x00CC44 : (battery > 15 ? 0xFFAA00 : 0xCC0000);
        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx + 1, by - bh/2 + 1, fillW, bh - 2);
        // Percentage text just left of icon
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx - 3, y + 1, Graphics.FONT_XTINY, battery.toString() + "%", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Steps row ----
    function drawSteps(dc as Dc, steps as Number, stepGoal as Number) as Void {
        var y = cy + 48;
        // Steps flush left
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(15, y, Graphics.FONT_SMALL, steps.toString(), Graphics.TEXT_JUSTIFY_LEFT);
        // Goal flush right
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var goalStr = stepGoal != null ? stepGoal.toString() : "0";
        dc.drawText(screenW - 15, y, Graphics.FONT_SMALL, goalStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- HR chart  (y = 193, height = 24) ----
    function drawHRChart(dc as Dc) as Void {
        var chartX = cx - 65; // 65
        var chartY = cy + 63; // 193
        var chartW = 130;
        var chartH = 24;

        // Dark background
        dc.setColor(0x4A2A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(chartX, chartY, chartW, chartH);

        var barW  = chartW / 12;
        var minHR = 50;
        var maxHR = 120;

        for (var i = 0; i < 12; i++) {
            if (hrHistory[i] > 0) {
                if (hrHistory[i] < minHR) { minHR = hrHistory[i]; }
                if (hrHistory[i] > maxHR) { maxHR = hrHistory[i]; }
            }
        }
        var hrRange = maxHR - minHR;
        if (hrRange < 10) { hrRange = 10; }

        dc.setColor(0xCC6633, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var idx = (hrHistoryIndex + i) % 12;
            var val = hrHistory[idx];
            if (val > 0) {
                var barH = ((val - minHR).toFloat() / hrRange.toFloat() * (chartH - 4)).toNumber();
                if (barH < 2) { barH = 2; }
                var bx = chartX + i * barW;
                var by = chartY + chartH - barH;
                dc.fillRectangle(bx + 1, by, barW - 1, barH);
            }
        }

        // HR range label below chart
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var rangeStr = minHR.toString() + " - " + maxHR.toString();
        dc.drawText(cx, chartY + chartH + 2, Graphics.FONT_XTINY, rangeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onHide() as Void {}
    function onExitSleep() as Void {}
    function onEnterSleep() as Void {}
}
