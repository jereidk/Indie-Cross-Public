package;

import Shaders.FXHandler;
// import GameJolt.GameJoltAPI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;

using StringTools;

#if (desktop || android)
import Discord.DiscordClient;
#end

/**
 * @author BrightFyre
 */
class Caching extends MusicBeatState
{
	var calledDone = false;
	var screen:LoadingScreen;
	var debug:Bool = false;

	public function new()
	{
		super();

		enableTransIn = false;
		enableTransOut = false;
	}

	override function create()
	{
		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end

		super.create();

		GameLogger.init();
		installJavaCrashHandler();
		checkPreviousCrash();

		// Probe GL for ASTC texture compression support as early as possible
		// (the GL context is guaranteed live by the time a state's create()
		// runs) and install the context-loss recovery handler before any
		// asset gets a chance to load through Paths.returnGraphic().
		#if (android && cpp)
		mobile.backend.AstcSupport.check();
		mobile.backend.AstcLoader.installContextHandler();
		#end

                FlxG.save.bind(Main.curSave, 'indiecross');
                PlayerSettings.init();
		KadeEngineData.initSave();

		screen = new LoadingScreen();
		screen.max = 9;
		add(screen);

		trace("Starting caching...");

		initSettings();
	}

	/**
	 * Installs the Java-level uncaught exception handler (catches JVM/JNI
	 * crashes that escape Haxe's own exception pipeline entirely -- see
	 * mobile.backend.java.JavaCrashHandler's doc comment). Writes to the
	 * same crash.log path GameLogger.init() (called right before this)
	 * already resolved as writable, so both Haxe- and Java-side crashes and
	 * the native-crash trace files JavaCrashHandler saves all land in one
	 * place that checkPreviousCrash() below already knows to check.
	 */
	function installJavaCrashHandler():Void
	{
		#if android
		try
		{
			var dir = GameLogger.getDir();
			if (dir.length > 0)
				mobile.backend.JavaCrashHandler.install(dir + 'crash.log');
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * Checks for a crash.log left by SUtil.uncaughtErrorHandler() (Haxe
	 * exception) or mobile.backend.java.JavaCrashHandler (JVM/JNI exception)
	 * the last time the game closed unexpectedly, ALSO checks Android's own
	 * ApplicationExitInfo record (API 30+) for a native SIGSEGV/OOM/ANR that
	 * killed the process before either handler got a chance to write
	 * anything, and shows a one-time alert with whatever was found. Checks
	 * both storage locations crash.log can be saved to (primary external
	 * storage, then the app-sandboxed fallback), since which one succeeded
	 * last session isn't known ahead of time. crash.log is deleted either
	 * way it's found, so this only ever fires once per crash.
	 */
	function checkPreviousCrash():Void
	{
		#if (android && sys)
		try
		{
			var crashLogMessage:Null<String> = null;
			var candidates = [
				SUtil.getPath() + 'crash.log',
				extension.androidtools.content.Context.getExternalFilesDir(null) + '/crash.log'
			];

			for (path in candidates)
			{
				if (sys.FileSystem.exists(path))
				{
					crashLogMessage = sys.io.File.getContent(path);
					sys.FileSystem.deleteFile(path);
					break;
				}
			}

			// Always ALSO check Android's own exit record, regardless of
			// whether crash.log existed above -- this is the only way to
			// learn about a native crash that killed the process before
			// JavaCrashHandler.install() (Caching.create(), a few lines
			// above checkPreviousCrash()) ever got a chance to run.
			var nativeInfo = mobile.backend.JavaCrashHandler.readPreviousNativeCrash();
			if (nativeInfo != null)
				nativeInfo = resolveNativeCrashTraces(nativeInfo);

			var fullMsg:Null<String> = null;
			if (crashLogMessage != null && nativeInfo != null && nativeInfo.length > 0)
				fullMsg = crashLogMessage + '\n\n=== Native crash (same or different session) ===\n\n' + nativeInfo;
			else if (nativeInfo != null && nativeInfo.length > 0)
				fullMsg = nativeInfo;
			else
				fullMsg = crashLogMessage;

			if (fullMsg == null) return;

			// Full, untruncated copy next to game.log for pulling off-device --
			// the in-game popup below is capped for readability, but a resolved
			// native backtrace (demangled C++ signatures) can easily run past
			// that cap.
			try
			{
				var dir = GameLogger.getDir();
				if (dir.length > 0)
					sys.io.File.saveContent(dir + 'last_crash_summary.log', '[' + Date.now().toString() + ']\n' + fullMsg);
			}
			catch (e:Dynamic) {}

			if (fullMsg.length > 2000)
				fullMsg = fullMsg.substr(0, 2000) + '\n[truncated...]';

			Application.current.window.alert(fullMsg, 'The game closed unexpectedly last time');
		}
		catch (e:Dynamic) {}
		#end
	}

	#if (android && sys)
	/**
	 * Extracts every "Trace saved to: <path>" entry from
	 * JavaCrashHandler.readPreviousNativeCrash()'s summary text, resolves
	 * each trace's crashing thread's unresolved frames against the bundled
	 * per-ABI symbol table (see TombstoneParser/SymbolResolver's own doc
	 * comments), and appends a human-readable resolved backtrace right
	 * after each matching line -- the popup and last_crash_summary.log then
	 * show function name (and file:line, when available) directly.
	 *
	 * Best-effort throughout: any failure for a given trace (missing symbol
	 * table for this build -- see SymbolResolver's doc comment on Phase 3
	 * not being wired up yet, corrupt/foreign trace, nothing to resolve)
	 * just skips that one trace -- the original summary text is never
	 * altered or removed, only ever appended to.
	 */
	static function resolveNativeCrashTraces(info:String):String
	{
		final marker = 'Trace saved to: ';
		final lines = info.split('\n');
		final out:Array<String> = [];

		for (line in lines)
		{
			out.push(line);

			final idx = line.indexOf(marker);
			if (idx < 0) continue;

			final tracePath = line.substr(idx + marker.length);
			if (tracePath.length == 0) continue;

			try
			{
				final resolved = resolveOneTrace(tracePath);
				if (resolved != null) out.push(resolved);
			}
			catch (e:Dynamic) {}
		}

		return out.join('\n');
	}

	static function resolveOneTrace(tracePath:String):Null<String>
	{
		final threadInfo = mobile.backend.TombstoneParser.parse(tracePath);
		if (threadInfo == null) return null;

		// The bundled symbol table only ever matches the CURRENTLY installed
		// build's own .so -- if the app was updated between the crash and
		// this launch, the trace's addresses belong to a DIFFERENT binary
		// than what's now bundled, and resolving against it would silently
		// produce a confidently WRONG function name instead of no answer at
		// all. The trace's own header always stamps the versionCode it came
		// from (see JavaCrashHandler.java's buildCurrentBuildInfo()), so
		// bail out on any mismatch.
		final traceVersionCode = mobile.backend.TombstoneParser.readHeaderField(tracePath, 'versionCode');
		final currentVersionCode = lime.app.Application.current.meta.get('build');
		if (traceVersionCode != null && currentVersionCode != null && traceVersionCode != currentVersionCode)
			return null;

		final abi = mobile.backend.TombstoneParser.readHeaderField(tracePath, 'abi');

		// Gather every unresolved frame's address first so the whole trace
		// only costs ONE pass over the (tens-of-MB) symbol file.
		final targets:Array<Int> = [];
		for (frame in threadInfo.frames)
		{
			if (frame.funcName != '') continue; // already resolved by the OS's own unwinder
			if (frame.fileName.indexOf('base.apk') < 0) continue; // not our own code
			targets.push(frame.relPc);
		}
		if (targets.length == 0) return null;

		final resolved = mobile.backend.SymbolResolver.resolveBatch(targets, abi);

		final resolvedLines:Array<String> = [];
		for (frame in threadInfo.frames)
		{
			if (frame.funcName != '') continue;
			if (frame.fileName.indexOf('base.apk') < 0) continue;

			final r = resolved.get(frame.relPc);
			if (r == null) continue;

			var line = '    0x' + StringTools.hex(frame.relPc) + ': ' + r.funcName;
			if (r.file != null && r.line != null) line += ' (' + r.file + ':' + r.line + ')';
			resolvedLines.push(line);
		}

		if (resolvedLines.length == 0) return null;

		return '  Crashed thread: ${threadInfo.name} (tid=${threadInfo.tid})\n  Resolved backtrace:\n' + resolvedLines.join('\n');
	}
	#end

	function initSettings()
	{
		#if debug
		debug = true;
		#end

		// DiscordClient.hx itself branches internally (#if desktop / #elseif
		// android / #else) -- was gated #if desktop here only, which meant
		// the Android Kizzy-based branch (added this session) was never
		// actually reached from anywhere reachable on a real device.
		#if (desktop || android)
		DiscordClient.initialize();
		#end

		Highscore.load();
		PlayerSettings.player1.controls.loadKeyBinds();
		KeyBinds.keyCheck();

		FXHandler.UpdateColors();

		// Android defaults every window to 60Hz regardless of the panel's
		// real capability until the app explicitly opts into a faster
		// supported mode -- for a rhythm game that caps visual smoothness
		// (and the perceived precision of hitting notes) on every 90/120Hz-
		// capable device for no reason. Doesn't persist itself, so it needs
		// requesting again on every launch, not just the first one.
		#if android
		mobile.backend.AndroidUtils.requestHighRefreshRate();
		mobile.backend.AndroidUtils.setGameplayState(false);
		#end

		// Backs the "Screen Mode" option (Options -> Window) -- Normal/Wide/
		// Stretch. resetSize() on preStateSwitch clears the notch-position
		// cache and any forced width/height override on every full state
		// switch, matching how every other per-state layout value gets
		// recomputed fresh instead of carrying stale geometry across states.
		FlxG.scaleMode = new FunkinRatioScaleMode();
		FlxG.signals.preStateSwitch.add((cast FlxG.scaleMode : FunkinRatioScaleMode).resetSize);

		Application.current.onExit.add(function(exitCode)
		{
			FlxG.save.flush();
			#if (desktop || android)
			DiscordClient.shutdown();
			#end
			Sys.exit(0);
		});

		FlxG.sound.muteKeys = null;
		FlxG.sound.volumeUpKeys = null;
		FlxG.sound.volumeDownKeys = null;
		FlxG.sound.volume = 1;
		FlxG.sound.muted = false;
		FlxG.fixedTimestep = false;
		FlxG.console.autoPause = false;
		FlxG.autoPause = FlxG.save.data.focusfreeze;

		switch (FlxG.save.data.resolution)
		{
			case 0:
				FlxG.resizeWindow(640, 360);
				FlxG.resizeGame(640, 360);
			case 1:
				FlxG.resizeWindow(768, 432);
				FlxG.resizeGame(768, 432);
			case 2:
				FlxG.resizeWindow(896, 504);
				FlxG.resizeGame(896, 504);
			case 3:
				FlxG.resizeWindow(640, 360);
				FlxG.resizeGame(640, 360);
			case 4:
				FlxG.resizeWindow(1152, 648);
				FlxG.resizeGame(1152, 648);
			case 5:
				FlxG.resizeWindow(1280, 720);
				FlxG.resizeGame(1280, 720);
			case 6:
				FlxG.resizeWindow(1920, 1080);
				FlxG.resizeGame(1920, 1080);
			case 7:
				FlxG.resizeWindow(2560, 1440);
				FlxG.resizeGame(2560, 1440);
			case 8:
				FlxG.resizeWindow(3840, 2160);
				FlxG.resizeGame(3840, 2160);
		}

		// GameJoltAPI.connect();
		// GameJoltAPI.authDaUser(FlxG.save.data.gjUser, FlxG.save.data.gjToken);

		FlxG.worldBounds.set(0, 0);

		FlxG.save.data.optimize = false;

		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			screen.setLoadingText("Done!");
			end();
		});
	}

	function end()
	{
		FlxG.camera.fade(FlxColor.BLACK, 1, false);

		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			FlxG.switchState(() -> new TitleState());
		});
	}
}
