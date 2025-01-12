/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module primidi.gui.controlbar;

import atelier;
import primidi.gui.port;
import primidi.player, primidi.midi;

final class ControlBar: GuiElement {
    private {
        bool _isVisible = true;
    }

    this() {
        size(Vec2f(getWindowWidth(), 50f));
        setAlign(GuiAlignX.center, GuiAlignY.bottom);

        {
            auto hbox = new HContainer;
            appendChild(hbox);
            hbox.appendChild(new CurrentTimeGui);
            hbox.appendChild(new ProgressBar);
            hbox.appendChild(new TotalTimeGui);
        }

        {
            auto playBtn = new PlayButton;
            appendChild(playBtn);
        }

        {
            auto hbox = new HContainer;
            hbox.setAlign(GuiAlignX.left, GuiAlignY.bottom);
            hbox.position = Vec2f(48f, 5f);
            hbox.spacing = Vec2f(2f, 0f);
            appendChild(hbox);

            auto rewindBtn = new RewindButton;
            hbox.appendChild(rewindBtn);

            auto stopBtn = new StopButton;
            hbox.appendChild(stopBtn);
        }

        GuiState hiddenState = {
            offset: Vec2f(0f, -50f),
            time: .25f,
            easing: getEasingFunction(Ease.quadInOut)
        };
        addState("hidden", hiddenState);

        GuiState shownState = {
            time: .25f,
            easing: getEasingFunction(Ease.quadInOut)
        };
        addState("shown", shownState);
        setState("shown");
    }

    override void onEvent(Event event) {
        switch(event.type) with(Event.Type) {
        case resize:
            size(Vec2f(event.window.size.x, 50f));
            break;
        case custom:
            if(event.custom.id == "hide") {
                doTransitionState(_isVisible ? "hidden" : "shown");
                _isVisible = !_isVisible;
            }
            break;
        default:
            break;
        }
    }

    override void onCallback(string id) {
        super.onCallback(id);
        switch(id) {
        default:
            break;
        }
    }

    override void draw() {
        drawFilledRect(origin, size, Color(240, 240, 240));
    }
}

final class PlayButton: Button {
    private {
        Sprite _pauseSprite, _playSprite;
    }

    this() {
        _pauseSprite = fetch!Sprite("pause");
        _playSprite = fetch!Sprite("play");

        setAlign(GuiAlignX.left, GuiAlignY.bottom);
        position = Vec2f(4f, 2f);
        size = Vec2f(30f, 30f);
    }

	override void onSubmit() {
        if(isMidiPlaying())
            pauseMidi();
        else
            replayMidi();
    }

    override void update(float deltaTime) {
        super.update(deltaTime);
        if(getButtonDown(KeyButton.space) || getButtonDown(KeyButton.k) || getButtonDown(KeyButton.p))
            onSubmit();
    }

    override void draw() {
        if(isClicked) {
            drawFilledRect(origin, size, Color(204, 228, 247));
            drawRect(origin, size, Color(0, 84, 153));
        }
        else if(isHovered) {
            drawFilledRect(origin, size, Color(229, 241, 251));
            drawRect(origin, size, Color(0, 120, 215));
        }
        else {
            drawFilledRect(origin, size, Color(225, 225, 225));
            drawRect(origin, size, Color(173, 173, 173));
        }
        if(isMidiPlaying() && isMidiClockRunning())
            _pauseSprite.draw(center);
        else
            _playSprite.draw(center);
    }
}

final class RewindButton: Button {
    private {
        Sprite _rewindSprite;
    }

    this() {
        _rewindSprite = fetch!Sprite("rewind");
        size = Vec2f(24f, 24f);
    }

    override void onSubmit() {
        rewindMidi();
    }

    override void update(float deltaTime) {
        super.update(deltaTime);
        if(getButtonDown(KeyButton.r))
            onSubmit();
    }

    override void draw() {
        if(isClicked) {
            drawFilledRect(origin, size, Color(204, 228, 247));
            drawRect(origin, size, Color(0, 84, 153));
        }
        else if(isHovered) {
            drawFilledRect(origin, size, Color(229, 241, 251));
            drawRect(origin, size, Color(0, 120, 215));
        }
        else {
            drawFilledRect(origin, size, Color(225, 225, 225));
            drawRect(origin, size, Color(173, 173, 173));
        }
        _rewindSprite.draw(center);
    }
}

final class StopButton: Button {
    private {
        Sprite _stopSprite;
    }

    this() {
        _stopSprite = fetch!Sprite("stop");
        size = Vec2f(24f, 24f);
    }

    override void onSubmit() {
        stopMidi();
    }

