import Toybox.Communications;
import Toybox.System;

// Helper to format dateKey to string
function formatDateKey(dateKey) {
    var year = (dateKey / 10000).toNumber();
    var month = ((dateKey % 10000) / 100).toNumber();
    var day = (dateKey % 100).toNumber();
    var monthStr = (month < 10) ? ("0" + month) : ("" + month);
    var dayStr = (day < 10) ? ("0" + day) : ("" + day);
    return "" + year + "-" + monthStr + "-" + dayStr;
}
