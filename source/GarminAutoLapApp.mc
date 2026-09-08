import Toybox.Application;
import Toybox.WatchUi;

class GarminAutoLapApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new GarminAutoLapView()];
    }
}

function getApp() {
    return Application.getApp() as GarminAutoLapApp;
}
