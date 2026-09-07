package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.typeLimit.NextState;
import sys.thread.Thread;

using StringTools;

class LoadingState extends MusicBeatState
{
	public static var target:NextState;
	public static var stopMusic = false;

	static var imagesToCache:Array<String> = [];
	static var soundsToCache:Array<String> = [];
	static var library:String = "";

	var screen:LoadingScreen;

	#if android
	/** Set in create(), consumed by the first update() -- see create(). */
	var pendingCache:Bool = false;
	#end

	public function new()
	{
		super();

		enableTransIn = false;
		enableTransOut = false;
	}

	override function create()
	{
		super.create();

		// Hardcoded, aaaaahhhh
		switch (PlayState.storyWeek)
		{
			case 0:
				library = "cup";

				soundsToCache = ["parry", "knockout", "death"];

				imagesToCache = [
					'knock',
					'ready_wallop',
					'bull/Roundabout',
					'bull/GreenShit',
					'bull/Cupheadshoot',
					'bull/Cuphead Hadoken',
					'mozo'
				];

				FNFState.disableNextTransIn = true;

			case 1:
				library = "sans";

				soundsToCache = ["notice", "sansattack", "dodge", "readygas", "shootgas"];

				imagesToCache = ["DodgeMechs"];

				switch (PlayState.SONG.song.toLowerCase())
				{
					case 'bad-time':
						imagesToCache = imagesToCache.concat(['Gaster_blasterss', 'DodgeMechsBS-Shader']);
				}

			case 2:
				library = "bendy";

				soundsToCache = ['inked'];

				imagesToCache = ['Damage01', 'Damage02', 'Damage03', 'Damage04'];
		}

		// Hardcoded for now
		if (PlayState.SONG.song.toLowerCase() == 'ritual')
			FNFState.disableNextTransIn = true;

		screen = new LoadingScreen();
		add(screen);

		screen.max = soundsToCache.length + imagesToCache.length;

		FlxG.camera.fade(FlxG.camera.bgColor, 0.5, true);

		FlxGraphic.defaultPersist = true;

		#if android
		// The Thread.create() path below is fine on desktop, but on Android
		// this work reaches the GPU: Paths.image() routes through
		// mobile.backend.AstcLoader, whose tryLoad() calls
		// Context3D.createASTCTexture() -- and nearly every image in assets/
		// ships ASTC-only here, no .png at all. GL calls are only valid on the
		// main thread, which is presumably why the two loops used to be
		// skipped outright on android (`#if !android` around them) rather than
		// moved.
		//
		// Skipping them doesn't avoid the work, though, it just defers it to
		// the first time each asset is actually *used* in PlayState -- caught
		// in perf.log as synchronous multi-hundred-ms frame spikes right after
		// a song started (e.g. Freaky-Machine's Damage0X hit-popups,
		// Devils-Gambit's "Cuphead Hadoken" bullet sprite -- both already
		// listed in imagesToCache above, just never actually cached on this
		// platform). So run them on the main thread instead, from update()
		// rather than from here: create() is followed by this frame's own
		// draw(), so waiting one frame means the loading screen is actually
		// on-screen before the main thread blocks, instead of the app looking
		// frozen on the previous state for the whole load.
		pendingCache = true;
		#else
		Thread.create(() ->
		{
			cacheEverything();
			finishLoading();
		});
		#end
	}

	#if android
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (pendingCache)
		{
			pendingCache = false;
			cacheEverything();
			finishLoading();
		}
	}
	#end

	function cacheEverything():Void
	{
		screen.setLoadingText("Loading sounds...");
		for (sound in soundsToCache)
		{
			trace("Caching sound " + sound);
			FlxG.sound.cache(Paths.sound(sound, library));
			screen.progress += 1;
		}

		screen.setLoadingText("Loading images...");
		for (image in imagesToCache)
		{
			trace("Caching image " + image);
			FlxG.bitmap.add(Paths.image(image, library));
			screen.progress += 1;
		}
	}

	function finishLoading():Void
	{
		FlxGraphic.defaultPersist = false;

		screen.setLoadingText("Done!");
		trace("Done caching");

		FlxG.camera.fade(FlxColor.BLACK, 1, false);
		new FlxTimer().start(1, function(_:FlxTimer)
		{
			screen.kill();
			screen.destroy();
			loadAndSwitchState(target, false);
		});
	}

	public static function loadAndSwitchState(target:NextState, stopMusic = false)
	{
		Paths.setCurrentLevel("week" + PlayState.storyWeek);

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.switchState(target);
	}
}
