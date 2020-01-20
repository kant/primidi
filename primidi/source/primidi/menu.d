/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module primidi.menu;

import std.stdio, std.conv, std.file, std.path, std.string;
import atelier, grimoire, minuit;
import primidi.loader, primidi.midi, primidi.gui, primidi.script;

private {
	enum _version = "0.2.0";
	string _lockFileName = ".lock";
	string _msgFileName = ".primidi";
	string _startingFilePath;
	File _lockFile;
	bool _isMainApplication;
	MainGui _mainGui;
}

bool processArguments(string[] args) {
	if(args.length == 1)
		return true;
	string arg = args[1];
	if(!arg.length)
		return false;
	switch(arg) {
	case "-v":
	case "--version":
		writeln("Primidi version " ~ _version);
		break;
	case "-h":
	case "--help":
		writeln("Primidi (c) 2016~2019 by Enalye.
Primidi is a free software and comes with ABSOLUTELY NO WARRANTY.

Usage:
 primidi
 primidi <file>
 primidi <option>

Where:
 <file> A midi file path to read

<option>:
 -h or --help		Display this help
 -v or --version 	Display the version number");
		break;
	default:
		_startingFilePath = arg;
		break;
	}
	return true;
}

void setupApplication(string[] args) {
	_lockFileName = buildNormalizedPath(dirName(thisExePath()), _lockFileName);
	_msgFileName = buildNormalizedPath(dirName(thisExePath()), _msgFileName);
	//if(!exists(_lockFileName)) {
		// If the file exists, Primidi is already launched... or it crashed, we can never know.
		_isMainApplication = true;
	//}
	if(_isMainApplication) {
		_lockFile = File(_lockFileName, "w");
		_lockFile.lock();
		
		enableAudio(false);
		initializeMidiDevices();
		createApplication(Vec2u(1280u, 720u + 70u), "Primidi");

		setWindowMinSize(Vec2u(500, 200));
		setWindowClearColor(Color.black);

		const string iconPath = buildNormalizedPath(dirName(thisExePath()), "media", "gui", "icon.png");
		if(exists(iconPath))
			setWindowIcon(iconPath);

		if(!processArguments(args)) {
			closeLock();
			return;
		}
		onStartupLoad(&onLoadComplete);

		scope(exit) {
			//We need to clean up the remaining threads.
			closeLock();
			stopMidiClock();
			stopMidiOutSequencer();
			closeMidiDevices();
		}
		runApplication();
		destroyApplication();
	}
	else if(processArguments(args)) {
		if(_startingFilePath.length)
			std.file.write(_msgFileName, _startingFilePath);
	}
}

private void closeLock() {
	if(!_isMainApplication)
		return;
	if(!exists(_lockFileName))
		return;
	_lockFile.close();
	std.file.remove(_lockFileName);
}

string receiveFilePath() {
	if(!exists(_msgFileName) || isDir(_msgFileName))
		return "";
	string filePath;
	try {
		filePath = readText(_msgFileName);
		std.file.remove(_msgFileName);
	}
	catch(Exception e) {}
	if(!exists(filePath) || isDir(filePath))
		return "";
	const string ext = extension(filePath).toLower;
	if(ext != ".mid" && ext != ".midi")
		return "";
	return filePath;
}

private void onLoadComplete() {
    setDefaultFont(fetch!TrueTypeFont("Cascadia"));
	_mainGui = new MainGui(_startingFilePath);
	onMainMenu();
}

private void onMainMenu() {
	removeRootGuis();
	addRootGui(_mainGui);
}