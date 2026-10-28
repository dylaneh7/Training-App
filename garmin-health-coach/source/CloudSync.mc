using Toybox.Communications;
using Toybox.Lang;
using Toybox.PersistedContent;

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
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :context => "pull"
        };

        Communications.makeWebRequest(
            URL,
            params,
            options,
            method(:onPullResponse)
        );
    }

    function onPullResponse(
        code as Number,
        data as Null or ByteArray or Dictionary or String or PersistedContent.Iterator,
        context as Object
    ) as Void {
        var callback = _pullCallback;
        _pullCallback = null;
        var ok = false;
        if (code == 200 && data != null && data instanceof Dictionary) {
            ok = data["ok"] == true;
        }
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
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :context => "push"
        };

        Communications.makeWebRequest(
            URL,
            params,
            options,
            method(:onPushResponse)
        );
    }

    function onPushResponse(
        code as Number,
        data as Null or ByteArray or Dictionary or String or PersistedContent.Iterator,
        context as Object
    ) as Void {
        var callback = _pushCallback;
        _pushCallback = null;
        var ok = false;
        if (code == 200 && data != null && data instanceof Dictionary) {
            ok = data["ok"] == true;
        }
        if (callback != null) {
            callback.invoke(ok, data);
        }
    }
}
