package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * Crash-safe "the game hit an error" screen, switched to instead of killing
 * the process on an uncaught exception (see SUtil.hx's uncaughtErrorHandler(),
 * Android only). Avoids anything that risks throwing again if the crash
 * handler fires while the asset system itself is what's broken -- but the
 * one font it does try (GameJoltInfo.fontPath / Bronx.otf, the same font
 * every other menu in the game already depends on via
 * HelperFunctions.returnMenuFont() to render at all) is wrapped in its own
 * try/catch, falling back to Flixel's built-in default font only if that
 * fails. Previously always used the built-in default outright, which made
 * this screen look like a generic engine crash dialog instead of Indie
 * Cross's own menus.
 *
 * Ported from NightmareVision-Android-Support's funkin.backend.FallbackState.
 */
class FallbackState extends MusicBeatState
{
	final warningMessage:String;
	final continueCallback:Void->Void;

	public function new(warningMessage:String, continueCallback:Void->Void)
	{
		this.continueCallback = continueCallback;
		this.warningMessage = warningMessage;
		super();
	}

	/**
	 * null falls back to Flixel's own built-in font -- same as this screen
	 * always used before. Only reachable if GameJoltInfo.fontPath itself
	 * fails to resolve (a broken asset system, exactly the case this whole
	 * screen exists to survive), so the try/catch here is not optional.
	 */
	static function resolveFont():Null<String>
	{
		try
			return HelperFunctions.returnMenuFont()
		catch (e:Dynamic)
			return null;
	}

	override function create()
	{
		// FIRST, before building anything -- every other state in this codebase
		// does the same, and this one used to be the lone exception, calling it
		// at the END of create() instead.
		//
		// MusicBeatState.create() opens with Paths.clearStoredMemory() +
		// clearUnusedMemory(), and clearStoredMemory() walks FlxG.bitmap._cache
		// and destroy()s every graphic that isn't in currentTrackedAssets --
		// which includes procedural makeGraphic() output and the bitmaps FlxText
		// renders itself into. Running it last therefore nuked the graphics this
		// very state had just finished creating: bg came back as a dead graphic
		// (the placeholder logo) and so did the ERROR heading and the message.
		//
		// "Tap to continue." was the only survivor, and that is the tell.
		// FlxText builds its graphic lazily -- FlxText.get_width()/get_height()
		// call regenGraphic(), which renders the bitmap and clears _regen.
		// error.screenCenter(X) and text.screenCenter(Y) read those getters, so
		// both had a real graphic by the time the cache was cleared. The hint's
		// size is never read here, so it still had _regen = true, no graphic to
		// destroy, and simply rendered itself fresh on the first draw().
		//
		// This is the crash screen: it has to survive a broken asset system, so
		// it cannot be the thing that breaks its own assets.
		super.create();

		var font:Null<String> = resolveFont();

		var bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, 0xFF1A0A2E);
		add(bg);

		var error = new FlxText(0, 25, 0, 'ERROR', 46);
		error.setFormat(font, 46, FlxColor.RED, LEFT, OUTLINE, FlxColor.BLACK);
		error.screenCenter(X);
		add(error);
		FlxTween.tween(error, {y: error.y + 45}, 2, {ease: FlxEase.sineInOut, type: PINGPONG});

		var text = new FlxText(25, 0, FlxG.width - 50, warningMessage, 28);
		text.setFormat(font, 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(text);
		text.screenCenter(Y);

		var hint = new FlxText(0, FlxG.height - 25 - 32, FlxG.width,
			#if android 'Tap to continue.' #else 'Press Confirm to continue.' #end, 32);
		hint.setFormat(font, 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(hint);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var shouldContinue = controls.ACCEPT;
		#if android
		if (!shouldContinue)
		{
			var touch = FlxG.touches.getFirst();
			shouldContinue = touch != null && touch.justPressed;
		}
		#end
		if (shouldContinue)
		{
			persistentUpdate = false;
			continueCallback();
		}
	}
}
