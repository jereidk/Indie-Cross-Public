package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxInputText;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import offsetMenus.DiffButtonOffsets;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

using StringTools;

/**
 * Touch/keyboard-typed cheat codes, ported from NightmareVision-Android-
 * Support's MainMenuState (its own devCodeField system). A small keyboard
 * icon in the top-right corner opens an FlxInputText box; typing a known
 * code word runs that code's action immediately -- no menu to navigate,
 * same idea as classic Kade Engine cheat codes.
 *
 * Replaces the previous DevPanel.hx (a whole touch-navigable panel you
 * opened with a single 'cheatmenu' code, listing every action as a row to
 * tap): simpler to use, and every action below still does exactly what its
 * DevPanel row used to.
 *
 * DEBUGTOOLS and SHOWCASE don't flip Debug Tools/Showcase Mode on directly
 * -- they only reveal that option in Options > Misc (see OptionsMenu.hx's
 * buildMiscOptions()), same as how NightmareVision-Android-Support's own
 * Misc options only reveal Showcase once Dev Mode is on. The actual on/off
 * switch is that Misc option, entered once and remembered from then on.
 */
class CheatCodes extends FlxSpriteGroup
{
	static inline final CODE_TRIGGER_SIZE:Int = 64;
	static inline final CODE_TRIGGER_MARGIN:Int = 12;

	static inline final DEV_COL_BG:Int = 0xFF1A1414;
	static inline final DEV_COL_ACCENT:Int = 0xFFFF4444;
	static inline final DEV_COL_DANGER:Int = 0xFF7F1D1D;
	static inline final DEV_COL_TEXT:Int = 0xFFFFFFFF;

	// Checked in full (StringTools.trim + toUpperCase) against the field's
	// live text every keystroke, AND again on Enter -- see
	// updateDevCodeGate()/submitDevCode().
	static final CODES:Array<String> = [
		'UNLOCKALL',
		'ALLACHIEVEMENTS',
		'DEBUGTOOLS',
		'SHOWCASE',
		'CHARTEDITOR',
		'OFFSETEDITOR',
		'RESETACHIEVEMENTS',
		'ERASESAVE'
	];

	var state:MainMenuState;

	var devCodeTriggerBg:FlxSprite;
	var devCodeField:FlxInputText;
	var devCodeBoxOpen:Bool = false;
	// Same reasoning as the original: devCodeField.onFocusChange can fire
	// from deep inside the field's own update() (any touch elsewhere makes
	// it drop focus), so closing/destroying it is deferred to a clean frame
	// boundary at the top of this group's own update() instead of being
	// done synchronously from inside that signal.
	var _pendingDevCodeClose:Bool = false;
	var _lastDevCodeText:String = '';

	public function new(state:MainMenuState)
	{
		super();
		this.state = state;

		createDevCodeTrigger();
	}

	override function update(elapsed:Float)
	{
		if (_pendingDevCodeClose)
		{
			_pendingDevCodeClose = false;
			closeDevCodeBox();
		}

		updateDevCodeGate();

		super.update(elapsed);
	}

	// ── code-entry gate ──────────────────────────────────────────────────

	function createDevCodeTrigger():Void
	{
		devCodeTriggerBg = new FlxSprite(FlxG.width - CODE_TRIGGER_SIZE - CODE_TRIGGER_MARGIN, CODE_TRIGGER_MARGIN);
		devCodeTriggerBg.loadGraphic(devKeyboardIcon(CODE_TRIGGER_SIZE, DEV_COL_BG, DEV_COL_ACCENT));
		devCodeTriggerBg.alpha = 0.75;
		devCodeTriggerBg.scrollFactor.set();
		add(devCodeTriggerBg);
	}

	function updateDevCodeGate():Void
	{
		var touches = FlxG.touches.list;
		if (touches != null)
		{
			for (touch in touches)
			{
				if (!touch.justReleased) continue;
				final x0 = FlxG.width - CODE_TRIGGER_SIZE - CODE_TRIGGER_MARGIN - 6;
				final x1 = FlxG.width - CODE_TRIGGER_MARGIN + 6;
				final y0 = CODE_TRIGGER_MARGIN - 6;
				final y1 = CODE_TRIGGER_MARGIN + CODE_TRIGGER_SIZE + 6;
				if (touch.x >= x0 && touch.x <= x1 && touch.y >= y0 && touch.y <= y1)
					toggleDevCodeBox();
				break;
			}
		}

		if (!devCodeBoxOpen) return;

		if (devCodeField != null)
		{
			if (devCodeField.text != _lastDevCodeText)
			{
				_lastDevCodeText = devCodeField.text;
				FlxG.sound.play(Paths.sound('type'));
			}

			final typed = StringTools.trim(devCodeField.text).toUpperCase();
			if (CODES.contains(typed))
				submitDevCode();
		}
	}

