import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

class GMTView extends WatchUi.WatchFace {

    // ── Geometry ─────────────────────────────────────────────────────────────
    private var _w    as Number = 280;
    private var _h    as Number = 280;
    private var _cx   as Number = 140;
    private var _cy   as Number = 140;
    private var _arcR as Number = 128;

    // ── Typography — vector fonts with pixel-precise sizing ──────────────────
    private var _fTime  = null;  // Center time: 62px condensed bold
    private var _fSec   = null;  // Seconds: 22px condensed bold
    private var _fData  = null;  // Data values: 14px condensed bold
    private var _fLabel = null;  // Labels: 11px thin
    private var _fGmt   = null;  // GMT time: 15px condensed
    private var _fDate  = null;  // Date "Apr 6": larger bold
    private var _fHR    = null;  // HR digits: 33% larger than data

    // ── Font height cache ────────────────────────────────────────────────────
    private var _hTime  as Number = 62;
    private var _hSec   as Number = 22;
    private var _hData  as Number = 14;
    private var _hLabel as Number = 11;
    private var _hGmt   as Number = 15;
    private var _hDate  as Number = 18;
    private var _hHR    as Number = 30;

    // ── State ────────────────────────────────────────────────────────────────
    private var _isAwake    as Boolean = true;
    private var _sunriseMin as Number  = -1;
    private var _sunsetMin  as Number  = -1;

    // ── Seconds clip region ──────────────────────────────────────────────────
    private var _secX as Number = 0;
    private var _secY as Number = 0;
    private var _secW as Number = 0;
    private var _secH as Number = 0;

    // ── Heart pulse clip region ──────────────────────────────────────────────
    private var _hrX as Number = 0;
    private var _hrY as Number = 0;
    private var _hrW as Number = 0;
    private var _hrH as Number = 0;

    // ── Eclipse table ────────────────────────────────────────────────────────
    // Total lunar eclipses 2026-2040 from NASA eclipse catalog
    // (umbral magnitude >= 1.0). Format: YYYYMMDD
    private var _eclipseDates as Array<Number> = [
        20260303,  // 2026 Mar 03 — umbral mag 1.151
        20281231,  // 2028 Dec 31 — umbral mag 1.246
        20290626,  // 2029 Jun 26 — umbral mag 1.844
        20291220,  // 2029 Dec 20 — umbral mag 1.117
        20320425,  // 2032 Apr 25 — umbral mag 1.191
        20321018,  // 2032 Oct 18 — umbral mag 1.103
        20330414,  // 2033 Apr 14 — umbral mag 1.094
        20331008,  // 2033 Oct 08 — umbral mag 1.350
        20360211,  // 2036 Feb 11 — umbral mag 1.299
        20360807,  // 2036 Aug 07 — umbral mag 1.454
        20370131,  // 2037 Jan 31 — umbral mag 1.207
        20400526,  // 2040 May 26 — umbral mag 1.535
        20401118   // 2040 Nov 18 — umbral mag 1.397
    ];

    function initialize() { WatchFace.initialize(); }

    function onLayout(dc as Dc) as Void {
        _w    = dc.getWidth();
        _h    = dc.getHeight();
        _cx   = _w / 2;
        _cy   = _h / 2;
        _arcR = _w * 48 / 100;

        // Build vector fonts scaled to screen — condensed faces for density
        if (Graphics has :getVectorFont) {
            _fTime  = Graphics.getVectorFont({:face => ["RobotoBlack", "RobotoCondensedBold", "Swiss721Bold"], :size => _w * 331 / 1000});
            _fSec   = Graphics.getVectorFont({:face => ["RobotoBlack", "RobotoCondensedBold", "Swiss721Bold"], :size => _w * 16 / 100});
            _fData  = Graphics.getVectorFont({:face => ["RobotoBlack", "RobotoCondensedBold", "Swiss721Bold"], :size => _w * 825 / 10000});
            _fLabel = Graphics.getVectorFont({:face => ["RobotoBlack", "RobotoCondensedBold", "Swiss721Bold"], :size => _w * 66 / 1000});
            _fGmt   = Graphics.getVectorFont({:face => ["RobotoBlack", "RobotoCondensedBold", "Swiss721Bold"], :size => _w * 77 / 1000});
            _fDate  = Graphics.getVectorFont({:face => ["RobotoBlack", "Swiss721Bold", "RobotoCondensedBold"], :size => _w * 75 / 1000});
            // HR digits: 33% larger than _fData (8.25% × 1.33 ≈ 11%)
            _fHR    = Graphics.getVectorFont({:face => ["RobotoBlack", "RobotoCondensedBold", "Swiss721Bold"], :size => _w * 110 / 1000});
        }

        // Cache font heights (fall back to system fonts if vectors unavailable)
        _hTime  = (_fTime  != null) ? dc.getFontHeight(_fTime)  : dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        _hSec   = (_fSec   != null) ? dc.getFontHeight(_fSec)   : dc.getFontHeight(Graphics.FONT_TINY);
        _hData  = (_fData  != null) ? dc.getFontHeight(_fData)  : dc.getFontHeight(Graphics.FONT_XTINY);
        _hLabel = (_fLabel != null) ? dc.getFontHeight(_fLabel) : dc.getFontHeight(Graphics.FONT_XTINY);
        _hGmt   = (_fGmt   != null) ? dc.getFontHeight(_fGmt)  : dc.getFontHeight(Graphics.FONT_XTINY);
        _hDate  = (_fDate  != null) ? dc.getFontHeight(_fDate) : dc.getFontHeight(Graphics.FONT_TINY);
        _hHR    = (_fHR    != null) ? dc.getFontHeight(_fHR)   : dc.getFontHeight(Graphics.FONT_TINY);

        // Seconds clip — generous padding for vector font ascenders
        var digitsDims = dc.getTextDimensions("00", _secFont());
        _secW = digitsDims[0] + 20;
        _secH = _hSec + 16;
        _secX = _w * 82 / 100 - _secW / 2;
        _secY = _cy - _hSec / 2 - 8;

        // Heart pulse clip — tight to actual heart shape bounds
        var rBase = _w * 4 / 100;
        if (rBase < 7) { rBase = 7; }
        var rPulse = rBase * 12 / 10 + 2;
        var hrCx = _cx - _w * 25 / 100;
        var hrCy = _h * 69 / 100;
        // Heart top = cy - 3r/4, bottom = cy + r, left = cx - r, right = cx + r
        _hrX = hrCx - rPulse - 1;
        _hrY = hrCy - rPulse * 3 / 4 - 1;         // tight to top of lobes
        _hrW = rPulse * 2 + 2;
        _hrH = rPulse * 7 / 4 + 2;                 // from lobes top to triangle bottom
    }

