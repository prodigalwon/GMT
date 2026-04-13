import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

// ── Timezone preset table ────────────────────────────────────────────────────
// Each entry is [stdLabel, utcOffsetMinutes, dstRule, cityName]
//
// DST rules:
//   0 = No DST ever
//   1 = US/Canada (2nd Sun Mar 2:00 local → 1st Sun Nov 2:00 local)
//   2 = EU/UK     (last Sun Mar 1:00 UTC  → last Sun Oct 1:00 UTC)
//   3 = Australia  (1st Sun Oct 2:00 local → 1st Sun Apr 3:00 local)
//   4 = NZ         (last Sun Sep 2:00 local → 1st Sun Apr 3:00 local)
//   5 = Chile      (1st Sat Apr 0:00 local → 1st Sat Sep 0:00 local)
//
// When DST is active, add +60 min to the base offset.
// Label swaps S→D automatically (EST→EDT, CST→CDT, etc.)
//
const TZ_PRESETS as Array = [
    // ── Pacific / No DST ─────────────────────────────────────────────────
    ["SST",  -660, 0, "Samoa"],
    ["HST",  -600, 0, "Hawaii"],
    // ── North America ────────────────────────────────────────────────────
    ["AKST", -540, 1, "Alaska"],
    ["PST",  -480, 1, "Pacific US"],
    ["MST",  -420, 0, "Arizona"],           // NO DST
    ["MST",  -420, 1, "Mountain US"],
    ["CST",  -360, 1, "Central US"],
    ["CST",  -360, 0, "Saskatchewan"],      // NO DST
    ["EST",  -300, 1, "Eastern US"],
    ["EST",  -300, 0, "Panama"],            // NO DST
    ["AST",  -240, 1, "Atlantic CA"],
    ["NST",  -210, 1, "Newfoundland"],
    // ── Central & South America ──────────────────────────────────────────
    ["CST",  -360, 0, "Mexico City"],       // Mexico abolished DST 2022
    ["COT",  -300, 0, "Bogota"],
    ["PET",  -300, 0, "Lima"],
    ["VET",  -240, 0, "Caracas"],
    ["CLT",  -240, 5, "Santiago"],          // Chile DST
    ["ART",  -180, 0, "Buenos Aires"],
    ["BRT",  -180, 0, "Sao Paulo"],
    // ── Atlantic / Africa ────────────────────────────────────────────────
    ["CVT",   -60, 0, "Cape Verde"],
    ["GMT",     0, 2, "London"],            // EU DST (becomes BST)
    ["GMT",     0, 0, "Accra"],             // NO DST
    ["GMT",     0, 0, "Reykjavik"],         // NO DST (Iceland)
    ["WAT",    60, 0, "Lagos"],             // NO DST
    ["CET",    60, 2, "Paris"],             // EU DST (becomes CEST)
    ["CET",    60, 2, "Berlin"],
    ["CAT",   120, 0, "Johannesburg"],      // NO DST
    ["EET",   120, 2, "Helsinki"],          // EU DST (becomes EEST)
    ["EET",   120, 0, "Cairo"],             // NO DST (Egypt abolished DST)
    ["EAT",   180, 0, "Nairobi"],           // NO DST
    // ── Middle East / Central Asia ───────────────────────────────────────
    ["MSK",   180, 0, "Moscow"],
    ["IRST",  210, 0, "Tehran"],            // Iran suspended DST
    ["GST",   240, 0, "Dubai"],
    ["AFT",   270, 0, "Kabul"],
    ["PKT",   300, 0, "Karachi"],
    ["IST",   330, 0, "Mumbai"],
    ["NPT",   345, 0, "Kathmandu"],
    // ── South / Southeast Asia ───────────────────────────────────────────
    ["BST",   360, 0, "Dhaka"],
    ["MMT",   390, 0, "Yangon"],
    ["ICT",   420, 0, "Bangkok"],
    ["WIB",   420, 0, "Jakarta"],
    ["HKT",   480, 0, "Hong Kong"],
    ["SGT",   480, 0, "Singapore"],
    ["PHT",   480, 0, "Manila"],
    // ── East Asia / Japan / Korea ────────────────────────────────────────
    ["JST",   540, 0, "Tokyo"],
    ["KST",   540, 0, "Seoul"],
    // ── Australia ────────────────────────────────────────────────────────
    ["ACST",  570, 0, "Darwin"],            // NO DST (Northern Territory)
    ["ACST",  570, 3, "Adelaide"],          // AU DST
    ["AEST",  600, 0, "Brisbane"],          // NO DST (Queensland)
    ["AEST",  600, 3, "Sydney"],            // AU DST
    ["AEST",  600, 3, "Melbourne"],         // AU DST
    // ── Pacific ──────────────────────────────────────────────────────────
    ["NCT",   660, 0, "Noumea"],
    ["NZST",  720, 4, "Auckland"],          // NZ DST
    ["FJT",   720, 0, "Fiji"],              // NO DST
    ["TOT",   780, 0, "Tongatapu"],
] as Array;

// ── Top-level menu delegate (Set GMT 1 / Set GMT 2) ──────────────────────────
class GMTSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var slot = (id == :gmt1) ? 1 : 2;
        var tzMenu = new WatchUi.Menu2({:title => "Set GMT " + slot});
        for (var i = 0; i < TZ_PRESETS.size(); i++) {
            var entry = TZ_PRESETS[i] as Array;
            var cityName = entry[3] as String;
            var label = entry[0] as String;
            var dstRule = entry[2] as Number;
            var dstTag = (dstRule > 0) ? " *" : "";
            tzMenu.addItem(new WatchUi.MenuItem(
                cityName + " (" + label + ")" + dstTag, null, i, null));
        }
        WatchUi.pushView(tzMenu, new GMTTimezonePickerDelegate(slot),
                         WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ── Timezone picker delegate ─────────────────────────────────────────────────
class GMTTimezonePickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _slot as Number;

    function initialize(slot as Number) {
        Menu2InputDelegate.initialize();
        _slot = slot;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var idx = item.getId() as Number;
        var entry = TZ_PRESETS[idx] as Array;
        var label = entry[0] as String;
        var offset = entry[1] as Number;
        var dstRule = entry[2] as Number;

        if (_slot == 1) {
            Properties.setValue("gmt1Label",   label);
            Properties.setValue("gmt1Offset",  offset);
            Properties.setValue("gmt1DstRule", dstRule);
        } else {
            Properties.setValue("gmt2Label",   label);
            Properties.setValue("gmt2Offset",  offset);
            Properties.setValue("gmt2DstRule", dstRule);
        }

        WatchUi.requestUpdate();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