	function toggleDevCodeBox():Void
	{
		if (devCodeBoxOpen)
			closeDevCodeBox();
		else
			openDevCodeBox();
	}

	function openDevCodeBox():Void
	{
		if (devCodeField != null)
			return;
		devCodeBoxOpen = true;
		pulseDevCodeTrigger(true);

		// Typing needs the keyboard, not the D-pad -- hide the pad so it
		// isn't sitting there reactable while its presses are actually
		// blocked (see update()'s devCodeBoxOpen gate below).
		if (state.virtualPad != null)
			state.virtualPad.visible = false;

		// Widened from the old single-code box (260px/10 chars) -- the
		// longest code here (RESETACHIEVEMENTS) is 17 characters.
		devCodeField = new FlxInputText(FlxG.width - 320, CODE_TRIGGER_MARGIN + CODE_TRIGGER_SIZE + 8, 308, '', 18, DEV_COL_TEXT, DEV_COL_BG);
		devCodeField.font = Paths.font('vcr.ttf');
		devCodeField.fieldBorderThickness = 2;
		devCodeField.fieldBorderColor = DEV_COL_ACCENT;
		devCodeField.alignment = CENTER;
		devCodeField.multiline = false;
		devCodeField.maxChars = 20;
		devCodeField.scrollFactor.set();
		add(devCodeField);
		_lastDevCodeText = '';

		devCodeField.onEnter.add(_ -> submitDevCode());

		devCodeField.onFocusChange.add((focused) -> {
			if (!focused && devCodeBoxOpen)
				_pendingDevCodeClose = true;
		});

		devCodeField.startFocus();
	}

	function pulseDevCodeTrigger(active:Bool):Void
	{
		if (devCodeTriggerBg == null)
			return;
		FlxTween.cancelTweensOf(devCodeTriggerBg.scale);
		devCodeTriggerBg.alpha = active ? 1.0 : 0.75;
		devCodeTriggerBg.scale.set(active ? 1.15 : 1.0, active ? 1.15 : 1.0);
		FlxTween.tween(devCodeTriggerBg.scale, {x: 1.0, y: 1.0}, 0.25, {ease: FlxEase.quadOut});
	}

	function submitDevCode():Void
	{
		if (devCodeField == null)
			return;

		final typed = StringTools.trim(devCodeField.text).toUpperCase();

		if (runCode(typed))
		{
			closeDevCodeBox();
		}
		else
		{
			devCodeField.backgroundColor = DEV_COL_DANGER;
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			haxe.Timer.delay(() -> {
				if (devCodeField != null)
					devCodeField.backgroundColor = DEV_COL_BG;
			}, 400);
		}
	}

	function closeDevCodeBox():Void
	{
		devCodeBoxOpen = false;
		pulseDevCodeTrigger(false);

		if (state.virtualPad != null)
			state.virtualPad.visible = true;

		if (devCodeField == null)
			return;
		remove(devCodeField, true);
		devCodeField.destroy();
		devCodeField = null;
	}

	// ── code actions ────────────────────────────────────────────────────

	function runCode(code:String):Bool
	{
		switch (code)
		{
			case 'UNLOCKALL':
				// Same fields the old CTRL+P debug shortcut / DevPanel row
				// set (freeplay songs, both week-beat difficulties,
				// genocide/pacifist story flags), PLUS secretChars/
				// shownalerts, which those skip.
				FlxG.save.data.freeplaylocked = [false, false, false];
				FlxG.save.data.weeksbeat = [true, true, true];
				FlxG.save.data.weeksbeatonhard = [true, true, true];
				FlxG.save.data.hasgenocided = true;
				FlxG.save.data.haspacifisted = true;

				// The Nightmare freeplay tab (freeplayType 2 in
				// FreeplayState.hx) gates each song on
				// `weeksbeatonhard[i] && shownalerts[i]`, not
				// weeksbeatonhard alone -- weeksbeatonhard[i] being true
				// just means hard mode was cleared, shownalerts[i] is what
				// actually means "the Nightmare unlock alert for that
				// character has already played". shownalerts only ever
				// flips true from MainMenuState's own reveal check
				// (secretChars[..] all false -> show the alert once ->
				// shownalerts[i] = true), which requires secretChars to
				// have been earned through real play first. Setting
				// weeksbeatonhard=true above without also driving these two
				// through the same "already happened" state left Nightmare
				// permanently empty in Freeplay.
				FlxG.save.data.secretChars = [false, false, false, false, false, false, false, false];
				FlxG.save.data.shownalerts = [true, true, true];

				FlxG.save.flush();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.8);

			case 'ALLACHIEVEMENTS':
				for (a in Achievements.achievements)
					Achievements.unlockAchievement(a.name, false);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.8);