    // ═════════════════════════════════════════════════════════════════════════
    function onUpdate(dc as Dc) as Void {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        _refreshSolarData();

        _drawDaylightArc(dc);
        _drawTickMarks(dc);
        _drawStepsBar(dc);
        _drawCenterTime(dc);
        _drawDate(dc);
        _drawWeather(dc);
        if (_isAwake) { _drawSeconds(dc); }
        _drawBattery(dc);
        _drawGmt1(dc);
        _drawGmt2(dc);
        _drawHR(dc);
        _drawSunset(dc);
        _drawMoon(dc);
    }

    function onPartialUpdate(dc as Dc) as Void {
        // Seconds
        dc.setClip(_secX, _secY, _secW, _secH);
        dc.setColor(0x000000, 0x000000);
        dc.fillRectangle(_secX, _secY, _secW, _secH);
        _drawSeconds(dc);
        dc.clearClip();

        // Heart pulse — only redraw the icon area, not the value below
        dc.setClip(_hrX, _hrY, _hrW, _hrH);
        dc.setColor(0x000000, 0x000000);
        dc.fillRectangle(_hrX, _hrY, _hrW, _hrH);
        _drawHeartIconOnly(dc);
        dc.clearClip();
    }

    // Draw just the heart shape (no number) — used by partial update
    private function _drawHeartIconOnly(dc as Dc) as Void {
        var rBase = _w * 4 / 100;
        if (rBase < 7) { rBase = 7; }
        var sec = System.getClockTime().sec;
        var r = (sec % 2 == 0) ? (rBase * 12 / 10) : rBase;
        _drawHeart(dc, _cx - _w * 25 / 100, _h * 69 / 100, r);
    }

    function onEnterSleep() as Void { _isAwake = false; WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { _isAwake = true;  WatchUi.requestUpdate(); }

    // ── Font accessors with fallback ─────────────────────────────────────────
    private function _timeFont()  { return _fTime  != null ? _fTime  : Graphics.FONT_NUMBER_HOT; }
    private function _secFont()   { return _fSec   != null ? _fSec   : Graphics.FONT_TINY; }
    private function _dataFont()  { return _fData  != null ? _fData  : Graphics.FONT_XTINY; }
    private function _labelFont() { return _fLabel != null ? _fLabel : Graphics.FONT_XTINY; }
    private function _gmtFont()   { return _fGmt   != null ? _fGmt   : Graphics.FONT_XTINY; }
    private function _dateFont()  { return _fDate  != null ? _fDate  : Graphics.FONT_TINY; }
    private function _hrFont()    { return _fHR    != null ? _fHR    : Graphics.FONT_TINY; }

    // ═════════════════════════════════════════════════════════════════════════
    //  BACKGROUND
    // ═════════════════════════════════════════════════════════════════════════

    private function _drawSpoke(dc as Dc) as Void {
        dc.setPenWidth(1);
        dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, 0, _cx, _h);
    }

