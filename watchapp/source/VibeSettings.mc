import Toybox.Application.Storage;
import Toybox.Attention;
import Toybox.Lang;

// Finish-vibration intensity. Each level repeats the base pattern ("chunk")
// more times: Modest x1 (the original pattern), Normal x2, Intense x4,
// Extremely Intense x8, with rising duty cycle. Attention.vibrate() accepts
// at most 8 VibeProfiles per call, so levels above Modest are chained as
// repeated calls; TimerView owns the chain timer.

const VIBE_LEVEL_MODEST = 0;
const VIBE_LEVEL_NORMAL = 1;
const VIBE_LEVEL_INTENSE = 2;
const VIBE_LEVEL_EXTREME = 3;

function getVibeLevel() as Lang.Number {
    var level = Storage.getValue("vibe_level");
    if (!(level instanceof Lang.Number)) { return VIBE_LEVEL_MODEST; }
    if (level < VIBE_LEVEL_MODEST || level > VIBE_LEVEL_EXTREME) { return VIBE_LEVEL_MODEST; }
    return level;
}

function setVibeLevel(level) as Void {
    if (!(level instanceof Lang.Number)) { return; }
    if (level < VIBE_LEVEL_MODEST || level > VIBE_LEVEL_EXTREME) { return; }
    Storage.setValue("vibe_level", level);
}

function vibeLevelName(level) as Lang.String {
    if (level == VIBE_LEVEL_NORMAL) { return "Normal"; }
    if (level == VIBE_LEVEL_INTENSE) { return "Intense"; }
    if (level == VIBE_LEVEL_EXTREME) { return "Extremely Intense"; }
    return "Modest";
}

function vibeChunkCount(level) as Lang.Number {
    if (level == VIBE_LEVEL_NORMAL) { return 2; }
    if (level == VIBE_LEVEL_INTENSE) { return 4; }
    if (level == VIBE_LEVEL_EXTREME) { return 8; }
    return 1;
}

function vibeChunkDurationMs() as Lang.Number {
    return 4 * 300 + 3 * 150;
}

function vibeChunkGapMs() as Lang.Number {
    return 250;
}

function playVibeChunk(level) as Void {
    if (!(Attention has :vibrate)) { return; }

    var duty = 50;
    if (level == VIBE_LEVEL_NORMAL) {
        duty = 70;
    } else if (level == VIBE_LEVEL_INTENSE) {
        duty = 90;
    } else if (level == VIBE_LEVEL_EXTREME) {
        duty = 100;
    }

    Attention.vibrate([
        new Attention.VibeProfile(duty, 300),
        new Attention.VibeProfile(0, 150),
        new Attention.VibeProfile(duty, 300),
        new Attention.VibeProfile(0, 150),
        new Attention.VibeProfile(duty, 300),
        new Attention.VibeProfile(0, 150),
        new Attention.VibeProfile(duty, 300)
    ]);
}
