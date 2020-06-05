/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module primidi.gui.script_error;

import std.conv: to;
import atelier, grimoire;
import primidi.locale;
import primidi.gui.buttons;

/// Error popup for compilation problems.
final class ScriptErrorModal: GuiElement {
    /// Ctor
    this(GrError error) {
        setAlign(GuiAlignX.center, GuiAlignY.center);
        size(Vec2f(800f, 250f));

        { //Error display
            auto box = new VContainer;
            box.setChildAlign(GuiAlignX.left);
            box.setAlign(GuiAlignX.center, GuiAlignY.center);
            //box.position = Vec2f(20f, 50f);
            addChildGui(box);

            string lineNumber = to!string(error.line) ~ "| ";
            string snippet, underline, extra, space;

            //Script snippet
            foreach(x; 1 .. lineNumber.length)
                space ~= " ";
            underline = space;
            extra = space;
            snippet ~= " " ~ lineNumber ~ error.lineText;

            //Underline
            underline ~= "|";
            foreach(x; 0 .. error.column)
                underline ~= " ";
            foreach(x; 0 .. error.textLength)
                underline ~= "^";
            if(error.info.length)
                underline ~= "  " ~ error.info;

            extra ~= "|";

            //Labels
            foreach (line; [
                "error: " ~ error.message,
                " ",
                "-----",
                space ~ "-> "
                ~ error.filePath
                ~ "(" ~ to!string(error.line)
                ~ "," ~ to!string(error.column)
                ~ ")",
                extra,
                snippet,
                underline,
                extra,
                "-----",
                " ",
                "Compilation aborted..."
                ]) {
                Label label = new Label(line);
                box.addChildGui(label);
            }
            
        }

        { //Title
            auto title = new Label(getLocalizedText("error") ~ ":");
            title.setAlign(GuiAlignX.left, GuiAlignY.top);
            title.position = Vec2f(20f, 10f);
            addChildGui(title);
        }

		{ //Close
            auto closeBtn = new ConfirmationButton(getLocalizedText("close"));
            closeBtn.setAlign(GuiAlignX.right, GuiAlignY.bottom);
            closeBtn.position = Vec2f(10f, 10f);
            closeBtn.size = Vec2f(70f, 20f);
            closeBtn.setCallback(this, "close");
            addChildGui(closeBtn);
        }

        { //Exit
            auto exitBtn = new ExitButton;
            exitBtn.setAlign(GuiAlignX.right, GuiAlignY.top);
            exitBtn.position = Vec2f(10f, 10f);
            exitBtn.setCallback(this, "cancel");
            addChildGui(exitBtn);
        }

        GuiState hiddenState = {
            offset: Vec2f(0f, -50f),
            color: Color.clear
        };
        addState("hidden", hiddenState);

        GuiState defaultState = {
            time: .5f,
            easingFunction: getEasingFunction(EasingAlgorithm.sineOut)
        };
        addState("default", defaultState);

        setState("hidden");
        doTransitionState("default");
    }

    override void onCallback(string id) {
		switch(id) {
		case "close":
            stopModalGui();
            break;
        default:
            break;
        }
	}

    override void update(float deltaTime) {
        if(getButtonDown(KeyButton.escape) || getButtonDown(KeyButton.enter) || getButtonDown(KeyButton.enter2))
            onCallback("close");
    }

    override void draw() {
        drawFilledRect(origin, size, Color(.11f, .08f, .15f));
    }

    override void drawOverlay() {
        drawRect(origin, size, Color.gray);
    }
}