    private function _drawTickMarks(dc as Dc) as Void {
        var outerR = _w / 2 - 2;
        var twoPi = Math.PI * 2.0;
        for (var i = 0; i < 60; i++) {
            var angle = (i.toFloat() / 60.0f) * twoPi - Math.PI / 2.0;
            var cosA = Math.cos(angle).toFloat();
            var sinA = Math.sin(angle).toFloat();
            var major = (i % 5 == 0);
            var len = major ? _w * 3 / 100 : _w * 15 / 1000;
            var innerR = outerR - len;
            dc.setColor(major ? 0xAAAAAA : 0x555555, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(major ? 2 : 1);
            dc.drawLine(
                _cx + (cosA * innerR).toNumber(), _cy + (sinA * innerR).toNumber(),
                _cx + (cosA * outerR).toNumber(), _cy + (sinA * outerR).toNumber());
        }
        dc.setPenWidth(1);
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  DAYLIGHT ARC
    // ═════════════════════════════════════════════════════════════════════════

    private function _drawDaylightArc(dc as Dc) as Void {
        if (_sunriseMin < 0 || _sunsetMin < 0) { return; }
        var nowMin = System.getClockTime().hour * 60 + System.getClockTime().min;
        if (nowMin < _sunriseMin || nowMin > _sunsetMin) { return; }

        var minsLeft = _sunsetMin - nowMin;
        dc.setColor(_arcColor(minsLeft), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);

        var startDeg = _minToDeg(nowMin);
        var endDeg   = _minToDeg(_sunsetMin);
        if (startDeg != endDeg) {
            dc.drawArc(_cx, _cy, _arcR, Graphics.ARC_CLOCKWISE, startDeg, endDeg);
        }

        // Sun dot
        dc.fillCircle(_degX(startDeg, _arcR), _degY(startDeg, _arcR), _w * 17 / 1000);

        // Sunset marker
        if (minsLeft < 120 && minsLeft > 0) {
            dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_degX(endDeg, _arcR), _degY(endDeg, _arcR), _w * 13 / 1000);
        }
        dc.setPenWidth(1);
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  STEPS BAR
    // ═════════════════════════════════════════════════════════════════════════

    private function _drawStepsBar(dc as Dc) as Void {
        var steps = 0;
        var goal  = 10000;
        if (Toybox.ActivityMonitor has :getInfo) {
            var ai = ActivityMonitor.getInfo();
            if (ai != null) {
                if (ai.steps    != null) { steps = ai.steps; }
                if (ai.stepGoal != null && ai.stepGoal > 0) { goal = ai.stepGoal; }
            }
        }
        var filled = steps * 10 / goal;
        if (filled > 10) { filled = 10; }

        // Vertical bar to the right of the center time
        var bx = _w * 65 / 100;
        var bw = _w * 35 / 1000;
        if (bw < 5) { bw = 5; }
        // 33% taller: scale segment height and spacing
        var bh = _h * 35 / 1000;
        if (bh < 8) { bh = 8; }
        var sp = _h * 44 / 1000;
        // Bottom segment aligned with bottom of the time block
        var by = _cy + _hTime * 5 / 10 - bh;

        for (var i = 0; i < 10; i++) {
            var y = by - i * sp;
            if (i < filled) {
                dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);  // bright blue — taken
            } else {
                dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);  // dark blue — remaining
            }
            dc.fillRectangle(bx, y, bw, bh);
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  CENTER TIME
    // ═════════════════════════════════════════════════════════════════════════

    private function _drawCenterTime(dc as Dc) as Void {
        var ct = System.getClockTime();
        var hour = ct.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var font = _timeFont();
        var tuck = _hTime / 6;

        // Lift the whole time block up a touch — vector fonts have heavy bottom padding
        var lift = _hTime / 8;

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - _hTime + tuck - lift, font, hour.format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Minutes (blue)
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - tuck - lift, font, ct.min.format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  DATA FIELDS — clean typographic hierarchy
    // ═════════════════════════════════════════════════════════════════════════

    // ── 12 o'clock: Date ─────────────────────────────────────────────────────
    private function _drawDate(dc as Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var y = _h * 6 / 100;
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, _dateFont(),
                    (info.month as String).substring(0, 3) + " " + info.day,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y + _hDate, _dateFont(),
                    info.day_of_week as String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Weather ──────────────────────────────────────────────────────────────
    private function _drawWeather(dc as Dc) as Void {
        if (!(Toybox.Weather has :getCurrentConditions)) { return; }
        var cond = Weather.getCurrentConditions();
        if (cond == null || cond.condition == null) { return; }

        var c = cond.condition as Number;
        var kind = 0;     // 0=clear 1=ptcld 2=cloud 3=rain 4=snow 5=storm 6=fog 7=wind
        var color = 0x555555;

        if (c == 0 || c == 22 || c == 23 || c == 40) {
            kind = 0; color = 0xFFAA00;
        } else if (c == 1 || c == 2 || c == 52) {
            kind = 1; color = 0xAAAAAA;
        } else if (c == 20) {
            kind = 2; color = 0xAAAAAA;
        } else if (c == 3 || c == 14 || c == 15 || c == 25 || c == 26 || c == 31
                || c == 11 || c == 24 || c == 27) {
            kind = 3; color = 0x00AAFF;
        } else if (c == 4 || c == 16 || c == 17 || c == 48) {
            kind = 4; color = 0xAAAAFF;
        } else if (c == 6 || c == 12 || c == 28 || c == 32 || c == 41 || c == 42) {
            kind = 5; color = 0xFF5500;
        } else if (c == 8 || c == 9 || c == 29 || c == 39) {
            kind = 6; color = 0x555555;
        } else if (c == 5) {
            kind = 7; color = 0x00AAFF;
        } else if (c == 7 || c == 18 || c == 19 || c == 21 || c == 49 || c == 50) {
            kind = 3; color = 0x55AAFF;
        }

        // Below the time, above the battery
        var icx = _cx;
        var sz = _w * 80 / 1000;
        var icy = _h * 73 / 100;
        _drawWeatherIcon(dc, icx, icy, sz, kind, color);
    }

    // ── Weather icon shapes ──────────────────────────────────────────────────
    private function _drawWeatherIcon(dc as Dc, cx as Number, cy as Number,
                                      sz as Number, kind as Number, col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (kind == 0) {
            // CLEAR — sun: filled circle + rays
            dc.fillCircle(cx, cy, sz / 2);
            dc.setPenWidth(2);
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4.0;
                var x1 = cx + (Math.cos(a) * (sz * 7 / 10).toFloat()).toNumber();
                var y1 = cy + (Math.sin(a) * (sz * 7 / 10).toFloat()).toNumber();
                var x2 = cx + (Math.cos(a) * (sz * 95 / 100).toFloat()).toNumber();
                var y2 = cy + (Math.sin(a) * (sz * 95 / 100).toFloat()).toNumber();
                dc.drawLine(x1, y1, x2, y2);
            }
            dc.setPenWidth(1);
        } else if (kind == 1) {
            // PT CLD — small sun + cloud
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - sz / 2, cy - sz / 4, sz / 3);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            _drawCloud(dc, cx + sz / 5, cy + sz / 5, sz);
        } else if (kind == 2) {
            // CLOUDY — single cloud
            _drawCloud(dc, cx, cy, sz);
        } else if (kind == 3) {
            // RAIN — cloud + drops
            _drawCloud(dc, cx, cy - sz / 4, sz);
            dc.setPenWidth(2);
            for (var i = -1; i <= 1; i++) {
                var dx = i * sz / 3;
                dc.drawLine(cx + dx, cy + sz / 3, cx + dx - sz / 6, cy + sz * 6 / 10);
            }
            dc.setPenWidth(1);
        } else if (kind == 4) {
            // SNOW — six-pointed snowflake
            dc.setPenWidth(2);
            var r1 = (sz * 9 / 10).toFloat();
            for (var i = 0; i < 6; i++) {
                var a = i * Math.PI / 3.0;
                var ex = cx + (Math.cos(a) * r1).toNumber();
                var ey = cy + (Math.sin(a) * r1).toNumber();
                dc.drawLine(cx, cy, ex, ey);
                // Branches at 2/3 along each arm
                var bx = cx + (Math.cos(a) * r1 * 2.0f / 3.0f).toNumber();
                var by = cy + (Math.sin(a) * r1 * 2.0f / 3.0f).toNumber();
                var ba1 = a + Math.PI / 3.0;
                var ba2 = a - Math.PI / 3.0;
                var blen = r1 / 3.0f;
                dc.drawLine(bx, by,
                    bx + (Math.cos(ba1) * blen).toNumber(),
                    by + (Math.sin(ba1) * blen).toNumber());
                dc.drawLine(bx, by,
                    bx + (Math.cos(ba2) * blen).toNumber(),
                    by + (Math.sin(ba2) * blen).toNumber());
            }
            dc.setPenWidth(1);
        } else if (kind == 5) {
            // STORM — cloud + lightning bolt
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            _drawCloud(dc, cx, cy - sz / 4, sz);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            // Simple bolt: triangle pointing down
            var bx = cx;
            var by = cy + sz / 3;
            dc.fillPolygon([[bx - sz / 6, by],
                            [bx + sz / 8, by],
                            [bx, by + sz / 2]]);
        } else if (kind == 6) {
            // FOG — three horizontal lines
            dc.setPenWidth(2);
            for (var i = -1; i <= 1; i++) {
                var fy = cy + i * sz / 4;
                dc.drawLine(cx - sz / 2, fy, cx + sz / 2, fy);
            }
            dc.setPenWidth(1);
        } else if (kind == 7) {
            // WIND — wavy lines
            dc.setPenWidth(2);
            for (var j = -1; j <= 1; j++) {
                var wy = cy + j * sz / 3;
                dc.drawLine(cx - sz * 3 / 4, wy, cx + sz / 3, wy);
                dc.drawLine(cx + sz / 3, wy, cx + sz / 2, wy - sz / 6);
            }
            dc.setPenWidth(1);
        }
    }

    // Simple cloud: 3 overlapping filled circles
    private function _drawCloud(dc as Dc, cx as Number, cy as Number, sz as Number) as Void {
        var r = sz / 3;
        dc.fillCircle(cx - r, cy, r);
        dc.fillCircle(cx + r, cy, r);
        dc.fillCircle(cx, cy - r / 2, r * 11 / 10);
        dc.fillRectangle(cx - r, cy, r * 2, r);
    }

    // ── 3 o'clock: Seconds ───────────────────────────────────────────────────
    private function _drawSeconds(dc as Dc) as Void {
        var x = _w * 82 / 100;
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, _cy - _hSec / 2, _secFont(),
                    System.getClockTime().sec.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── 6 o'clock: Battery ───────────────────────────────────────────────────
    private function _drawBattery(dc as Dc) as Void {
        var bat = System.getSystemStats().battery.toNumber();
        var y = _h * 80 / 100;

        // Pick color based on level
        var color;
        if (bat > 30)       { color = 0x00FF55; }
        else if (bat > 15)  { color = 0xFFAA00; }
        else                { color = 0xFF5555; }

        // Battery icon — horizontal cell with terminal cap (50% larger)
        var iconW = _w * 9 / 100;
        var iconH = _h * 52 / 1000;
        if (iconH < 12) { iconH = 12; }
        var capW = iconW / 10;
        if (capW < 2) { capW = 2; }
        var capH = iconH * 3 / 5;
        var iconX = _cx - iconW / 2 - capW / 2;
        var iconY = y;

        // Outline
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(iconX, iconY, iconW, iconH);
        // Terminal cap
        dc.fillRectangle(iconX + iconW, iconY + (iconH - capH) / 2, capW, capH);

        // Fill proportional to charge
        var fillW = (iconW - 4) * bat / 100;
        if (fillW < 0) { fillW = 0; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(iconX + 2, iconY + 2, fillW, iconH - 4);

        // Percentage text below
        dc.drawText(_cx, y + iconH + 2, _dataFont(), bat + "%", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── 9 o'clock (lower): GMT 2 ─────────────────────────────────────────────
    private function _drawGmt1(dc as Dc) as Void {
        var slotH = (_hGmt + 1) * 3;
        _drawGmtSlot(dc, _w * 9 / 100, _cy - slotH / 2 + _hGmt / 2,
                     _propNum("gmt2Offset", -300), _propStr("gmt2Label", "EST"),
                     _propNum("gmt2DstRule", 1), _w * 8 / 100);
    }

    // ── 10 o'clock (upper): GMT 1 ────────────────────────────────────────────
    private function _drawGmt2(dc as Dc) as Void {
        _drawGmtSlot(dc, _w * 17 / 100, _h * 18 / 100,
                     _propNum("gmt1Offset", -600), _propStr("gmt1Label", "HST"),
                     _propNum("gmt1DstRule", 0), 0);
    }

    private function _drawGmtSlot(dc as Dc, x as Number, y as Number,
                                  utcOffsetMin as Number, label as String,
                                  dstRule as Number, indent as Number) as Void {
        // Check if DST is currently active for this timezone
        var effectiveOffset = utcOffsetMin;
        var effectiveLabel = label;
        if (dstRule > 0 && _isDST(dstRule, utcOffsetMin)) {
            effectiveOffset = utcOffsetMin + 60;
            // Swap S→D in label (EST→EDT, CST→CDT, AEST→AEDT, etc.)
            effectiveLabel = _dstLabel(label);
        }

        var m = Time.now().add(new Time.Duration(effectiveOffset * 60));
        var info = Gregorian.utcInfo(m, Time.FORMAT_MEDIUM);
        var hour = info.hour as Number;
        var min  = info.min as Number;
        var sfx = (hour >= 12) ? "PM" : "AM";
        hour = hour % 12;
        if (hour == 0) { hour = 12; }

        var localMin = System.getClockTime().timeZoneOffset / 60;
        var rel = effectiveOffset - localMin;

        var line = _hData + 1;

        // Line 1: Time
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _dataFont(),
                    hour + ":" + min.format("%02d") + " " + sfx,
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Line 2: Day
        dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + indent, y + line, _dataFont(),
                    info.day_of_week as String, Graphics.TEXT_JUSTIFY_LEFT);

        // Line 3: label + offset in green
        dc.setColor(0x00FF55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + indent, y + line * 2, _labelFont(),
                    effectiveLabel + " " + _fmtOffsetOnly(rel),
                    Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ── 8 o'clock: Heart Rate ────────────────────────────────────────────────
    // Vertical stack: heart icon on top, number below
    // Mirrored with sunset across vertical axis
    private function _drawHR(dc as Dc) as Void {
        var rBase = _w * 4 / 100;
        if (rBase < 7) { rBase = 7; }
        var sec = System.getClockTime().sec;
        var r = (sec % 2 == 0) ? (rBase * 12 / 10) : rBase;

        var offsetX = _w * 25 / 100;
        var iconCx = _cx - offsetX;
        var iconCy = _h * 69 / 100;
        _drawHeart(dc, iconCx, iconCy, r);

        var hr = _getHeartRate();
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(iconCx, iconCy + rBase + 4, _hrFont(),
                    (hr > 0) ? hr.toString() : "--", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Heart shape: two top circles + bottom triangle
    private function _drawHeart(dc as Dc, cx as Number, cy as Number, r as Number) as Void {
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        var lobeR = r / 2;
        var lobeY = cy - r / 4;
        // Two top lobes
        dc.fillCircle(cx - lobeR, lobeY, lobeR);
        dc.fillCircle(cx + lobeR, lobeY, lobeR);
        // Bottom triangle pointing down
        dc.fillPolygon([[cx - r, lobeY],
                        [cx + r, lobeY],
                        [cx, cy + r]]);
    }

    // ── 4 o'clock: Sunset ────────────────────────────────────────────────────
    // Vertical stack: sun icon on top, time below
    // Mirrored with HR across vertical axis
    private function _drawSunset(dc as Dc) as Void {
        var offsetX = _w * 25 / 100;
        var iconR = _w * 4 / 100;
        if (iconR < 7) { iconR = 7; }
        var iconCx = _cx + offsetX;
        // Drop the sun's horizon line so its visual mass aligns with the heart.
        // Heart center is at 70%, heart visual extends ~r/2 above; the sun's
        // visible half-circle is fully above the horizon, so push horizon down.
        var horizonY = _h * 74 / 100;
        var iconCy = horizonY;

        // Half-circle (top hemisphere), drawn above horizon
        dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(iconCx, iconCy, iconR);
        // Mask off the bottom half of the circle
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(iconCx - iconR - 1, iconCy + 1, iconR * 2 + 2, iconR + 2);

        // Horizon line
        dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(iconCx - iconR * 3 / 2, iconCy + 1,
                    iconCx + iconR * 3 / 2, iconCy + 1);

        // Rays radiating UP from the half-sun (angles in the upper half)
        // Upper half on screen = sin negative = angles π to 2π in standard math
        var rayInner = (iconR * 13 / 10).toFloat();
        var rayOuter = (iconR * 18 / 10).toFloat();
        for (var i = 0; i < 5; i++) {
            // 5 rays evenly spaced from -150° to -30° (above horizon)
            var deg = -150.0 + i * 30.0;
            var a = deg * Math.PI / 180.0;
            var cosA = Math.cos(a).toFloat();
            var sinA = Math.sin(a).toFloat();
            dc.drawLine(
                iconCx + (cosA * rayInner).toNumber(),
                iconCy + (sinA * rayInner).toNumber(),
                iconCx + (cosA * rayOuter).toNumber(),
                iconCy + (sinA * rayOuter).toNumber());
        }
        dc.setPenWidth(1);

        // Show NEXT relevant solar event with 20-min grace after each.
        // From (sunrise+20) to (sunset+20): show sunset
        // From (sunset+20) to (sunrise+20 next day): show sunrise
        var str = "--:--";
        var displayMin = _nextSolarEventMin();
        if (displayMin >= 0) {
            var h = displayMin / 60;
            var mn = displayMin % 60;
            if (!System.getDeviceSettings().is24Hour) {
                h = h % 12;
                if (h == 0) { h = 12; }
            }
            str = h + ":" + mn.format("%02d");
        }
        dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(iconCx, horizonY + 4, _dataFont(), str,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Returns the minutes-of-day to display: sunset during day, sunrise at night.
    // Toggle happens 20 minutes after each event.
    private function _nextSolarEventMin() as Number {
        if (_sunriseMin < 0 || _sunsetMin < 0) { return _sunsetMin; }
        var ct = System.getClockTime();
        var nowMin = ct.hour * 60 + ct.min;
        var grace = 20;

        // After sunrise+20 and before sunset+20 → show sunset
        if (nowMin >= _sunriseMin + grace && nowMin < _sunsetMin + grace) {
            return _sunsetMin;
        }
        // Otherwise (deep night before sunrise, or after sunset+20) → show sunrise
        return _sunriseMin;
    }

    // ── 2 o'clock: Moon ──────────────────────────────────────────────────────
    private function _drawMoon(dc as Dc) as Void {
        var phase = _getMoonPhase();
        var ecl = _isLunarEclipse();
        var col = ecl ? 0xFF5555 : 0xFFFFAA;

        // Latitude tilt: at equator (lat=0) the terminator is horizontal,
        // at poles (lat=±90) it's vertical (our default rendering).
        var lat = _getLatitude();

        var r = _w * 6 / 100;
        var cx = _w * 76 / 100;
        var cy = _h * 24 / 100;
        _drawMoonIcon(dc, cx, cy, r, phase, col, lat);
    }

    // ── Steps text (subtle) ──────────────────────────────────────────────────
    private function _drawSteps(dc as Dc) as Void {
        var x = _w * 30 / 100;
        var y = _h * 77 / 100;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _labelFont(), "STEPS", Graphics.TEXT_JUSTIFY_CENTER);
        var steps = 0;
        if (Toybox.ActivityMonitor has :getInfo) {
            var ai = ActivityMonitor.getInfo();
            if (ai != null && ai.steps != null) { steps = ai.steps; }
        }
        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + _hLabel, _dataFont(), _fmtSteps(steps),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── UTC badge ────────────────────────────────────────────────────────────
    private function _drawUtc(dc as Dc) as Void {
        var sec = System.getClockTime().timeZoneOffset;
        var sign = (sec >= 0) ? "+" : "-";
        var a = sec.abs();
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy + _hTime - _hTime / 6 + 2, _labelFont(),
                    "UTC " + sign + (a / 3600).format("%d") + ":" + ((a % 3600) / 60).format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ═════════════════════════════════════════════════════════════════════════

    private function _refreshSolarData() as Void {
        _sunriseMin = -1;
        _sunsetMin  = -1;
        if (!(Toybox.Weather has :getSunset)) { return; }
        var loc = _getLoc();
        if (loc == null) {
            _sunriseMin = 378;
            _sunsetMin  = 1127;
            return;
        }
        var now = Time.now();
        if (Toybox.Weather has :getSunrise) {
            var sr = Weather.getSunrise(loc, now);
            if (sr != null) {
                var i = Gregorian.info(sr, Time.FORMAT_SHORT);
                _sunriseMin = (i.hour as Number) * 60 + (i.min as Number);
            }
        }
        var ss = Weather.getSunset(loc, now);
        if (ss != null) {
            var i = Gregorian.info(ss, Time.FORMAT_SHORT);
            _sunsetMin = (i.hour as Number) * 60 + (i.min as Number);
        }
    }

    private function _getLoc() {
        // Try Position cache first (last known GPS fix)
        if (Toybox has :Position && Position has :getInfo) {
            try {
                var pi = Position.getInfo();
                if (pi != null && pi.position != null) {
                    return pi.position;
                }
            } catch (e) {}
        }
        // Fall back to weather observation location
        if (Toybox.Weather has :getCurrentConditions) {
            var c = Weather.getCurrentConditions();
            if (c != null && (c has :observationLocationPosition)) {
                var l = c.observationLocationPosition;
                if (l != null) { return l; }
            }
        }
        // Fall back to current activity location
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentLocation != null) { return ai.currentLocation; }
        return null;
    }

    // Returns latitude in degrees, or 45.0 default (mid-northern) if no location.
    private function _getLatitude() as Float {
        try {
            var loc = _getLoc();
            if (loc == null) { return 0.0f; }
            if (!(loc has :toDegrees)) { return 0.0f; }
            var deg = loc.toDegrees();
            if (deg == null) { return 0.0f; }
            var arr = deg as Array;
            if (arr.size() < 1) { return 0.0f; }
            var lat = arr[0];
            if (lat == null) { return 0.0f; }
            var f = (lat as Lang.Numeric).toFloat();
            // Sanity check: real latitudes are between -90 and 90 exclusive.
            // The simulator's no-GPS sentinel returns values outside that
            // range (180, 90, etc.) — reject and fall back to 0 (equator).
            if (f <= -90.0f || f >= 90.0f) { return 0.0f; }
            return f;
        } catch (e) {
            return 0.0f;
        }
    }

    private function _minToDeg(min as Number) as Number {
        var m12 = min % 720;
        var deg = 90 - m12 / 2;
        while (deg < 0) { deg += 360; }
        return deg % 360;
    }

    private function _degX(deg as Number, r as Number) as Number {
        return _cx + (r.toFloat() * Math.cos(deg.toFloat() * Math.PI / 180.0f).toFloat()).toNumber();
    }

    private function _degY(deg as Number, r as Number) as Number {
        return _cy - (r.toFloat() * Math.sin(deg.toFloat() * Math.PI / 180.0f).toFloat()).toNumber();
    }

    private function _arcColor(ml as Number) as Number {
        if (ml <= 0)  { return 0x00FF55; }   // green flash
        if (ml > 90)  { return 0xFFAA00; }   // gold
        if (ml > 30)  { return _lerp(0xFFAA00, 0xAA55FF, 1.0f - (ml - 30).toFloat() / 60.0f); }
        return _lerp(0xAA55FF, 0x5500FF, 1.0f - ml.toFloat() / 30.0f);
    }

    private function _lerp(c1 as Number, c2 as Number, t as Float) as Number {
        if (t <= 0.0f) { return c1; }
        if (t >= 1.0f) { return c2; }
        var r = ((c1 >> 16) & 0xFF) + ((((c2 >> 16) & 0xFF) - ((c1 >> 16) & 0xFF)).toFloat() * t).toNumber();
        var g = ((c1 >> 8)  & 0xFF) + ((((c2 >> 8)  & 0xFF) - ((c1 >> 8)  & 0xFF)).toFloat() * t).toNumber();
        var b = (c1 & 0xFF) + (((c2 & 0xFF) - (c1 & 0xFF)).toFloat() * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    private function _getHeartRate() as Number {
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null) { return ai.currentHeartRate as Number; }
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getHeartRateHistory)) {
            var it = SensorHistory.getHeartRateHistory({
                :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
            if (it != null) {
                var s = it.next();
                if (s != null && s.data != null) { return s.data.toNumber(); }
            }
        }
        return 0;
    }

    private function _getMoonPhase() as Float {
        var ref = Gregorian.moment({
            :year => 2000, :month => 1, :day => 6, :hour => 18, :minute => 14, :second => 0 });
        var d = (Time.now().value() - ref.value()).toFloat() / 86400.0f;
        var p = d / 29.53059f;
        return p - Math.floor(p).toFloat();
    }

    private function _isLunarEclipse() as Boolean {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var t = (info.year as Number) * 10000 + (info.month as Number) * 100 + (info.day as Number);
        for (var i = 0; i < _eclipseDates.size(); i++) {
            if (_eclipseDates[i] == t) { return true; }
        }
        return false;
    }

    private function _drawMoonIcon(dc as Dc, cx as Number, cy as Number,
                                   r as Number, phase as Float, color as Number,
                                   latitude as Float) as Void {
        if (phase < 0.03f || phase > 0.97f) {
            // New moon — outline only
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
            return;
        }

        // Lit moon body
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        if (phase > 0.47f && phase < 0.53f) { return; }  // Full moon

        // Shadow magnitude — how far to offset the shadow circle from moon center
        // Near new moon (phase~0): mag is small → shadow nearly centered → thin crescent
        // Near full moon (phase~0.5): mag is large → shadow pushed far aside → mostly lit
        var mag;
        if (phase < 0.5f) {
            mag = (phase * 2.0f * r.toFloat() * 1.5f);
        } else {
            mag = ((1.0f - phase) * 2.0f * r.toFloat() * 1.5f);
        }

        // At equator: shadow directly above (negative Y = up in screen coords)
        // Waxing → shadow up, Waning → shadow down
        var bx = 0.0f;
        var by;
        if (phase < 0.5f) { by =  mag; }
        else              { by = -mag; }

        // Latitude rotates clockwise in northern hemisphere
        var rotDeg = latitude;
        var rotRad = rotDeg * Math.PI / 180.0f;
        var cosR = Math.cos(rotRad).toFloat();
        var sinR = Math.sin(rotRad).toFloat();
        var sxF = bx * cosR - by * sinR;
        var syF = bx * sinR + by * cosR;

        var sx = cx + sxF.toNumber();
        var sy = cy + syF.toNumber();

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, r);
    }

    private function _moonName(p as Float) as String {
        if (p < 0.03f || p > 0.97f) { return "NEW"; }
        if (p < 0.22f) { return "WX CR"; }
        if (p < 0.28f) { return "1ST Q"; }
        if (p < 0.47f) { return "WX GB"; }
        if (p < 0.53f) { return "FULL"; }
        if (p < 0.72f) { return "WN GB"; }
        if (p < 0.78f) { return "3RD Q"; }
        return "WN CR";
    }

    private function _fmtSteps(n as Number) as String {
        if (n < 1000) { return n.toString(); }
        return (n / 1000) + "," + (n % 1000).format("%03d");
    }

    private function _fmtRelOff(label as String, rel as Number) as String {
        var s = (rel >= 0) ? "+" : "-";
        var a = rel.abs();
        if (a % 60 == 0) { return label + " " + s + (a / 60); }
        return label + " " + s + (a / 60) + ":" + (a % 60).format("%02d");
    }

    private function _fmtOffsetOnly(rel as Number) as String {
        var s = (rel >= 0) ? "+" : "-";
        var a = rel.abs();
        if (a % 60 == 0) { return s + (a / 60); }
        return s + (a / 60) + ":" + (a % 60).format("%02d");
    }

    private function _propNum(k as String, fb as Number) as Number {
        try { var v = Properties.getValue(k); if (v != null) { return v as Number; } } catch (e) {}
        return fb;
    }

    private function _propStr(k as String, fb as String) as String {
        try { var v = Properties.getValue(k); if (v != null) { return v as String; } } catch (e) {}
        return fb;
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  DST LOGIC
    // ═════════════════════════════════════════════════════════════════════════

    // Checks if DST is currently active for the given rule and base offset.
    // Uses current UTC time from Time.now().
    //
    // Rules:
    //   1 = US/CA:  2nd Sun Mar 2:00 local  →  1st Sun Nov 2:00 local
    //   2 = EU/UK:  last Sun Mar 1:00 UTC   →  last Sun Oct 1:00 UTC
    //   3 = AU:     1st Sun Oct 2:00 local  →  1st Sun Apr 3:00 local
    //   4 = NZ:     last Sun Sep 2:00 local →  1st Sun Apr 3:00 local
    //   5 = Chile:  1st Sat Apr 0:00 local  →  1st Sat Sep 0:00 local
    //
    private function _isDST(rule as Number, baseOffsetMin as Number) as Boolean {
        var utcNow = Time.now();
        var utcInfo = Gregorian.utcInfo(utcNow, Time.FORMAT_SHORT);
        var yr  = utcInfo.year as Number;
        var mon = utcInfo.month as Number;
        var day = utcInfo.day as Number;
        var hr  = utcInfo.hour as Number;

        // Convert current UTC hour to a comparable "minutes since Jan 1 00:00 UTC"
        // for easy comparison. Approximate: ignore leap seconds.
        var utcDayOfYear = _dayOfYear(yr, mon, day);
        var utcTotalMin  = utcDayOfYear * 1440 + hr * 60 + (utcInfo.min as Number);

        if (rule == 1) {
            // US: 2nd Sunday of March at 2:00 local → 1st Sunday of November at 2:00 local
            var startDay = _nthSunday(yr, 3, 2);   // 2nd Sun of March
            var endDay   = _nthSunday(yr, 11, 1);  // 1st Sun of November
            // Convert local transition time to UTC minutes-of-year
            var startMin = _dayOfYear(yr, 3, startDay) * 1440 + 2 * 60 - baseOffsetMin;
            var endMin   = _dayOfYear(yr, 11, endDay) * 1440 + 2 * 60 - (baseOffsetMin + 60);
            return (utcTotalMin >= startMin && utcTotalMin < endMin);
        }

        if (rule == 2) {
            // EU: last Sunday of March at 1:00 UTC → last Sunday of October at 1:00 UTC
            var startDay = _lastSunday(yr, 3);
            var endDay   = _lastSunday(yr, 10);
            var startMin = _dayOfYear(yr, 3, startDay) * 1440 + 60;  // 1:00 UTC
            var endMin   = _dayOfYear(yr, 10, endDay) * 1440 + 60;
            return (utcTotalMin >= startMin && utcTotalMin < endMin);
        }

        if (rule == 3) {
            // AU: 1st Sunday of October at 2:00 local → 1st Sunday of April at 3:00 local
            // Southern hemisphere: DST is Oct→Apr, wraps across year boundary.
            var startDay = _nthSunday(yr, 10, 1);
            var endDay   = _nthSunday(yr, 4, 1);
            var startMin = _dayOfYear(yr, 10, startDay) * 1440 + 2 * 60 - baseOffsetMin;
            var endMin   = _dayOfYear(yr, 4, endDay) * 1440 + 3 * 60 - (baseOffsetMin + 60);
            // Wraps: active if AFTER start OR BEFORE end
            return (utcTotalMin >= startMin || utcTotalMin < endMin);
        }

        if (rule == 4) {
            // NZ: last Sunday of September at 2:00 local → 1st Sunday of April at 3:00 local
            var startDay = _lastSunday(yr, 9);
            var endDay   = _nthSunday(yr, 4, 1);
            var startMin = _dayOfYear(yr, 9, startDay) * 1440 + 2 * 60 - baseOffsetMin;
            var endMin   = _dayOfYear(yr, 4, endDay) * 1440 + 3 * 60 - (baseOffsetMin + 60);
            return (utcTotalMin >= startMin || utcTotalMin < endMin);
        }

        if (rule == 5) {
            // Chile: 1st Saturday of April at 0:00 local → 1st Saturday of September at 0:00 local
            // Chile goes OFF DST in April and ON DST in September (southern hemisphere).
            // So DST is active Sep→Apr (wrap).
            var startDay = _nthDayOfWeek(yr, 9, 7, 1); // 1st Sat of Sep
            var endDay   = _nthDayOfWeek(yr, 4, 7, 1);  // 1st Sat of Apr
            var startMin = _dayOfYear(yr, 9, startDay) * 1440 - baseOffsetMin;
            var endMin   = _dayOfYear(yr, 4, endDay) * 1440 - (baseOffsetMin + 60);
            return (utcTotalMin >= startMin || utcTotalMin < endMin);
        }

        return false;
    }

    // Swap standard label to daylight: EST→EDT, CST→CDT, AEST→AEDT, etc.
    // If label contains 'S' before the 'T', replace 'S' with 'D'.
    // Falls back to appending 'D' if no 'S' found.
    private function _dstLabel(label as String) as String {
        var len = label.length();
        // Find the last 'S' before 'T' and swap it
        for (var i = len - 1; i >= 0; i--) {
            if (label.substring(i, i + 1).equals("S")) {
                return label.substring(0, i) + "D" + label.substring(i + 1, len);
            }
        }
        // London GMT → BST
        if (label.equals("GMT")) { return "BST"; }
        // Fallback: just return label + "D"
        return label + "D";
    }

    // ── Date math helpers ────────────────────────────────────────────────────

    // Day-of-year (1-based): Jan 1 = 0, Feb 1 = 31, etc.
    private function _dayOfYear(yr as Number, mon as Number, day as Number) as Number {
        var daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        // Leap year check
        if (yr % 4 == 0 && (yr % 100 != 0 || yr % 400 == 0)) {
            daysInMonth[2] = 29;
        }
        var total = 0;
        for (var m = 1; m < mon; m++) {
            total += daysInMonth[m];
        }
        return total + day - 1;  // 0-based
    }

    // Find the Nth occurrence of Sunday (dow=1 in Gregorian) in a given month.
    // n=1 is first, n=2 is second, etc.
    private function _nthSunday(yr as Number, mon as Number, n as Number) as Number {
        return _nthDayOfWeek(yr, mon, 1, n);  // Sunday = 1 in CIQ
    }

    // Find the last Sunday of a given month.
    private function _lastSunday(yr as Number, mon as Number) as Number {
        return _lastDayOfWeek(yr, mon, 1);
    }

    // Find the Nth occurrence of a specific day-of-week (1=Sun..7=Sat) in a month.
    private function _nthDayOfWeek(yr as Number, mon as Number,
                                   dow as Number, n as Number) as Number {
        // Get day-of-week of the 1st of the month
        var firstOfMonth = Gregorian.moment({
            :year => yr, :month => mon, :day => 1,
            :hour => 12, :minute => 0, :second => 0
        });
        var info = Gregorian.utcInfo(firstOfMonth, Time.FORMAT_SHORT);
        var firstDow = info.day_of_week as Number;  // 1=Sun..7=Sat

        // Days until the target dow from the 1st
        var delta = ((dow - firstDow) + 7) % 7;
        var day = 1 + delta + (n - 1) * 7;
        return day;
    }

    // Find the last occurrence of a day-of-week in a month.
    private function _lastDayOfWeek(yr as Number, mon as Number,
                                    dow as Number) as Number {
        var daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        if (yr % 4 == 0 && (yr % 100 != 0 || yr % 400 == 0)) {
            daysInMonth[2] = 29;
        }
        var lastDay = daysInMonth[mon];

        // Get dow of the last day of the month
        var lastOfMonth = Gregorian.moment({
            :year => yr, :month => mon, :day => lastDay,
            :hour => 12, :minute => 0, :second => 0
        });
        var info = Gregorian.utcInfo(lastOfMonth, Time.FORMAT_SHORT);
        var lastDow = info.day_of_week as Number;

        // How many days back to the target dow
        var delta = ((lastDow - dow) + 7) % 7;
        return lastDay - delta;
    }
}
