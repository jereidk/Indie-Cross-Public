package;

import android.flixel.FlxVirtualPad;
import flixel.FlxCamera;
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
 * Touch-friendly "type a code, get a panel" dev gate, ported from
 * NightmareVision-Android-Support's MainMenuState (its own devCodeField +
 * dev panel system). A small keyboard icon in the top-right corner opens an
 * FlxInputText box; typing the code opens a touch-navigable panel with a
 * handful of debug actions. Kept in its own file/class (instead of inline
 * in MainMenuState, like the original) so MainMenuState only needs to
 * create it, add it, and let it run -- everything else is self-contained.
 *
 * Trimmed down from NightmareVision's version to what this codebase
 * actually has: no ClientPrefs-based unlock/economy flags, no FNAF code, no
 * audio-synced "epic unlock" glow timed off a specific .ogg waveform.
 * The panel rows mostly just expose existing keyboard-only debug shortcuts
 * from MainMenuState's own update() (CTRL+P unlock-everything, CTRL+SHIFT+A
 * grant achievements, CTRL+I offset editor, CTRL+L showcase mode, the
 * DELETE-key save eraser) as touch buttons, plus a chart editor shortcut and
 * an achievements reset.
 */
class DevPanel extends FlxSpriteGroup
{
	static inline final DEV_CODE:String = 'cheatmenu';
	static inline final CODE_TRIGGER_SIZE:Int = 64;
	static inline final CODE_TRIGGER_MARGIN:Int = 12;

	static inline final DEV_COL_BG:Int = 0xFF1A1414;
	static inline final DEV_COL_ACCENT:Int = 0xFFFF4444;
	static inline final DEV_COL_DANGER:Int = 0xFF7F1D1D;
	static inline final DEV_COL_DANGER_ARMED:Int = 0xFFFF4444;
	static inline final DEV_COL_TEXT:Int = 0xFFFFFFFF;
	static inline final DEV_PANEL_BG:Int = 0xFF120D0D;
	static inline final DEV_COL_SECTION:Int = 0xFF9C7A7A;
	static inline final DEV_COL_TOGGLE:Int = 0xFF332424;
	static inline final DEV_COL_TOGGLE_ON:Int = 0xFF2E7D32;
	static inline final DEV_COL_LOOT:Int = 0xFF9C6B1F;
	static inline final DEV_COL_TOOL:Int = 0xFF1E3A5F;
	static inline final DEV_COL_CLOSE:Int = 0xFF241A1A;

	var state:MainMenuState;

	// ── code-entry gate ──────────────────────────────────────────────────
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

	// ── panel state ──────────────────────────────────────────────────────
	var devPanelOpen:Bool = false;
	var devPanelAll:Array<FlxSprite> = [];
	var devPanelBtns:Array<{x:Float, y:Float, w:Float, h:Float, idx:Int}> = [];
	var devPanelCooldown:Int = 0;
	var devPanelCam:FlxCamera;

	var devPanelX:Float = 0;
	var devPanelY:Float = 0;
	var devPanelW:Float = 0;
	var devPanelH:Float = 0;

	var devLblDebug:FlxText;
	var devLblShowcase:FlxText;
	var devLblReset:FlxText;
	var devResetBtnSpr:FlxSprite;
	var devResetArmed:Bool = false;
	var devResetArmedUntil:Float = 0;

	public function new(state:MainMenuState)
	{
		super();
		this.state = state;

		createDevCodeTrigger();
		buildDevPanel();
	}

	override function update(elapsed:Float)
	{
		if (_pendingDevCodeClose)
		{
			_pendingDevCodeClose = false;
			closeDevCodeBox();
		}

		updateDevCodeGate();
		updateDevPanel();

		super.update(elapsed);
	}