    override void update(float deltaTime) {
        super.update(deltaTime);
        if(getButtonDown(KeyButton.s))
            onSubmit();
    }

    override void draw() {
        if(isClicked) {
            drawFilledRect(origin, size, Color(204, 228, 247));
            drawRect(origin, size, Color(0, 84, 153));
        }
        else if(isHovered) {
            drawFilledRect(origin, size, Color(229, 241, 251));
            drawRect(origin, size, Color(0, 120, 215));
        }
        else {
            drawFilledRect(origin, size, Color(225, 225, 225));
            drawRect(origin, size, Color(173, 173, 173));
        }
        _stopSprite.draw(center);
    }
}

final class ProgressBar: GuiElement {
    private {
        float _factor;
        Sprite _cursorSprite, _circleSprite;
        Color _backgroundColor, _foregroundColor;
    }

    this() {
        size(Vec2f(getWindowWidth() - 100f, 25f));
        _cursorSprite = fetch!Sprite("cursor");
        _circleSprite = fetch!Sprite("circle");
        _backgroundColor = Color(0.70f, 0.75f, 0.76f);
        _foregroundColor = Color(0.255f, 0.41f, 0.85f);
    }

    override void onEvent(Event event) {
        switch(event.type) with(Event.Type) {
        case mouseDown:
            _factor = clamp(rlerp(origin.x, origin.x + size.x, event.mouse.position.x), 0f, 1f);
            setMidiPosition(cast(long) (getMidiDuration() * _factor));
            break;
        case mouseUp:
            break;
        case resize:
            size(Vec2f(event.window.size.x - 100f, 25f));
            break;
        default:
            break;
        }
    }

    override void update(float deltaTime) {
        auto currentTime = getMidiTime();
        auto totalTime = getMidiDuration();
        if(!isMidiPlaying()) {
            _factor = 0f;
        }
        else if(totalTime <= 0) {
            _factor = 1f;
            return;
        }
        else {
            _factor = clamp(currentTime / totalTime, 0f, 1f);
        }
    }

    override void draw() {
        enum barSize = 10f;
        _circleSprite.color = _backgroundColor;
        _circleSprite.draw(Vec2f(origin.x, center.y));
        _circleSprite.draw(Vec2f(origin.x + size.x, center.y));
        drawFilledRect(
            Vec2f(origin.x, center.y - (barSize / 2f)),
            Vec2f(size.x, barSize),
            _backgroundColor);
        if(isMidiPlaying()) {
            _circleSprite.color = _foregroundColor;
            _circleSprite.draw(Vec2f(origin.x, center.y));
            _circleSprite.draw(Vec2f(origin.x + size.x * _factor, center.y));
            drawFilledRect(
                Vec2f(origin.x, center.y - (barSize / 2f)),
                Vec2f(size.x, barSize) * Vec2f(_factor, 1f),
                _foregroundColor);
            _cursorSprite.draw(Vec2f(origin.x + size.x * _factor, center.y));
        }
    }
}

final class CurrentTimeGui: GuiElement {
    private {
        Label _label;
    }

    this() {
        _label = new Label("--:--");
        _label.color = Color.black;
        _label.setAlign(GuiAlignX.center, GuiAlignY.bottom);
        _label.position(Vec2f(0f, 8f));
        size(Vec2f(50f, 25f));
        appendChild(_label);
    }

    override void update(float deltaTime) {
        import core.time: dur;
        import std.format: format;
        import std.conv: to;

        string text;
        if(isMidiPlaying()) {
            const auto time = dur!"msecs"(getMidiTime().to!long).split!("minutes", "seconds");
            text = format!"%02d:%02d"(time.minutes, time.seconds);
        }
        else {
            text = "--:--";
        }
        if(_label.text != text)
            _label.text = text;
    }

    override void draw() {
        _label.draw();
    }
}

final class TotalTimeGui: GuiElement {
    private {
        Label _label;
    }

    this() {
        _label = new Label("--:--");
        _label.color = Color.black;
        _label.setAlign(GuiAlignX.center, GuiAlignY.bottom);
        _label.position(Vec2f(0f, 8f));
        size(Vec2f(50f, 25f));
        appendChild(_label);
    }

    override void update(float deltaTime) {
        import core.time: dur;
        import std.format: format;
        import std.conv: to;

        string text;
        if(isMidiPlaying()) {
            const auto time = dur!"msecs"(getMidiDuration().to!long).split!("minutes", "seconds");
            text = format!"%02d:%02d"(time.minutes, time.seconds);
        }
        else {
            text = "--:--";
        }
        if(_label.text != text)
            _label.text = text;
    }

    override void draw() {
        _label.draw();
    }
}