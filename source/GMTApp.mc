import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GMTApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new GMTView()];
    }

    // On-device settings entry point. Invoked when the user enters the system
    // Watch Face menu and selects this watch face's settings.
    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => "GMT Settings"});
        menu.addItem(new WatchUi.MenuItem("Set GMT 1", null, :gmt1, null));
        menu.addItem(new WatchUi.MenuItem("Set GMT 2", null, :gmt2, null));
        return [menu, new GMTSettingsMenuDelegate()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
