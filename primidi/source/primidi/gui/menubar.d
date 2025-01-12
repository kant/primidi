/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module primidi.gui.menubar;

import atelier;
import primidi.player, primidi.midi, primidi.locale;
import primidi.gui.open_file, primidi.gui.port, primidi.gui.locale;
import primidi.gui.plugin, primidi.gui.ticks;

private {
    bool _isMenuFocused;
    float[] _menuSizes;
}

/** 
 * Bar on top that contains configuration options.
 */
final class MenuBar: GuiElement {
    private {
        MenuButton[] _buttons;
        bool _isVisible = true;
    }

    this() {
        size(Vec2f(getWindowWidth(), 20f));
        auto box = new HContainer;
        appendChild(box);

        const auto menuNames = ["media", "ports", "plugin", "view"];
        const auto menuItems = [
            ["media.open", "media.quit"],
            ["port.input", "port.output"],
            ["plugin.open", "plugin.reload", "plugin.restart", "plugin.ticks"],
            ["view.locale", "view.hide", "view.fullscreen"]
            ];
        _menuSizes.length = menuNames.length;
        for(size_t i = 0uL; i < menuNames.length; ++ i) {
            auto menuBtn = new MenuButton(menuNames[i], menuItems[i], cast(uint) i, cast(uint) menuNames.length);
            menuBtn.setCallback(this, "menu");
            box.appendChild(menuBtn);
            _buttons ~= menuBtn;
        }

        GuiState hiddenState = {
            offset: Vec2f(0f, -20f),
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
            size(Vec2f(event.window.size.x, 20f));
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
        _isMenuFocused = true;
        switch(id) {
        case "menu":
            stopOverlay();
            foreach(child; _buttons) {
                child.isHovered = false;
                child.isClicked = false;
                child.hasFocus = false;
            }
            foreach(child; _buttons) {
                if(child.requestChange) {
                    child.requestChange = false;
                    _buttons[child.changeId].isClicked = true;
                    _buttons[child.changeId].onSubmit();
                    break;
                }
            }
            break;
        default:
            break;
        }
    }

    override void draw() {
        drawFilledRect(origin, size, Color.white);
    }
}

private final class MenuCancel: GuiElement {
    this() {
        size(getWindowSize());
    }

    override void onSubmit() {
        triggerCallback();
    }
}

private final class MenuChange: GuiElement {
    uint triggerId;

    this(uint id) {
        triggerId = id;
    }

    override void onHover() {
        triggerCallback();
    }
}

private final class MenuButton: GuiElement {
    private {
        Label _label;
        MenuCancel _cancelTrigger;
        MenuChange[] _changeTriggers;
        MenuList _list;
        uint _changeId, _menuId;
        string _nameId;
    }
    bool requestChange;

    @property uint changeId() const { return _changeId; }

    this(const string name, const(string[]) menuItems, uint id, uint maxId) {
        _nameId = name;
        _menuId = id;
        _label = new Label(getLocalizedText(_nameId));
        _label.setAlign(GuiAlignX.center, GuiAlignY.center);
        _label.color = Color.black;
        appendChild(_label);
        size(Vec2f(_label.size.x + 20f, 20f));
        _menuSizes[_menuId] = size.x;

        _list = new MenuList(this, menuItems);
        _cancelTrigger = new MenuCancel;
        _cancelTrigger.setCallback(this, "cancel");

        for(uint i = 0u; i < maxId; ++ i) {
            if(i == _menuId)
                continue;
            auto changeTrigger = new MenuChange(i);
            changeTrigger.size = size;
            changeTrigger.setCallback(this, "change");
            _changeTriggers ~= changeTrigger;
        }
    }

    override void onEvent(Event event) {
        switch(event.type) with(Event.Type) {
        case resize:
            _cancelTrigger.size = cast(Vec2f) event.window.size;
            break;
        case custom:
            if(event.custom.id == "locale") {
                _label.text = getLocalizedText(_nameId);
                size(Vec2f(_label.size.x + 20f, 20f));
                _menuSizes[_menuId] = size.x;
                _list.localize();
            }
            break;
        default:
            break;
        }
    }

    override void onSelect() {
        if(isSelected)
            onSubmit();
    }

    override void onSubmit() {
        setOverlay(_cancelTrigger);
        foreach(changeTrigger; _changeTriggers) {
            setOverlay(changeTrigger);
        }
        setOverlay(_list);
    }

