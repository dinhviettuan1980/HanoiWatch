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

    var screenW  = 260;
    var screenH  = 260;
    var cx       = 130;
    var cy       = 130;

    var hrHistory as Array<Number> = new Array<Number>[12];
    var hrHistoryIndex as Number   = 0;
    var avatarBitmap               = null;

    function initialize() {
        WatchFace.initialize();
        for (var i = 0; i < 12; i++) { hrHistory[i] = 0; }
    }

    function onLayout(dc as Dc) as Void {
        screenW = dc.getWidth();
        screenH = dc.getHeight();
        cx = screenW / 2;
        cy = screenH / 2;
    }

    function onShow() as Void {
        avatarBitmap = WatchUi.loadResource(Rez.Drawables.AvatarIcon);
    }

    function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var now       = Time.now();
        var info      = Gregorian.info(now, Time.FORMAT_SHORT);

        var sysStats = System.getSystemStats();
        var battery  = (sysStats != null && sysStats.battery != null) ? sysStats.battery.toNumber() : -1;

        var actInfo  = ActivityMonitor.getInfo();
        var steps    = actInfo.steps;
        var stepGoal = actInfo.stepGoal;

        var floors = 0;
        if (actInfo has :floorsClimbed && actInfo.floorsClimbed != null) {
            floors = actInfo.floorsClimbed;
        }

        var calories = 0;
        if (actInfo has :calories && actInfo.calories != null) {
            calories = actInfo.calories;
        }

        var bodyBattery = -1;
        if (actInfo has :bodyBattery && actInfo.bodyBattery != null) {
            bodyBattery = actInfo.bodyBattery;
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

        var tempC      = null;
        var conditions = null;
        if (Weather has :getCurrentConditions) {
            conditions = Weather.getCurrentConditions();
        }
        if (conditions != null && conditions.temperature != null) {
            tempC = conditions.temperature.toNumber();
        }

        var sunTimes   = calcSunriseSunset(info.day, info.month, info.year);
        var is24h      = System.getDeviceSettings().is24Hour;
        var sunriseStr = formatSunTime(sunTimes[0], is24h);
        var sunsetStr  = formatSunTime(sunTimes[1], is24h);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawOuterRing(dc);
        drawProgressArcs(dc, steps, stepGoal);
        drawSunriseSunset(dc, sunriseStr, sunsetStr);
        drawDateRow(dc, info);
        drawTime(dc, clockTime);
        drawWeatherTemp(dc, tempC);
        drawLocation(dc);
        drawAvatar(dc);
        drawCaloriesBodyBattery(dc, calories, bodyBattery);
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
            var angle   = (i * 6 - 90) * Math.PI / 180.0;
            var isHour  = (i % 5 == 0);
            var r_inner = isHour ? r2 : r2 + 3;
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

    // ---- Sunrise / Sunset ----
    function drawSunriseSunset(dc as Dc, sunrise as String, sunset as String) as Void {
        var y = cy - 110;
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 40, y, Graphics.FONT_XTINY, sunrise, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, y + 4, 2);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 40, y, Graphics.FONT_XTINY, sunset, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Lunar calendar (fixed algorithm) ----
    function jdFromDate(d as Number, m as Number, y as Number) as Number {
        var a = (14 - m) / 12;
        var yy = y + 4800 - a;
        var mm = m + 12 * a - 3;
        return d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045;
    }

    function newMoonJD(k as Number) as Number {
        var T  = k.toFloat() / 1236.85f;
        var T2 = T * T;
        var dr = Math.PI / 180.0f;
        var jd = 2415020.75933f + 29.53058868f * k.toFloat() + 0.0001178f * T2;
        jd += 0.00033f * Math.sin((166.56f + 132.87f * T) * dr);
        var M   = (359.2242f  + 29.10535608f  * k.toFloat()) * dr;
        var Mpr = (306.0253f  + 385.81691806f * k.toFloat()) * dr;
        var F   = (21.2964f   + 390.67050646f * k.toFloat()) * dr;
        var C   = (0.1734f - 0.000393f * T) * Math.sin(M)
                + 0.0021f * Math.sin(2.0f * M)
                - 0.4068f * Math.sin(Mpr)
                + 0.0161f * Math.sin(2.0f * Mpr)
                + 0.0104f * Math.sin(2.0f * F)
                - 0.0051f * Math.sin(M + Mpr)
                - 0.0074f * Math.sin(M - Mpr)
                - 0.0006f * Math.sin(2.0f * F + Mpr)
                + 0.0010f * Math.sin(2.0f * F - Mpr);
        // UTC+7 offset
        return (jd + C + 0.5f + 7.0f / 24.0f).toNumber();
    }

    function sunLonSector(jd as Number) as Number {
        var T  = (jd.toFloat() - 2451545.0f) / 36525.0f;
        var dr = Math.PI / 180.0f;
        var M  = (357.5291f + 35999.0503f * T) * dr;
        var L  = 280.46645f + 36000.76983f * T
               + (1.9146f - 0.004817f * T) * Math.sin(M)
               + 0.019993f * Math.sin(2.0f * M);
        var theta = L * dr;
        var twoPi = Math.PI * 2.0f;
        theta = theta - twoPi * (theta / twoPi).toNumber().toFloat();
        if (theta < 0.0f) { theta += twoPi; }
        return (theta / Math.PI * 6.0f).toNumber();
    }

    function getMonth11JD(y as Number) as Number {
        var jd31dec = jdFromDate(31, 12, y);
        var k       = ((jd31dec - 2415021).toFloat() / 29.530588853f).toNumber();
        var nm      = newMoonJD(k);
        if (sunLonSector(nm) >= 9) { nm = newMoonJD(k - 1); }
        return nm;
    }

    function solarToLunar(d as Number, m as Number, y as Number) as Array {
        var jd         = jdFromDate(d, m, y);
        var k          = ((jd - 2415021).toFloat() / 29.530588853f).toNumber();
        var monthStart = newMoonJD(k + 1);
        if (monthStart > jd) { monthStart = newMoonJD(k); }

        var a11 = getMonth11JD(y);
        if (a11 >= monthStart) {
            a11 = getMonth11JD(y - 1);
        } else {
            // next year's month 11 used only for leap month detection (not needed here)
        }

        var lunarDay   = jd - monthStart + 1;
        var diff       = ((monthStart - a11).toFloat() / 29.530588853f + 0.5f).toNumber();
        var lunarMonth = diff + 11;
        while (lunarMonth > 12) { lunarMonth -= 12; }
        while (lunarMonth < 1)  { lunarMonth += 12; }
        if (lunarDay < 1)  { lunarDay = 1; }
        if (lunarDay > 30) { lunarDay = 30; }

        return [lunarDay, lunarMonth];
    }

    // ---- Date row + lunar ----
    function drawDateRow(dc as Dc, info as Gregorian.Info) as Void {
        var dayNames = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"];
        var dayStr   = dayNames[info.day_of_week - 1];
        var dateStr  = dayStr + " " + info.day.toString() + "/" + info.month.toString();

        var lunar    = solarToLunar(info.day, info.month, info.year);
        var lunarStr = lunar[0].toString() + "/" + lunar[1].toString() + " AL";

        var y = cy - 85;
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(35, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 35, y, Graphics.FONT_XTINY, lunarStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Large time ----
    function drawTime(dc as Dc, clockTime as ClockTime) as Void {
        var hour   = clockTime.hour;
        var minute = clockTime.min;
        var is24h  = System.getDeviceSettings().is24Hour;
        if (!is24h) {
            if (hour > 12) { hour = hour - 12; }
            if (hour == 0) { hour = 12; }
        }
        var minuteStr = minute < 10 ? "0" + minute.toString() : minute.toString();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 28, cy - 42, Graphics.FONT_NUMBER_THAI_HOT, hour.toString() + ":" + minuteStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Temperature ----
    function drawWeatherTemp(dc as Dc, temp) as Void {
        var tempStr = (temp != null) ? temp.toString() + "\u00B0" : "---";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 15, cy - 38, Graphics.FONT_SMALL, tempStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Hanoi ----
    function drawLocation(dc as Dc) as Void {
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 15, cy + 2, Graphics.FONT_XTINY, "Hanoi", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Calories (left) + Body Battery (right) — row between date and time ----

    function drawAvatar(dc as Dc) as Void {
        if (avatarBitmap != null) {
            dc.drawBitmap(cx - 20, cy - 75, avatarBitmap);
        }
    }

    function drawCaloriesBodyBattery(dc as Dc, calories as Number, bodyBattery as Number) as Void {
        var y = cy - 60;

        // Calories flush left
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(15, y, Graphics.FONT_XTINY, calories.toString() + "cal", Graphics.TEXT_JUSTIFY_LEFT);

        // Body Battery flush right
        var bbStr   = bodyBattery >= 0 ? "BB:" + bodyBattery.toString() : "BB:--";
        var bbColor = bodyBattery > 60 ? 0x00CC44 : (bodyBattery > 30 ? 0xFFAA00 : (bodyBattery >= 0 ? 0xCC0000 : 0x666666));
        dc.setColor(bbColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 15, y, Graphics.FONT_XTINY, bbStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Stats row: floors | HR | battery ----
    function drawFloors(dc as Dc, floors as Number) as Void {
        var y = cy + 40;
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(15, y + 7, 4, 4);
        dc.fillRectangle(19, y + 4, 4, 4);
        dc.fillRectangle(23, y + 1, 4, 4);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(30, y + 1, Graphics.FONT_XTINY, floors.toString(), Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawHeartRate(dc as Dc, hr as Number) as Void {
        var y     = cy + 40;
        var hrStr = hr > 0 ? hr.toString() : "--";
        drawHeart(dc, cx - 14, y + 7, 5);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 4, y + 1, Graphics.FONT_XTINY, hrStr, Graphics.TEXT_JUSTIFY_LEFT);
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
        var y  = cy + 40;
        var bw = 18;
        var bh = 10;
        var bx = screenW - 17 - bw;
        var by = y + 7;
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(bx, by - bh/2, bw, bh);
        dc.fillRectangle(bx + bw, by - 2, 2, 4);
        if (battery >= 0) {
            var fillW     = ((battery.toFloat() / 100.0) * (bw - 2)).toNumber();
            var fillColor = battery > 30 ? 0x00CC44 : (battery > 15 ? 0xFFAA00 : 0xCC0000);
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx + 1, by - bh/2 + 1, fillW, bh - 2);
        }
        var batStr = battery >= 0 ? battery.toString() + "%" : "--%";
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx - 3, y + 1, Graphics.FONT_XTINY, batStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- Steps row ----
    function drawSteps(dc as Dc, steps as Number, stepGoal as Number) as Void {
        var y = cy + 62;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(32, y, Graphics.FONT_XTINY, steps.toString(), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var goalStr = stepGoal != null ? stepGoal.toString() : "0";
        dc.drawText(screenW - 32, y, Graphics.FONT_XTINY, goalStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- HR chart ----
    function drawHRChart(dc as Dc) as Void {
        var chartX = 70;
        var chartY = cy + 65;
        var chartW = screenW - 140;
        var chartH = 38;

        dc.setColor(0x3A1A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(chartX, chartY, chartW, chartH);

        var barW  = chartW / 12;
        var minHR = -1;
        var maxHR = -1;
        for (var i = 0; i < 12; i++) {
            if (hrHistory[i] > 0) {
                if (minHR < 0 || hrHistory[i] < minHR) { minHR = hrHistory[i]; }
                if (maxHR < 0 || hrHistory[i] > maxHR) { maxHR = hrHistory[i]; }
            }
        }
        if (minHR < 0) { minHR = 60; maxHR = 100; } // fallback khi chưa có data
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

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, chartY + chartH + 2, Graphics.FONT_XTINY,
            minHR.toString() + "-" + maxHR.toString(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Sunrise / Sunset calculation (Hanoi fixed coords, no GPS needed) ----
    // Hanoi: lat=21.0285°N, lng=105.8542°E, UTC+7
    function calcSunriseSunset(d as Number, m as Number, y as Number) as Array {
        var dr = Math.PI / 180.0f;

        // Day of year
        var doy = jdFromDate(d, m, y) - jdFromDate(1, 1, y) + 1;

        var lat = 21.0285f * dr;
        var B   = (360.0f / 365.0f * (doy - 81)) * dr;

        // Equation of time (minutes)
        var eot = 9.87f * Math.sin(2.0f * B) - 7.53f * Math.cos(B) - 1.5f * Math.sin(B);

        // Solar declination (radians)
        var decl = 23.45f * Math.sin(B) * dr;

        // Hour angle at sunrise/sunset (0.833° accounts for refraction + sun radius)
        var cosHA = (Math.cos(90.833f * dr) - Math.sin(lat) * Math.sin(decl))
                    / (Math.cos(lat) * Math.cos(decl));
        cosHA = cosHA < -1.0f ? -1.0f : (cosHA > 1.0f ? 1.0f : cosHA);
        var ha = Math.acos(cosHA) / dr; // degrees

        // Solar noon in local clock time (UTC+7, std meridian=105°, Hanoi lng=105.8542°)
        var solarNoon = 12.0f - eot / 60.0f + (105.0f - 105.8542f) * 4.0f / 60.0f;

        return [solarNoon - ha / 15.0f, solarNoon + ha / 15.0f];
    }

    function formatSunTime(h as Float, is24h as Boolean) as String {
        var hInt = h.toNumber();
        var mInt = ((h - hInt.toFloat()) * 60.0f).toNumber();
        if (mInt < 0)  { mInt = 0; }
        if (mInt > 59) { mInt = 59; }
        var suffix = "";
        if (!is24h) {
            suffix = hInt < 12 ? "a" : "p";
            if (hInt > 12) { hInt -= 12; }
            if (hInt == 0) { hInt = 12; }
        }
        return hInt.toString() + ":" + (mInt < 10 ? "0" : "") + mInt.toString() + suffix;
    }

    function onHide() as Void {}
    function onExitSleep() as Void {}
    function onEnterSleep() as Void {}
}
