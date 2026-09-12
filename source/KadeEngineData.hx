import flixel.FlxG;
import openfl.Lib;

class KadeEngineData
{
	public static function initSave()
	{
		if (FlxG.save.data.render == null)
			FlxG.save.data.render = 0;

		if (FlxG.save.data.hitboxOpacity == null)
			FlxG.save.data.hitboxOpacity = 0.6;

		if (FlxG.save.data.gradientHitboxes == null)
			FlxG.save.data.gradientHitboxes = true;

		if (FlxG.save.data.mechsInputVariants == null)
			FlxG.save.data.mechsInputVariants = true;

		if (FlxG.save.data.gotSaveData == null)
			FlxG.save.data.gotSaveData = 0;

		if (FlxG.save.data.newInput == null)
			FlxG.save.data.newInput = true;

		if (FlxG.save.data.downscroll == null)
			FlxG.save.data.downscroll = false;

		if (FlxG.save.data.dfjk == null)
			FlxG.save.data.dfjk = false;

		if (FlxG.save.data.accuracyDisplay == null)
			FlxG.save.data.accuracyDisplay = true;

		if (FlxG.save.data.offset == null)
			FlxG.save.data.offset = 0;

		if (FlxG.save.data.songPosition == null)
			FlxG.save.data.songPosition = true;

		if (FlxG.save.data.fps == null)
			FlxG.save.data.fps = false;

		if (FlxG.save.data.memory == null)
			FlxG.save.data.memory = false;

		if (FlxG.save.data.changedHit == null)
		{
			FlxG.save.data.changedHitX = -1;
			FlxG.save.data.changedHitY = -1;
			FlxG.save.data.changedHit = false;
		}

		if (FlxG.save.data.fpsRain == null)
			FlxG.save.data.fpsRain = false;

		if (FlxG.save.data.fpsCap == null)
			FlxG.save.data.fpsCap = 60;

		// FPSMonitor/MemoryMonitor default to 24px on construction already
		// (bumped up from the original 12px, unreadably small on a phone
		// screen); this is only for the adjustable-from-Options case.
		if (FlxG.save.data.debugDisplaySize == null)
			FlxG.save.data.debugDisplaySize = 24;

		if (FlxG.save.data.npsDisplay == null)
			FlxG.save.data.npsDisplay = false;

		if (FlxG.save.data.highquality == null)
			FlxG.save.data.highquality = true;

		if (FlxG.save.data.photosensitive == null)
			FlxG.save.data.photosensitive = false;

		if (FlxG.save.data.frames == null)
			FlxG.save.data.frames = 10;

		if (FlxG.save.data.accuracyMod == null)
			FlxG.save.data.accuracyMod = 1;

		if (FlxG.save.data.ghost == null)
			FlxG.save.data.ghost = true;

		if (FlxG.save.data.resetButton == null)
			FlxG.save.data.resetButton = false;

		if (FlxG.save.data.botplay == null)
			FlxG.save.data.botplay = false;

		if (FlxG.save.data.cpuStrums == null)
			FlxG.save.data.cpuStrums = false;

		if (FlxG.save.data.strumline == null)
			FlxG.save.data.strumline = false;

		if (FlxG.save.data.customStrumLine == null)
			FlxG.save.data.customStrumLine = 0;

		if (FlxG.save.data.camzoom == null)
			FlxG.save.data.camzoom = true;

		if (FlxG.save.data.scoreScreen == null)
			FlxG.save.data.scoreScreen = true;

		if (FlxG.save.data.inputShow == null)
			FlxG.save.data.inputShow = false;

		if (FlxG.save.data.optimize == null)
			FlxG.save.data.optimize = false;

		if (FlxG.save.data.photosensitive == null)
			FlxG.save.data.photosensitive = false;

		if (FlxG.save.data.highquality == null)
			FlxG.save.data.highquality = true;

		if (FlxG.save.data.focusfreeze == null)
			FlxG.save.data.focusfreeze = false;

		if (FlxG.save.data.focuspause == null)
			FlxG.save.data.focuspause = true;

		if (FlxG.save.data.memorycache == null)
			FlxG.save.data.memorycache = true;

		if (FlxG.save.data.hitsounds == null)
			FlxG.save.data.hitsounds = false;

		if (FlxG.save.data.hudalpha == null)
			FlxG.save.data.hudalpha = 1;

		if (FlxG.save.data.cachestart == null)
			FlxG.save.data.cachestart = true;

		if (FlxG.save.data.version == null)
			FlxG.save.data.version = 0;

		if (FlxG.save.data.boneshit == null)
			FlxG.save.data.boneshit = 0;

		// screenMode: 0 = Normal (fit, 16:9 with black bars), 1 = Wide
		// (expand, reveals more background on a wider-than-16:9 screen,
		// no distortion), 2 = Stretch (fills the screen exactly, may
		// distort). Defaults to whatever the device's own real aspect
		// ratio actually supports instead of always starting at Normal --
		// most Android phones are already wider than 16:9, so Normal-by-
		// default would show black bars on a first launch for no reason
		// on the common case. Desktop/other targets just default to
		// Normal (their window is already user-resizable).
		if (FlxG.save.data.screenMode == null)
		{
			#if android
			var deviceRatio:Float = FlxG.stage.stageWidth / FlxG.stage.stageHeight;
			FlxG.save.data.screenMode = (deviceRatio > (16 / 9) + 0.01) ? 1 : 0;
			#else
			FlxG.save.data.screenMode = 0;
			#end
		}

		if (FlxG.save.data.inkshit == null)
			FlxG.save.data.inkshit = 0;

		if (FlxG.save.data.despairdeaths == null)
			FlxG.save.data.despairdeaths = 0;

		if (FlxG.save.data.laneUnderlay == null)
			FlxG.save.data.laneUnderlay = false;

		if (FlxG.save.data.showsubs == null)
			FlxG.save.data.showsubs = false;

		if (FlxG.save.data.laneTransparency == null)
			FlxG.save.data.laneTransparency = 0.5;

		if (FlxG.save.data.middleScroll == null)
			FlxG.save.data.middleScroll = false;

		if (FlxG.save.data.weeksbeat == null)
			FlxG.save.data.weeksbeat = [false, false, false];

		if (FlxG.save.data.weeksbeatonhard == null)
			FlxG.save.data.weeksbeatonhard = [false, false, false];

		if (FlxG.save.data.freeplaylocked == null)
			FlxG.save.data.freeplaylocked = [true, true, true];

		if (FlxG.save.data.huh == null)
			FlxG.save.data.huh = true;

		if (FlxG.save.data.volume == null)
			FlxG.save.data.volume = 1;

		if (FlxG.save.data.muted == null)
			FlxG.save.data.muted = false;

		if (FlxG.save.data.hasgenocided == null)
			FlxG.save.data.hasgenocided = false;

		if (FlxG.save.data.haspacifisted == null)
			FlxG.save.data.haspacifisted = false;

		if (FlxG.save.data.sanessDeathQuotes == null)
			FlxG.save.data.sanessDeathQuotes = 0;

		if (FlxG.save.data.watchedTitleVid == null)
			FlxG.save.data.watchedTitleVid = false;

		// noteLayout: 'Normal' (classic side-by-side strumline) or 'VSlice'
		// (player centered/split, opponent shrunk to a corner) -- see
		// NoteLayoutOption/NoteTapOption in Options.hx.
		if (FlxG.save.data.noteLayout == null)
			FlxG.save.data.noteLayout = 'Normal';

		// Only meaningful (and only exposed in Options) when noteLayout is
		// 'VSlice': taps the falling note sprite directly instead of the
		// usual fixed-zone Hitbox. See android.flixel.NoteTapInput.
		if (FlxG.save.data.noteTapControls == null)
			FlxG.save.data.noteTapControls = false;

		if (FlxG.save.data.secretChars == null)
			FlxG.save.data.secretChars = [true, true, true, true, true, true, true, true];

		if (FlxG.save.data.mechanicType == null)
			FlxG.save.data.mechanicType = 1;

		if (FlxG.save.data.givenCode == null)
			FlxG.save.data.givenCode = false;

		if (FlxG.save.data.showms == null)
			FlxG.save.data.showms = false;

		if (FlxG.save.data.colorblind == null)
			FlxG.save.data.colorblind = 0;

		if (FlxG.save.data.gamma == null)
			FlxG.save.data.gamma = 1;

		if (FlxG.save.data.resolution == null)
			FlxG.save.data.resolution = 5;

		if (FlxG.save.data.brightness == null)
			FlxG.save.data.brightness = 0;

		if (FlxG.save.data.seenCredits == null)
			FlxG.save.data.seenCredits = false;

		if (FlxG.save.data.achievementsIndie == null)
			Achievements.defaultAchievements();

		if (FlxG.save.data.shownalerts == null)
			FlxG.save.data.shownalerts = [false, false, false];

		FlxG.sound.volume = FlxG.save.data.volume;
		FlxG.sound.muted = FlxG.save.data.muted;

		Conductor.recalculateTimings();
		KeyBinds.keyCheck();

		FlxG.save.flush();

		(cast(Lib.current.getChildAt(0), Main)).toggleFPS(FlxG.save.data.fps);
		(cast(Lib.current.getChildAt(0), Main)).toggleMemCounter(FlxG.save.data.memory);
		(cast(Lib.current.getChildAt(0), Main)).setFPSCap(FlxG.save.data.fpsCap);
		(cast(Lib.current.getChildAt(0), Main)).setDebugDisplaySize(FlxG.save.data.debugDisplaySize);
	}
}
