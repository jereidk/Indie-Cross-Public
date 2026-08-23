package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.typeLimit.NextState;
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
	public var stateCallback:NextState;
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
			// Size to the placeholder's DRAWN footprint, not its hitbox.
			// FlxSprite.width/height are the collision box, and freaky-machine's
			// placeholder does makeGraphic(FlxG.width, FlxG.height) and then
			// assigns .width/.height a quarter of that. Under the original raw
			// VlcBitmap implementation those two lines were inert: it did
			// sprite.loadGraphic(bitmap.bitmapData), and loadGraphic resets
			// width/height from the new graphic, so the quarter only ever
			// affected the screenCenter() call sitting between them. Reading
			// .width here revived that vestigial line and shrank the background
			// video to a quarter of the screen.
			//
			// Falls back to width/height when there is no graphic at all --
			// sansSprite is a bare `new FlxSprite(0, 0)` with .width/.height
			// assigned by hand and no makeGraphic, so frameWidth/frameHeight
			// are 0 there and the hitbox IS the intended footprint.
			var targetWidth:Float = outputTo.frameWidth > 0 ? outputTo.frameWidth * outputTo.scale.x : outputTo.width;
			var targetHeight:Float = outputTo.frameHeight > 0 ? outputTo.frameHeight * outputTo.scale.y : outputTo.height;

			video.setGraphicSize(Std.int(targetWidth), Std.int(targetHeight));
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
		// This listener lives on FlxG.stage, which SURVIVES state switches --
		// but the video sprite is added to FlxG.state, so switching states
		// destroys it, and FlxVideoSprite.destroy() nulls its `bitmap`. The
		// old `video == null` check never caught that: our own reference stays
		// non-null while the object behind it is dead, so the next line
		// dereferenced a null bitmap and crashed (reported as
		// "VideoHandler.hx (line 160) Null Object Reference" on Freaky-Machine).
		//
		// A LOOPING video makes this certain rather than incidental:
		// onEndReached never fires, so onComplete() never runs and never
		// removes this listener, and PlayState only ever pause()/resume()s the
		// videos in gameVideos -- kill() is never called on them. So the
		// listener always outlives the sprite. Detach as soon as it is gone.
		if (video == null || video.bitmap == null)
		{
			FlxG.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			video = null;
			return;
		}

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

	/**
	 * Pauses/resumes playback -- e.g. PlayState pausing every active cutscene
	 * video when the game itself pauses. video is a private field (bare
	 * `bitmap.pause()`/`.resume()` on a VideoHandler instance isn't valid
	 * from outside this class), so these two are the encapsulated equivalent.
	 */
	public function pause()
	{
		#if VIDEOS_ALLOWED
		// bitmap null-checked for the same reason as onEnterFrame: PlayState
		// pauses every entry in gameVideos, and one of those sprites may
		// already have been destroyed by a state switch.
		if (video != null && video.bitmap != null)
			video.bitmap.pause();
		#end
	}

	public function resume()
	{
		#if VIDEOS_ALLOWED
		if (video != null && video.bitmap != null)
			video.bitmap.resume();
		#end
	}
}