			case 'DEBUGTOOLS':
				// Doesn't turn Debug Tools on by itself -- reveals its
				// toggle in Options > Misc (OptionsMenu.hx), same treatment
				// as SHOWCASE below.
				FlxG.save.data.debugToolsCodeUnlocked = true;
				FlxG.save.flush();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);

			case 'SHOWCASE':
				FlxG.save.data.showcaseCodeUnlocked = true;
				FlxG.save.flush();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);

			case 'CHARTEDITOR':
				FlxG.switchState(() -> new ChartingState());

			case 'OFFSETEDITOR':
				FlxG.switchState(() -> new DiffButtonOffsets());

			case 'RESETACHIEVEMENTS':
				// Typing the whole word out is already a much stronger
				// intent signal than the old panel's tap-twice-within-3s
				// button, but this still permanently erases progress -- a
				// confirm prompt costs nothing and matches ERASESAVE below.
				state.persistentUpdate = false;
				state.openSubState(new Prompt("Reset all achievements?"));
				Prompt.acceptThing = function()
				{
					Achievements.defaultAchievements();
					FlxG.sound.play(Paths.sound('delete'), 0.7);
					state.persistentUpdate = true;
				}
				Prompt.backThing = function()
				{
					state.persistentUpdate = true;
				}

			case 'ERASESAVE':
				// Same confirm-prompt flow as the existing DELETE-key/
				// virtual pad C-button handler in MainMenuState's own
				// update().
				state.persistentUpdate = false;
				state.openSubState(new Prompt("Are you sure you want to erase your save?"));
				Prompt.acceptThing = function()
				{
					FlxG.save.erase();
					FlxG.save.flush();
					FlxG.save.bind(Main.curSave, 'indiecross');
					KadeEngineData.initSave();
					FlxG.sound.play(Paths.sound('delete'), 0.7);
					TitleState.restart();
				}
				Prompt.backThing = function()
				{
					state.persistentUpdate = true;
				}

			default:
				return false;
		}

		return true;
	}

	// ── procedural shapes (no asset files needed for the trigger icon) ────

	function devRoundedRect(w:Int, h:Int, color:Int, radius:Int):BitmapData
	{
		var bmp = new BitmapData(w, h, true, 0x00000000);
		var r = radius;

		for (px in 0...w)
		{
			for (py in 0...h)
			{
				var inside = true;

				if (px < r && py < r)
				{
					var dx = r - px, dy = r - py;
					if (dx * dx + dy * dy > r * r) inside = false;
				}
				else if (px >= w - r && py < r)
				{
					var dx = px - (w - r - 1), dy = r - py;
					if (dx * dx + dy * dy > r * r) inside = false;
				}
				else if (px < r && py >= h - r)
				{
					var dx = r - px, dy = py - (h - r - 1);
					if (dx * dx + dy * dy > r * r) inside = false;
				}
				else if (px >= w - r && py >= h - r)
				{
					var dx = px - (w - r - 1), dy = py - (h - r - 1);
					if (dx * dx + dy * dy > r * r) inside = false;
				}

				if (inside) bmp.setPixel32(px, py, color);
			}
		}

		return bmp;
	}

	function devKeyboardIcon(size:Int, bgColor:Int, keyColor:Int):BitmapData
	{
		var bmp = devRoundedRect(size, size, bgColor, Std.int(size * 0.22));

		var margin:Int = Std.int(size * 0.16);
		var cols:Int = 4;
		var gap:Int = Std.int(size * 0.06);
		var usableW:Int = size - margin * 2;
		var keyW:Float = (usableW - gap * (cols - 1)) / cols;
		var keyH:Int = Std.int(size * 0.14);
		var rowY:Int = Std.int(size * 0.28);

		for (col in 0...cols)
		{
			var kx = Std.int(margin + col * (keyW + gap));
			bmp.fillRect(new Rectangle(kx, rowY, keyW, keyH), keyColor);
		}

		var barY:Int = rowY + keyH + gap;
		bmp.fillRect(new Rectangle(margin, barY, usableW, keyH), keyColor);

		return bmp;
	}
}