    override void update(float deltaTime) {
        if(getButtonDown(KeyButton.f12))
            onCallback("view.fullscreen");
        if(getButtonDown(KeyButton.f11))
            onCallback("view.hide");
        if(getButtonDown(KeyButton.f5))
            onCallback("plugin.reload");
        if(getButtonDown(KeyButton.f6))
            onCallback("plugin.restart");
        if(isButtonDown(KeyButton.leftControl) || isButtonDown(KeyButton.rightControl)) {
            if(getButtonDown(KeyButton.o))
                onCallback("media.open");
            if(getButtonDown(KeyButton.q))
                onCallback("media.quit");
        }
    }

    override void onCallback(string id) {
        switch(id) {
        case "cancel":
            stopOverlay();
            isClicked = false;
            break;
        case "change":
            foreach(changeTrigger; _changeTriggers) {
                if(changeTrigger.isHovered) {
                    _changeId = changeTrigger.triggerId;
                    requestChange = true;
                    triggerCallback();
                    break;
                }
            }
            break;
        case "media.open":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            auto modal = new OpenModal(getMidiFilePath(), [".mid", ".midi"]);
            modal.setCallback(this, "media.open.modal");
            pushModal(modal);
            break;
        case "media.open.modal":
            auto modal = popModal!OpenModal;
            playMidi(modal.getPath());
            break;
        case "media.quit":
            stopOverlay();
            stopApplication();
            break;
        case "port.output":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            pushModal(new OutPortModal);
            break;
        case "port.input":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            pushModal(new InPortModal);
            break;
        case "plugin.open":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            pushModal(new SelectPluginModal);
            break;
        case "plugin.reload":
            if(isModal())
                stopModal();
            stopOverlay();
            isClicked = false;
            isHovered = false;
            reloadScript();
            break;
        case "plugin.restart":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            restartScript();
            break;
        case "plugin.ticks":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            pushModal(new SelectTicksIntervalModal);
            break;
        case "view.locale":
            stopOverlay();
            isClicked = false;
            isHovered = false;
            pushModal(new SelectLocaleModal);
            break;
        case "view.hide":
            stopOverlay();
            sendCustomEvent("hide");
            break;
        case "view.fullscreen":
            stopOverlay();
            if(getWindowDisplay() == DisplayMode.windowed)
                setWindowDisplay(DisplayMode.desktop);
            else
                setWindowDisplay(DisplayMode.windowed);
            break;
        default:
            break;
        }
    }

    override void draw() {
        if(isClicked) {
            drawFilledRect(origin, size, Color(153, 209, 255));
            drawRect(origin, size, Color(204, 232, 255));
        }
        else if(isHovered) {
            drawFilledRect(origin, size, Color(229, 243, 255));
            drawRect(origin, size, Color(204, 232, 255));
        }
    }

    override void drawOverlay() {
        _list.position = origin + Vec2f(0f, size.y);

        foreach(changeTrigger; _changeTriggers) {
            float x = 0f;
            for(uint i = 0u; i < changeTrigger.triggerId; ++ i) {
                x += _menuSizes[i];
            }
            changeTrigger.position = Vec2f(x, 0f);
            changeTrigger.size = Vec2f(_menuSizes[changeTrigger.triggerId], 20f);
        }
    }
}

/** 
 * Overlay container
 */
private final class MenuList: VContainer {
    this(GuiElement callbackObject, const(string[]) options) {
        position(Vec2f(0f, 20f));
        setChildAlign(GuiAlignX.left);
        foreach(option; options) {
            auto btn = new MenuItem(option);
            btn.setCallback(callbackObject, option);
            appendChild(btn);
        }
    }

    override void update(float deltaTime) {
        super.update(deltaTime);
        foreach(child; cast(MenuItem[]) children)
            child.parentSize = size.x;
    }

    void localize() {
        foreach(child; cast(MenuItem[]) children)
            child.localize();
    }

    override void draw() {
        drawFilledRect(origin, size, Color.white);
    }
}

private final class MenuItem: GuiElement {
    private {
        Label _label;
        string _nameId;
    }

    float parentSize = 0f;

    this(string name) {
        _nameId = name;
        _label = new Label(getLocalizedText(_nameId));
        _label.position(Vec2f(50f, 0f));
        _label.setAlign(GuiAlignX.left, GuiAlignY.center);
        _label.color = Color.black;
        appendChild(_label);
        size(Vec2f(_label.size.x + 100f, 30f));
    }

    void localize() {
        _label.text = getLocalizedText(_nameId);
        size(Vec2f(_label.size.x + 100f, 30f));
    }

    override void onSubmit() {
        triggerCallback();
    }

    override void onHover() {

    }

    override void draw() {
        if(isHovered) {
            drawFilledRect(origin, Vec2f(parentSize, size.y), Color(229, 243, 255));
            drawRect(origin, Vec2f(parentSize, size.y), Color(204, 232, 255));
        }
    }
}