import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FuelApp extends Application.AppBase {
    private var mView as FuelView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new FuelView();
        mView = v;
        return [v];
    }

    // Called when settings are changed from the Connect IQ phone app (store/beta installs only)
    function onSettingsChanged() as Void {
        if (mView != null) {
            mView.loadSchedule();
        }
        WatchUi.requestUpdate();
    }
}
