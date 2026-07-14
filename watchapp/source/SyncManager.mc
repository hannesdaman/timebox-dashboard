import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Helper to format dateKey to string
function formatDateKey(dateKey) {
    var year = (dateKey / 10000).toNumber();
    var month = ((dateKey % 10000) / 100).toNumber();
    var day = (dateKey % 100).toNumber();
    var monthStr = (month < 10) ? ("0" + month) : ("" + month);
    var dayStr = (day < 10) ? ("0" + day) : ("" + day);
    return "" + year + "-" + monthStr + "-" + dayStr;
}

// Epoch seconds -> "YYYY-MM-DDTHH:MM:SSZ" for Supabase timestamptz columns.
function isoUtcTimestamp(epochSeconds) as Lang.String {
    var info = Gregorian.utcInfo(new Time.Moment(epochSeconds), Time.FORMAT_SHORT);
    return "" + info.year + "-" +
        info.month.format("%02d") + "-" +
        info.day.format("%02d") + "T" +
        info.hour.format("%02d") + ":" +
        info.min.format("%02d") + ":" +
        info.sec.format("%02d") + "Z";
}
