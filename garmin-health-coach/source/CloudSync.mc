using Toybox.Communications;
using Toybox.Lang;

module CloudSync {
    const URL = "https://ecmosmmqloyahsdcxvpz.supabase.co/functions/v1/garmin-sync";

    var _pullCallback = null;
    var _pushCallback = null;

    function configured() {
        return GarminSecrets.TOKEN != null && GarminSecrets.TOKEN.length() >= 20;
    }

    function pull(weekIndex, day, callback) {
        if (!configured()) {
            if (callback != null) { callback.invoke(false, null); }
            return;
        }

        _pullCallback = callback;
        var params = {
            "weekIndex" => weekIndex,
            "day" => day
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "x-garmin-token" => GarminSecrets.TOKEN },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            URL,
            params,
            options,
            new Lang.Method(CloudSync, :onPullResponse)
        );
    }

    function onPullResponse(code, data) {
        var callback = _pullCallback;
        _pullCallback = null;
        var ok = code == 200 && data != null && data["ok"] == true;
        if (callback != null) {
            callback.invoke(ok, data);
        }
    }

    function pushSet(weekIndex, day, stateIndex, setIndex, weight, reps, rir, callback) {
        if (!configured()) {
            if (callback != null) { callback.invoke(false, null); }
            return;
        }

        _pushCallback = callback;
        var params = {
            "weekIndex" => weekIndex,
            "day" => day,
            "stateIndex" => stateIndex,
            "setIndex" => setIndex,
            "weight" => weight,
            "reps" => reps,
            "rir" => rir
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "x-garmin-token" => GarminSecrets.TOKEN,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            URL,
            params,
            options,
            new Lang.Method(CloudSync, :onPushResponse)
        );
    }

    function onPushResponse(code, data) {
        var callback = _pushCallback;
        _pushCallback = null;
        var ok = code == 200 && data != null && data["ok"] == true;
        if (callback != null) {
            callback.invoke(ok, data);
        }
    }
}