	override function destroy()
	{
		if (devPanelCam != null)
		{
			if (FlxG.cameras.list.indexOf(devPanelCam) != -1)
				FlxG.cameras.remove(devPanelCam);
			devPanelCam = null;
		}

		super.destroy();
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
		// Panel's dim overlay sits visually on top of the trigger icon once
		// open -- skip entirely so a touch landing in that same corner can't
		// reopen the code box while the panel is already up.
		if (devPanelOpen) return;

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

			final typed = StringTools.trim(devCodeField.text).toLowerCase();
			if (typed == DEV_CODE)
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

		devCodeField = new FlxInputText(FlxG.width - 272, CODE_TRIGGER_MARGIN + CODE_TRIGGER_SIZE + 8, 260, '', 20, DEV_COL_TEXT, DEV_COL_BG);
		devCodeField.font = Paths.font('vcr.ttf');
		devCodeField.fieldBorderThickness = 2;
		devCodeField.fieldBorderColor = DEV_COL_ACCENT;
		devCodeField.alignment = CENTER;
		devCodeField.multiline = false;
		devCodeField.maxChars = 10;
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

		final typed = StringTools.trim(devCodeField.text).toLowerCase();
		if (typed == DEV_CODE)
		{
			closeDevCodeBox();
			openDevPanel();
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

	// ── procedural shapes (no asset files needed for the panel chrome) ────

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

	function devRoundedRectTop(w:Int, h:Int, color:Int, radius:Int):BitmapData
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

	// ── panel content ───────────────────────────────────────────────────

	function buildDevPanel():Void
	{
		var PW:Int = 560;
		var PH:Int = 640;
		var px:Int = Std.int((FlxG.width - PW) / 2);
		var py:Int = Std.int((FlxG.height - PH) / 2);
		var BW:Int = PW - 48;
		var BH:Int = 40;
		var BX:Int = px + 24;

		devPanelX = px;
		devPanelY = py;
		devPanelW = PW;
		devPanelH = PH;

		function reg(thing:FlxSprite):Void
		{
			thing.visible = false;
			devPanelAll.push(thing);
			add(thing);
		}

		var overlay = new FlxSprite(0, 0);
		overlay.makeGraphic(FlxG.width, FlxG.height, 0xBF000000);
		reg(overlay);

		var bg = new FlxSprite(px, py);
		bg.loadGraphic(devRoundedRect(PW, PH, DEV_PANEL_BG, 22));
		reg(bg);

		var topBand = new FlxSprite(px, py);
		topBand.loadGraphic(devRoundedRectTop(PW, 80, DEV_COL_BG, 22));
		topBand.alpha = 0.9;
		reg(topBand);

		var accent = new FlxSprite(px + 22, py + 16);
		accent.makeGraphic(6, 40, DEV_COL_ACCENT);
		reg(accent);

		var title = new FlxText(px + 40, py + 14, PW - 80, 'DEVELOPER PANEL', 28);
		title.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		reg(title);

		var subtitle = new FlxText(px + 42, py + 46, PW - 80, 'you shouldn\'t be here', 13);
		subtitle.setFormat(Paths.font('vcr.ttf'), 13, DEV_COL_SECTION, LEFT, OUTLINE, FlxColor.BLACK);
		reg(subtitle);

		var rowY:Int = py + 88;

		function sectionLabel(text:String):Void
		{
			var lbl = new FlxText(BX, rowY, BW, text, 13);
			lbl.setFormat(Paths.font('vcr.ttf'), 13, DEV_COL_SECTION, LEFT, OUTLINE, FlxColor.BLACK);
			reg(lbl);
			rowY += 20;
		}

		function addRow(label:String, bgColor:Int, btnIdx:Int):FlxText
		{
			var spr = new FlxSprite(BX, rowY);
			spr.loadGraphic(devRoundedRect(BW, BH, bgColor, 10));
			reg(spr);

			var lbl = new FlxText(BX, rowY + 10, BW, label, 16);
			lbl.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			reg(lbl);

			devPanelBtns.push({x: BX, y: rowY, w: BW, h: BH, idx: btnIdx});
			rowY += BH + 6;
			return lbl;
		}

		sectionLabel('PROGRESSION');
		// Mirrors the existing CTRL+P debug shortcut exactly (see update()'s
		// old debugTools-gated keyboard block): unlocks every freeplay song,
		// marks every week beaten (normal + hard), and flips the genocide/
		// pacifist story flags -- all keyboard-only before this panel existed.
		addRow('Unlock Everything', DEV_COL_LOOT, 0);
		addRow('Grant All Achievements', DEV_COL_LOOT, 1);

		rowY += 4;
		sectionLabel('DEBUG');
		devLblDebug = addRow(devDebugLabel(), MainMenuState.debugTools ? DEV_COL_TOGGLE_ON : DEV_COL_TOGGLE, 2);
		devLblShowcase = addRow(devShowcaseLabel(), MainMenuState.showcase ? DEV_COL_TOGGLE_ON : DEV_COL_TOGGLE, 3);

		rowY += 4;
		sectionLabel('TOOLS');
		addRow('Chart Editor', DEV_COL_TOOL, 4);
		addRow('Offset Editor', DEV_COL_TOOL, 5);

		rowY += 4;
		sectionLabel('DANGER ZONE');
		devLblReset = addRow('!  Reset Achievements', DEV_COL_DANGER, 6);
		devResetBtnSpr = devPanelAll[devPanelAll.length - 2];
		addRow('!  Erase Save Data', DEV_COL_DANGER, 7);

		rowY += 6;
		addRow('X  Close', DEV_COL_CLOSE, 8);
	}

	function devDebugLabel():String
		return MainMenuState.debugTools ? 'Debug Tools  ON' : 'Debug Tools  OFF';

	function devShowcaseLabel():String
		return MainMenuState.showcase ? 'Showcase Mode  ON' : 'Showcase Mode  OFF';

	function devResetLabel():String
		return devResetArmed ? '!  TAP AGAIN TO CONFIRM' : '!  Reset Achievements';

	function openDevPanel():Void
	{
		devPanelOpen = true;
		devPanelCooldown = 5;
		devResetArmed = false;

		// The panel's rows visually cover the same bottom corners the D-pad
		// and A/B/C buttons sit in (see MainMenuState's own pad-collision
		// fix) -- hide the pad so a row tap can't also register as a pad
		// button press underneath it. Only touch-tap row navigation is
		// implemented here, so the pad has nothing to do while this is open.
		if (state.virtualPad != null) state.virtualPad.visible = false;

		if (devLblDebug != null) devLblDebug.text = devDebugLabel();
		if (devLblShowcase != null) devLblShowcase.text = devShowcaseLabel();
		if (devLblReset != null) devLblReset.text = devResetLabel();

		// Dedicated camera, added last so it renders on top of everything
		// (game sprites, virtual pad, HUD). `false` here is load-bearing --
		// FlxG.cameras.add()'s DefaultDrawTarget defaults to true, which
		// would make this a default render target for every sprite in the
		// state that doesn't set its own `.cameras`, silently duplicating
		// the whole rest of the menu on top of itself. Every panel sprite is
		// already explicitly pinned to devPanelCam below, so it never needs
		// to be a default target.
		if (devPanelCam == null)
		{
			devPanelCam = new FlxCamera();
			devPanelCam.bgColor = 0x00000000;
			FlxG.cameras.add(devPanelCam, false);
			for (thing in devPanelAll) thing.cameras = [devPanelCam];
			devCodeTriggerBg.cameras = [devPanelCam];
		}

		FlxG.sound.play(Paths.sound('confirmMenu'), 0.8);

		var i = 0;
		for (thing in devPanelAll)
		{
			thing.visible = true;
			var startY = thing.y;
			thing.y = startY + 18;
			thing.alpha = 0;

			var delay = Math.min(i * 0.012, 0.18);
			FlxTween.tween(thing, {y: startY, alpha: 1}, 0.28, {ease: FlxEase.quintOut, startDelay: delay});
			i++;
		}
	}

	function closeDevPanel():Void
	{
		devPanelOpen = false;
		devResetArmed = false;
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
		for (thing in devPanelAll)
		{
			FlxTween.cancelTweensOf(thing);
			thing.visible = false;
			thing.alpha = 1;
		}
		if (state.virtualPad != null) state.virtualPad.visible = true;
	}

	function handleDevBtnTap(idx:Int):Void
	{
		switch (idx)
		{
			case 0: // Unlock Everything -- same fields MainMenuState's own
				// CTRL+P debug shortcut sets (freeplay songs, both week-beat
				// difficulties, genocide/pacifist story flags), PLUS
				// secretChars/shownalerts (see below) that shortcut also
				// skips.
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
				// permanently empty in Freeplay -- the debugTools `||`
				// bypass on that same condition (FreeplayState.hx:205-215)
				// hid this unless Debug Tools was separately toggled too.
				FlxG.save.data.secretChars = [false, false, false, false, false, false, false, false];
				FlxG.save.data.shownalerts = [true, true, true];

				FlxG.save.flush();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.8);

			case 1: // Grant every achievement
				for (a in Achievements.achievements)
					Achievements.unlockAchievement(a.name, false);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.8);

			case 2: // Debug tools toggle
				MainMenuState.debugTools = !MainMenuState.debugTools;
				if (devLblDebug != null) devLblDebug.text = devDebugLabel();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);

			case 3: // Showcase mode toggle
				MainMenuState.showcase = !MainMenuState.showcase;
				if (devLblShowcase != null) devLblShowcase.text = devShowcaseLabel();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);

