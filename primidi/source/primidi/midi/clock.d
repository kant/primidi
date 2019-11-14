module primidi.midi.clock;

import std.datetime;
import std.datetime.stopwatch: StopWatch, AutoStart;

__gshared StopWatch midiClock;

void initMidiClock() {
    midiClock = StopWatch(AutoStart.no);
}

void startMidiClock() {
    midiClock.start();
}

void pauseMidiClock() {
    if(midiClock.running())
        midiClock.stop();
}

void stopMidiClock() {
    if(midiClock.running())
        midiClock.stop();
    midiClock.reset();
}

bool isMidiClockRunning() {
    return midiClock.running();
}

long getMidiTime() {
    import std.stdio;
    //writeln("Time: ", midiClock.peek.total!"msecs");
    return midiClock.peek.total!"msecs";
}

void setMidiTime(long time) {
    import std.datetime;
    midiClock.setTimeElapsed(dur!"msecs"(time));
}