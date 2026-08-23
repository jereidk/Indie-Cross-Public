package;

import GameJolt.GJToastManager;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.CallStack;
import haxe.io.Path;
import lime.app.Application;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.system.System;
import openfl.utils.Assets;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

class Main extends Sprite
{
	var memoryMonitor:MemoryMonitor = new MemoryMonitor(10, 3, 0xffffff);
	var fpsCounter:FPSMonitor = new FPSMonitor(10, 3, 0xFFFFFF);

	// Indie cross vars
	public static var dataJump:Int = 8; // The j
	public static var menuOption:Int = 0;
	public static var unloadDelay:Float = 0.5;
	public static var appTitle:String = 'Indie Cross';
	public static var menuMusic:String = 'freakyMenu';
	public static var menubpm:Float = 117;
	public static var curSave:String = 'save';
	public static var logAsked:Bool = false;
	public static var focusMusicTween:FlxTween;
	public static var hiddenSongs:Array<String> = ['gose', 'gose-classic', 'saness'];
	public static var gjToastManager:GJToastManager;
	public static var transitionDuration:Float = 0.5;

	public function new()
	{
		super();

		// As early as possible, before FlxGame or any background thread
		// (LoadingState's preload work, etc.) exists -- Logger.log() compares
		// against this to decide whether touching FlxG.state/FlxG.log from a
		// given call is safe.
		#if sys
		Logger.initMainThread();
		#end

		// Some hxcpp-level critical errors (certain stack/heap corruption
		// classes, among others) never reach UncaughtErrorEvent at all --
		// this hook converts one into a normal Haxe throw, which DOES reach
		// it, so it goes through the same crash-log/recovery path below
		// instead of just silently killing the process. Cheap and strictly
		// additive: it only ever fires for errors that would otherwise be
		// invisible to both crash handlers entirely.
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(function(message:String):Void
		{
			throw Std.string(message);
		});
		#end

		#if !android
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#else
		SUtil.uncaughtErrorHandler();
		#end

		SUtil.check();

		// 1280x720 explicitly, NOT 0x0. Flixel's docs say 0 means "use the
		// Project.xml size", but FlxGame actually does
		// `if (gameWidth == 0) gameWidth = FlxG.stage.stageWidth`, and on
		// mobile <window if="mobile" fullscreen="true"> makes the stage the
		// DEVICE resolution rather than the 1280x720 declared for the window.
		//
		// That value becomes FlxG.initialWidth/Height, which is exactly what
		// FunkinRatioScaleMode reads as its design resolution -- so on a phone
		// the "design" aspect ratio silently became the phone's own aspect
		// ratio, and Screen Mode's "Normal" (fit to 16:9, black bars) had
		// nothing to letterbox against: it computed the device's ratio, fit to
		// it, and came out identical to "Wide". Hence Normal/Stretch/Wide all
		// looking the same on Android while working fine on desktop, where the
		// stage really is 1280x720.
		//
		// ScreenAnchor already hardcodes 1280x720 as the design canvas, so
		// this also makes FlxG.initialWidth agree with the rest of the code
		// instead of only agreeing on desktop.
		addChild(new FlxGame(1280, 720, Caching, 60, 60, true, false));
		gjToastManager = new GJToastManager();
		addChild(memoryMonitor);
		addChild(fpsCounter);
		addChild(gjToastManager);

		#if debug
		// debugging shit
		FlxG.console.registerObject("Paths", Paths);
		FlxG.console.registerObject("Conductor", Conductor);
		FlxG.console.registerObject("PlayState", PlayState);
		FlxG.console.registerObject("Note", Note);
		FlxG.console.registerObject("PlayStateChangeables", PlayStateChangeables);
		FlxG.console.registerObject("MainMenuState", MainMenuState);
		#end

		Application.current.window.onFocusOut.add(onWindowFocusOut);
		Application.current.window.onFocusIn.add(onWindowFocusIn);
	}

	var oldVol:Float = 1.0;
	var newVol:Float = 0.3;

	public static var focused:Bool = true;

	// thx for ur code ari
	function onWindowFocusOut()
	{
		focused = false;

		// Lower global volume when unfocused
		if (Type.getClass(FlxG.state) != PlayState) // imagine stealing my code smh
		{
			oldVol = FlxG.sound.volume;
			if (oldVol > 0.3)
			{
				newVol = 0.3;
			}
			else
			{
				if (oldVol > 0.1)
				{
					newVol = 0.1;
				}
				else
				{
					newVol = 0;
				}
			}

			trace("Game unfocused");

			if (focusMusicTween != null)
				focusMusicTween.cancel();
			focusMusicTween = FlxTween.tween(FlxG.sound, {volume: newVol}, 0.5);

			// Conserve power by lowering draw framerate when unfocuced
			FlxG.drawFramerate = 60;
		}
	}

	function onWindowFocusIn()
	{
		new FlxTimer().start(0.2, function(tmr:FlxTimer)
		{
			focused = true;
		});

		// Lower global volume when unfocused
		if (Type.getClass(FlxG.state) != PlayState)
		{
			trace("Game focused");

			// Normal global volume when focused
			if (focusMusicTween != null)
				focusMusicTween.cancel();

			focusMusicTween = FlxTween.tween(FlxG.sound, {volume: oldVol}, 0.5);

			// Bring framerate back when focused
			FlxG.drawFramerate = 60;
		}
	}

	public function toggleFPS(fpsEnabled:Bool):Void
	{
		fpsCounter.visible = fpsEnabled;
	}

	public function toggleMemCounter(enabled:Bool):Void
	{
		memoryMonitor.visible = enabled;
	}

	public function changeDisplayColor(color:FlxColor)
	{
		fpsCounter.textColor = color;
		memoryMonitor.textColor = color;
	}

	public function setDebugDisplaySize(size:Float):Void
	{
		fpsCounter.setSize(size);
		memoryMonitor.setSize(size);
	}

	public function setFPSCap(cap:Float)
	{
		Lib.current.stage.frameRate = cap;
	}

	public function getFPSCap():Float
	{
		return Lib.current.stage.frameRate;
	}

	public function getFPS():Float
	{
		return fpsCounter.currentFPS;
	}

	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = StringTools.replace(dateNow, " ", "_");
		dateNow = StringTools.replace(dateNow, ":", "'");

		path = "./crash/" + "IndieCross_" + dateNow + ".txt";

		errMsg = "Version: " + Lib.application.meta["version"] + "\n";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nReport the error here: https://discord.gg/cZydhxFYpp";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		var crashDialoguePath:String = "FlixelCrashHandler";

		#if windows
		crashDialoguePath += ".exe";
		#end

		if (FileSystem.exists("./" + crashDialoguePath))
		{
			Sys.println("Found crash dialog: " + crashDialoguePath);

			#if linux
			crashDialoguePath = "./" + crashDialoguePath;
			#end
			new Process(crashDialoguePath, [path]);
		}
		else
		{
			Sys.println("No crash dialog found! Making a simple alert instead...");
			Application.current.window.alert(errMsg, "Error!");
		}

		Sys.exit(1);
	}
}
