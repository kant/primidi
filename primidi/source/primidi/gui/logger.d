/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module primidi.gui.logger;

import atelier;

final class Logger: GuiElement {
    private {
        VContainer _box;
    }

    this() {
        setAlign(GuiAlignX.left, GuiAlignY.bottom);
        size(Vec2f(200f, 200f));
        isInteractable(false);

        _box = new VContainer;
        addChildGui(_box);

        GuiState hiddenState = {
            color: Color.clear,
            offset: Vec2f(0f, 50f),
            time: 2f,
            easingFunction: getEasingFunction(EasingAlgorithm.sineIn),
            callbackId: "hidden"
        };
        addState("hidden", hiddenState);

        GuiState log3State = {
            time: 5f,
            callbackId: "log3"
        };
        addState("log3", log3State);

        GuiState log2State = {
            time: 1f,
            easingFunction: getEasingFunction(EasingAlgorithm.sineOut),
            callbackId: "log2"
        };
        addState("log2", log2State);

        GuiState log1State = {
            offset: Vec2f(0f, -10f),
            color: Color.clear
        };
        addState("log1", log1State);
    }
    
    override void onCallback(string id) {
        if(id == "hidden") {
            _box.removeChildrenGuis();
        }
        else if(id == "log2") {
            doTransitionState("log3");
        }
        else if(id == "log3") {
            doTransitionState("hidden");
        }
    }

    override void update(float deltaTime) {
        foreach(gui; _box.children)
            gui.color = color;
    }

    void add(string message) {
        import std.string: splitLines;
        foreach(line; splitLines(message))
            _box.addChildGui(new Label(line));
        setState("log1");
        doTransitionState("log2");
    }
    
    override void draw() {
        
    }
}