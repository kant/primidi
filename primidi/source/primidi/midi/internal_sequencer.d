/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module primidi.midi.internal_sequencer;

import std.algorithm;
import std.stdio;
import bindbc.sdl;

import atelier;
import primidi.midi;

class Note {
	uint tick;
	uint step;

	uint note;
	uint channel;
	uint velocity;
	float playTime, time, duration;
	bool isAlive, hasHit;
}

alias NotesArray = IndexedArray!(Note, 4096u);

private {
	Sequencer _sequencer;
	int _intervalWindowSize = 5_000, _startInterval = 2_500, _endInterval = 2_500;
	float _intervalRatio = 0.5f;
}

Note[][16] sequencerNotes;

void setupInternalSequencer() {
	_sequencer = new Sequencer;
	sequencerNotes = new Note[][16];
	startInternalSequencer();
}

void stopInternalSequencer() {
	if (!_sequencer)
		return;
	_sequencer.cleanUp();
	_sequencer = null;
}

void notifyEndInternalSequencer() {
	if (_onEndCallback)
		_onEndCallback();
}

void notifyFileDrop(string filePath) {
	if (_onFileDropCallback)
		_onFileDropCallback(filePath);
}

void playInternalSequencer(MidiFile midiFile) {
	if (!_sequencer)
		return;
	_sequencer.play(midiFile);
}

void setInternalSequencerInterval(int windowSize) {
	_intervalWindowSize = windowSize;
	_startInterval = cast(int)(_intervalWindowSize * _intervalRatio);
	_endInterval = cast(int)(_intervalWindowSize * (1f - _intervalRatio));
}

int getInternalSequencerInterval() {
	return _intervalWindowSize;
}

void setInternalSequencerHitRatio(float hitRatio = 0.5f) {
	_intervalRatio = clamp(hitRatio, 0f, 1f);
	_startInterval = cast(int)(_intervalWindowSize * _intervalRatio);
	_endInterval = cast(int)(_intervalWindowSize * (1f - _intervalRatio));
}

float getInternalSequencerHitRatio() {
	return _intervalRatio;
}

void startInternalSequencer() {
	if (_sequencer)
		_sequencer.start();
}

void updateInternalSequencer() {
	auto midiOut = getMidiOut();
	auto midiIn = getMidiIn();
	while (midiIn.canReceive()) {
		const ubyte[] bytes = midiIn.receive();
		switch (bytes[0] & 0xF0) with (MidiEventType) {
		case NoteOn:
			midiOut.send(bytes);
			ubyte channelId = bytes[0] & 0x0F;
			if (_sequencer) {
				Note note = new Note;
				note.channel = channelId;
				note.note = bytes[1];
				note.tick = cast(int) getInternalSequencerTick();
				note.step = 0;
				note.duration = 0f;
				note.playTime = 0f;
				note.time = 0f;
				note.isAlive = true;
				note.velocity = bytes[2];
				_sequencer.channels[channelId].midiNoteOnEvents.push(note);
				_sequencer.channels[channelId].notesInRange.push(note);
				if (_onNoteInputCallback !is null)
					_onNoteInputCallback(note);
			}
			break;
		case NoteOff:
			midiOut.send(bytes);
			ubyte channelId = bytes[0] & 0x0F;
			if (_sequencer) {
				_sequencer.channels[channelId].midiNoteOffEvents.push(bytes[1]);
			}
			break;
		default:
			break;
		}
	}

	if (_sequencer)
		_sequencer.update();
	foreach (ubyte i; 0 .. 16) {
		sequencerNotes[i].length = 0;
		auto notesInRange = fetchInternalSequencerNotesInRange(i);
		if (!notesInRange)
			continue;
		foreach (note; notesInRange) {
			sequencerNotes[i] ~= note;
		}
	}
}

NotesArray fetchInternalSequencerNotesInRange(ubyte channelId) {
	if (_sequencer && channelId < 16u)
		return _sequencer.channels[channelId].notesInRange;
	return null;
}

double getInternalSequencerTick() {
	if (_sequencer)
		return _sequencer.totalTicksElapsed;
	return 0uL;
}

// -- CALLBACKS --
alias NoteCallback = void function(Note);
alias FileCallback = void function(string);
private NoteCallback _onNoteEnterCallback, _onNoteHitCallback,
	_onNoteExitCallback, _onNoteInputCallback;
private FileCallback _onFileDropCallback;

