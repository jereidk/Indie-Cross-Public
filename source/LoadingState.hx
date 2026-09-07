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

		function finishLoading()
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

		#if android
		// The Thread.create() path below is fine on desktop, but
		// FlxG.sound.cache()/FlxG.bitmap.add() ultimately decode into GPU
		// textures, and uploading those from anything but the main GL thread
		// is unsafe on Android's GLES context model -- presumably why this
		// used to be skipped outright on android (`#if !android` around the
		// two loops). Skipping it doesn't avoid the decode work, though, it
		// just defers it to the first time each asset is actually *used* in
		// PlayState -- caught in perf.log as synchronous multi-hundred-ms
		// frame spikes right after a song started (e.g. Freaky-Machine's
		// Damage0X hit-popups, Devils-Gambit's "Cuphead Hadoken" bullet
		// sprite -- both already listed in imagesToCache above, just never
		// actually cached on this platform). Doing the same loops here
		// instead, synchronously on the main thread, blocks this state
		// briefly -- but it does so behind this state's own loading
		// screen/fade, which is exactly what LoadingState is for, instead of
		// mid-gameplay.
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

		finishLoading();
		#else
		Thread.create(() ->
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

			finishLoading();
		});
		#end
	}

	public static function loadAndSwitchState(target:NextState, stopMusic = false)
	{
		Paths.setCurrentLevel("week" + PlayState.storyWeek);

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.switchState(target);
	}
}
