package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.events.Event;

#if VIDEOS_ALLOWED
import hxvlc.flixel.FlxVideoSprite;
#end

/**
 * Plays an .mp4 into an existing placeholder FlxSprite (`outputTo`), matching
 * that sprite's position/size/cameras so callers don't need to change how
 * they set up their cutscene sprite.
 *
 * Ported from the old raw-VlcBitmap implementation to the hxvlc haxelib --
 * the previous source/vlc/ C++ extension only ever shipped linux/mac/windows
 * builds of libvlc/libvlccore (no Android .so's were ever built for it), so
 * video never actually played on Android. hxvlc ships its own prebuilt
 * Android binaries, same library NightmareVision-Android-Support uses.
 *
 * Public API (allowSkip / finishCallback / stateCallback / fadeToBlack /
 * fadeFromBlack / playMP4 / kill) is unchanged so every existing call site
 * (PlayState, MainMenuState, TitleState, GameOverSubstate) needs no edits.
 */
class VideoHandler
{
	public var finishCallback:Void->Void;
	public var stateCallback:FlxState;
	public var fadeToBlack:Bool = false;
	public var fadeFromBlack:Bool = false;
	public var allowSkip:Bool = false;

	#if VIDEOS_ALLOWED
	var video:FlxVideoSprite;
	var outputTo:FlxSprite;
	#end

	public function new()
	{
		FlxG.autoPause = false;
	}

	public function playMP4(path:String, ?repeat:Bool = false, ?outputTo:FlxSprite = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false,
			?midSong:Bool = false):Void
	{
		#if VIDEOS_ALLOWED
		if (!midSong && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		this.outputTo = outputTo;

		video = new FlxVideoSprite();
		video.bitmap.onFormatSetup.add(onVideoReady, true);
		video.bitmap.onEndReached.add(onComplete, true);

		if (repeat)
			video.load(checkFile(path), [':input-repeat=65535']);
		else
			video.load(checkFile(path));

		FlxG.state.add(video);
		video.play();

		if (outputTo != null)
			outputTo.visible = false;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		#end
	}

	function checkFile(fileName:String):String
	{
		#if android
		// fileName here is a plain asset path (Paths.video(...), e.g.
		// 'assets/videos/intro.mp4') -- no external-storage extraction, no
		// file:// wrapping. hxvlc.openfl.Video.load() already handles a bare
		// asset path itself: it checks Assets.exists()/Assets.getPath(), and
		// falls back to loading straight from Assets.getBytes() in memory
		// when Android's own AssetManager-backed assets don't resolve to a
		// real java.io.File path (which they never do -- APK-packaged
		// assets aren't real files on disk). Matches NightmareVision's own
		// FunkinVideoSprite, which passes Paths.video(...) to load()
		// completely unmodified for the exact same reason.
		return fileName;
		#elseif linux
		return 'file://' + Sys.getCwd() + fileName;
		#elseif windows
		return 'file:///' + Sys.getCwd() + fileName;
		#else
		return fileName;
		#end
	}

	/////////////////////////////////////////////////////////////////////////////////////

	#if VIDEOS_ALLOWED
	function onVideoReady():Void
	{
		trace("video loaded!");

		// Match whatever footprint the caller already sized/positioned
		// outputTo with (e.g. a full-screen black backdrop, or a smaller HUD
		// sprite) instead of guessing dimensions -- outputTo stays hidden
		// (see playMP4 above), this sprite renders the actual moving video
		// in its place.
		if (outputTo != null)
		{
			video.setGraphicSize(Std.int(outputTo.width), Std.int(outputTo.height));
			video.updateHitbox();
			video.x = outputTo.x;
			video.y = outputTo.y;
			video.cameras = outputTo.cameras;
		}

		if (fadeFromBlack)
			FlxG.camera.fade(FlxColor.BLACK, 0, false);
	}

	function onComplete():Void
	{
		video.pause();

		if (fadeToBlack)
			FlxG.camera.fade(FlxColor.BLACK, 0, false);

		if (fadeFromBlack)
			FlxG.camera.fade(FlxColor.BLACK, 1, true);

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			if (finishCallback != null)
				finishCallback();
			else if (stateCallback != null)
				LoadingState.loadAndSwitchState(stateCallback);

			if (video != null)
			{
				FlxG.state.remove(video);
				video.destroy();
				video = null;
			}
		});
	}

	function onEnterFrame(e:Event):Void
	{
		if (video == null)
			return;

		if (FlxG.keys.justPressed.ENTER #if android || FlxG.android.justReleased.BACK #end && (allowSkip && video.bitmap.isPlaying))
			onComplete();

		video.bitmap.volume = FlxG.sound.volume <= 0.1 ? 0 : FlxG.sound.volume;
	}
	#end

	public function kill()
	{
		#if VIDEOS_ALLOWED
		if (video != null)
		{
			video.visible = false;
			video.pause();
		}

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);

		if (finishCallback != null)
			finishCallback();
		#end
	}
}