void setNoteEnterCallback(NoteCallback callback) {
	_onNoteEnterCallback = callback;
}

void setNoteHitCallback(NoteCallback callback) {
	_onNoteHitCallback = callback;
}

void setNoteExitCallback(NoteCallback callback) {
	_onNoteExitCallback = callback;
}

void setNoteInputCallback(NoteCallback callback) {
	_onNoteInputCallback = callback;
}

alias GlobalMidiCallback = void function();
private GlobalMidiCallback _onStartCallback, _onEndCallback;
void setStartCallback(GlobalMidiCallback callback) {
	_onStartCallback = callback;
}

void setEndCallback(GlobalMidiCallback callback) {
	_onEndCallback = callback;
}

void setFileDropCallback(FileCallback callback) {
	_onFileDropCallback = callback;
}

///Visual sequencer
private final class Sequencer {
	struct Channel {
		Note[] notes;
		uint top;

		NotesArray notesInRange;
		IndexedArray!(Note, 128) midiNoteOnEvents;
		IndexedArray!(ubyte, 128) midiNoteOffEvents;
		long lastTickProcessed = -1;

		Note getTop() {
			return notes[top];
		}

		void process(long tick) {
			while (notes.length > top) {
				auto note = notes[top];
				// Ignore already past events
				if (tick > (note.tick + note.step + _endInterval)) {
					top++;
					continue;
				}
				// Not yet ready to enter the window
				if ((tick + _startInterval) <= note.tick)
					break;

				// Start entering the window
				note.isAlive = true;
				note.duration = rlerp(0, _intervalWindowSize, note.step);
				notesInRange.push(note);
				if (_onNoteEnterCallback !is null)
					_onNoteEnterCallback(note);
				top++;
			}

			foreach (ubyte pitch; midiNoteOffEvents) {
				uint index;
				foreach (ref note; midiNoteOnEvents) {
					if (note.note == pitch) {
						midiNoteOnEvents.markInternalForRemoval(index);
					}
					index++;
				}
				midiNoteOnEvents.sweepMarkedData();
			}
			midiNoteOffEvents.reset();

			foreach (ref note; midiNoteOnEvents) {
				note.step = cast(int) getInternalSequencerTick() - note.tick;
				note.duration = rlerp(0, _intervalWindowSize, note.step);
				note.playTime = 0f;
				note.time = rlerp(tick + _startInterval, tick - _endInterval, note.tick);
			}

			int i = 0;
			foreach (ref note; notesInRange) {
				note.playTime = cast(float)(cast(int) tick - cast(int) note.tick) / cast(float) note
					.step;
				note.duration = rlerp(0, _intervalWindowSize, note.step);
				note.time = rlerp(tick + _startInterval, tick - _endInterval, note.tick);

				if (tick >= note.tick && !note.hasHit) {
					note.hasHit = true;
					if (_onNoteHitCallback !is null)
						_onNoteHitCallback(note);
				}

				if (tick > (note.tick + note.step + _endInterval)) {
					// Leaving the window
					note.isAlive = false;
					notesInRange.markInternalForRemoval(i);
					if (_onNoteExitCallback !is null)
						_onNoteExitCallback(note);
				}
				i++;
			}
			notesInRange.sweepMarkedData();
			lastTickProcessed = tick;
		}
	}

	Channel[16] channels;

	MidiEvent[] events;
	uint eventsTop;

	TempoEvent[] tempoEvents;
	uint tempoEventsTop;

	long ticksPerQuarter = 960;
	long tickAtLastChange;
	double ticksElapsedSinceLastChange, tickPerMs, msPerTick, timeAtLastChange;
	float currentBpm = 0f;
	double totalTicksElapsed = .0;

	private {
		MidiFile _midiFile;
	}

	this() {
		foreach (channelId; 0 .. 16) {
			channels[channelId].notesInRange = new NotesArray;
			channels[channelId].midiNoteOnEvents = new IndexedArray!(Note, 128);
			channels[channelId].midiNoteOffEvents = new IndexedArray!(ubyte, 128);
		}
	}

