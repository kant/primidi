module primidi.workstation.panel;

import std.conv: to;
import std.path;
import std.string;

import primidi.common.all;
import primidi.core.all;
import primidi.render.all;
import primidi.ui.all;
import primidi.midi.all;

import primidi.workstation.common.all;
import primidi.workstation.control.all;
import primidi.workstation.piano.all;

class MainPanel: WidgetGroup {
	private {
		Playlist _playlist;
		HContainer _panelBtnContainer;
		ControlPanel _controlPanel;
		PianoPanel _pianoPanel;
		TextButton[] _panelBtns;
	}

	this(string[] args) {
		windowClearColor = Color(0.111f, 0.1125f, 0.123f);
		_position = centerScreen;
		_size = screenSize;

		initializeSfx();

		//Panel buttons
		_panelBtnContainer = new HContainer;
		_panelBtnContainer.position = Vec2f(screenWidth / 2f, 50f);
		uint i = 0u;
		foreach(displayName; ["Controler", "P.Roll", "Piano"]) {
			auto btn = new TextButton(displayName);
			btn.size = Vec2f(100f, 25f);
			btn.setCallback("workstation.btn.panel" ~ to!string(i), this);
			_panelBtns ~= btn;
			_panelBtnContainer.addChild(btn);
			i ++;
		}
		addChild(_panelBtnContainer);

		//Panels
		_controlPanel = new ControlPanel(args);
		_pianoPanel = new PianoPanel;

		_panelBtns[0].isLocked = true;
		addChild(_controlPanel);
	}

	override void onEvent(Event event) {
		super.onEvent(event);

		switch(event.type) with(EventType) {
		case Callback:
			switch(event.id) {
			case "workstation.btn.panel0":
				foreach(btn; _panelBtns)
					btn.isLocked = false;
				_panelBtns[0].isLocked = true;
				removeChildren();
				addChild(_panelBtnContainer);
				addChild(_controlPanel);
				break;
			case "workstation.btn.panel1":
				foreach(btn; _panelBtns)
					btn.isLocked = false;
				_panelBtns[1].isLocked = true;
				removeChildren();
				addChild(_panelBtnContainer);
				break;
			case "workstation.btn.panel2":
				foreach(btn; _panelBtns)
					btn.isLocked = false;
				_panelBtns[2].isLocked = true;
				removeChildren();
				addChild(_panelBtnContainer);
				addChild(_pianoPanel);
				break;
			default:
				break;
			}
			break;
		case DropFile:
			if(extension(event.str).toLower == ".mid") {
				auto midiFile = new MidiFile(event.str);
				stopMidiOutSequencer();
				setupInternalSequencer(midiFile);
				setupMidiOutSequencer(midiFile);
				startMidiOutSequencer();
				startInternalSequencer();
			}
			break;
		case Quit:
			stopMidiOutSequencer();
			break;
		default:
			break;
		}
	}

	override void update(float deltaTime) {
		super.update(deltaTime);
		updateInternalSequencer();
	}

	override void draw() {
		super.draw();
		renderSfx();
	}
}