			case 4: // Chart Editor
				closeDevPanel();
				FlxG.switchState(() -> new ChartingState());

			case 5: // Offset Editor
				closeDevPanel();
				FlxG.switchState(() -> new DiffButtonOffsets());

			case 6: // Reset achievements -- two-tap confirm to avoid fat-finger data loss
				if (!devResetArmed)
				{
					devResetArmed = true;
					devResetArmedUntil = haxe.Timer.stamp() + 3.0;
					if (devLblReset != null) devLblReset.text = devResetLabel();
					if (devResetBtnSpr != null)
					{
						var bw = Std.int(devResetBtnSpr.width), bh = Std.int(devResetBtnSpr.height);
						devResetBtnSpr.loadGraphic(devRoundedRect(bw, bh, DEV_COL_DANGER_ARMED, 10));
					}
					FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
				}
				else
				{
					Achievements.defaultAchievements();
					FlxG.sound.play(Paths.sound('delete'), 0.7);
					closeDevPanel();
				}

			case 7: // Erase Save Data -- same confirm-prompt flow as the
				// existing DELETE-key/virtual pad C-button handler in
				// MainMenuState's own update().
				closeDevPanel();
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

			case 8: // Close
				closeDevPanel();
		}
	}

	function updateDevPanel():Void
	{
		if (!devPanelOpen)
			return;

		if (devPanelCooldown > 0)
		{
			devPanelCooldown--;
			return;
		}

		// Auto-revert the destructive-reset arm state if not confirmed in time.
		if (devResetArmed && haxe.Timer.stamp() > devResetArmedUntil)
		{
			devResetArmed = false;
			if (devLblReset != null) devLblReset.text = devResetLabel();
			if (devResetBtnSpr != null)
			{
				var bw = Std.int(devResetBtnSpr.width), bh = Std.int(devResetBtnSpr.height);
				devResetBtnSpr.loadGraphic(devRoundedRect(bw, bh, DEV_COL_DANGER, 10));
			}
		}

		var touches = FlxG.touches.list;
		if (touches != null)
		{
			for (touch in touches)
			{
				if (!touch.justReleased) continue;
				var tapped = false;
				for (btn in devPanelBtns)
				{
					if (touch.x >= btn.x && touch.x <= btn.x + btn.w && touch.y >= btn.y && touch.y <= btn.y + btn.h)
					{
						handleDevBtnTap(btn.idx);
						tapped = true;
						break;
					}
				}
				// Only close on a tap landing fully outside the panel body --
				// a near-miss between two rows (still inside the panel)
				// shouldn't close the whole thing on a stray touch.
				if (!tapped && !devPanelContains(touch.x, touch.y))
					closeDevPanel();
				break;
			}
		}
	}

	function devPanelContains(x:Float, y:Float):Bool
	{
		return x >= devPanelX && x <= devPanelX + devPanelW && y >= devPanelY && y <= devPanelY + devPanelH;
	}
}