	void play(MidiFile midiFile) {
		_midiFile = midiFile;
		speedFactor = 1f;
		initialBpm = 120;

		ticksPerQuarter = midiFile.ticksPerBeat;

		//ubyte trackId = 0u;
		Note[][16] noteOnEvents, noteOffEvents;

		//Set channel notes
		foreach (uint t; 0 .. cast(uint) midiFile.tracks.length) {
			//Temporarily here, move them to Channel
			int maxNote = 0, minNote = 0;

			//List all NOTE ON and NOTE OFF events.
			foreach (MidiEvent event; midiFile.tracks[t]) {
				switch (event.type) with (MidiEventType) {
				case NoteOn:
					Note note = new Note;
					note.channel = event.note.channel;
					note.tick = event.tick;
					note.note = event.note.note;
					note.velocity = event.note.velocity;
					if (note.velocity == 0)
						noteOffEvents[event.note.channel] ~= note;
					else
						noteOnEvents[event.note.channel] ~= note;

					if (event.note.note > maxNote)
						maxNote = event.note.note; //Temp

					if (event.note.note < minNote)
						minNote = event.note.note; //Temp
					break;
				case NoteOff:
					Note note = new Note;
					note.channel = event.note.channel;
					note.tick = event.tick;
					note.note = event.note.note;
					note.velocity = event.note.velocity;
					noteOffEvents[event.note.channel] ~= note;
					break;
				default:
					break;
				}

				//Fill in the tempo track.
				if (event.subType == MidiEvents.Tempo) {
					TempoEvent tempoEvent;
					tempoEvent.tick = event.tick;
					tempoEvent.usPerQuarter = event.tempo.microsecondsPerBeat;
					tempoEvents ~= tempoEvent;
				}
			}
		}

		foreach (channelId; 0u .. 16u) {
			//Use the NOTE OFF events to set each note length.
			foreach (uint i; 0 .. cast(uint)(noteOnEvents[channelId].length)) {
				int note = noteOnEvents[channelId][i].note;
				foreach (uint y; 0 .. cast(uint)(noteOffEvents[channelId].length)) {
					if (note == noteOffEvents[channelId][y].note) {
						noteOnEvents[channelId][i].step = noteOffEvents[channelId][y].tick
							- noteOnEvents[channelId][i].tick;
						//Minimal rendering step.
						if (noteOnEvents[channelId][i].step < 25)
							noteOnEvents[channelId][i].step = 25;
						noteOffEvents[channelId] = noteOffEvents[channelId][0 .. y]
							~ noteOffEvents[channelId][y + 1 .. $];
						break;
					}
				}
			}

			if (noteOnEvents[channelId].length) {
				channels[channelId].notes = noteOnEvents[channelId];
				//trackId ++;
			}
		}
		if (_onStartCallback)
			_onStartCallback();
	}

	void start() {
		//Initialize
		tickAtLastChange = 0;
		tickPerMs = (initialBpm * ticksPerQuarter * speedFactor) / 60_000f;
		msPerTick = 60_000f / (initialBpm * ticksPerQuarter * speedFactor);
		timeAtLastChange = 0;
	}

	void update() {
		const double currentTime = getMidiTime();

	checkTempo:
		const double msDeltaTime = currentTime - timeAtLastChange; //The time since last tempo change.
		ticksElapsedSinceLastChange = msDeltaTime * tickPerMs;

		totalTicksElapsed = tickAtLastChange + ticksElapsedSinceLastChange;

		if (tempoEvents.length > tempoEventsTop) {
			const long tickThreshold = tempoEvents[tempoEventsTop].tick;
			if (totalTicksElapsed > tickThreshold) {
				const long tickDelta = tickThreshold - tickAtLastChange;
				const double finalDeltaTime = tickDelta * msPerTick;

				const long usPerQuarter = tempoEvents[tempoEventsTop].usPerQuarter;
				tempoEventsTop++;

				ticksElapsedSinceLastChange = 0;
				tickAtLastChange = tickThreshold;
				timeAtLastChange += finalDeltaTime;
				tickPerMs = (1000f * ticksPerQuarter * speedFactor) / usPerQuarter;
				msPerTick = usPerQuarter / (ticksPerQuarter * 1000f * speedFactor);
				currentBpm = tickPerMs * 60_000f / ticksPerQuarter;
				goto checkTempo;
			}
		}

		//Events handling.
		foreach (channelId; 0 .. 16) {
			channels[channelId].process(cast(long) totalTicksElapsed);
		}
	}

	void cleanUp() {
		foreach (channelId; 0 .. 16) {
			channels[channelId].notes.length = 0uL;
			foreach (ref note; channels[channelId].notesInRange) {
				note.isAlive = false;
			}
		}
	}
}
