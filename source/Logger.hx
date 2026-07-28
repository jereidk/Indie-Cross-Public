package;

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import haxe.PosInfos;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;
using Logger.Ansi;

enum abstract Severity(Int) to Int
{
	var PRINT;
	var WARN;
	var ERROR;
	var NOTICE;

	public function toString():String
	{
		return switch (this)
		{
			default: '[LOG] ';
			case WARN: '[WARN] ';
			case ERROR: '[ERROR] ';
			case NOTICE: '[NOTICE] ';
		}
	}
}

/**
 * Structured trace/log helper: adds a timestamp, current state/substate name,
 * and ANSI colour coding to every line, and (see GameLogger.hx) mirrors
 * everything to a rolling game.log file on external storage.
 *
 * Ported from NightmareVision-Android-Support's funkin.backend.Logger.
 * Not ported: the crowplexus.iris ErrorSeverity conversion (Indie-Cross-
 * Public's Lua layer isn't hscript-iris, so there's no such error type to
 * convert from) and the on-screen DebugTextPlugin echo (no such plugin
 * system exists here) -- this is trace()/FlxG.log output plus the
 * persistent file, not an in-game overlay.
 */
class Logger
{
	/**
	 * Enable detailed prefix with timestamp and state info
	 */
	public static var detailedPrefix:Bool = true;

	#if sys
	/**
	 * The main/UI thread's identity, captured once via initMainThread() as
	 * early as possible. log() compares against this to decide whether
	 * touching Flixel (FlxG.state, FlxG.log) is safe -- reading/writing
	 * plain Flixel objects from a second native thread with no locking of
	 * their own is exactly the kind of concurrent mutation that corrupts
	 * memory on hxcpp instead of throwing a catchable exception.
	 */
	static var _mainThread:Null<sys.thread.Thread> = null;

	/**
	 * Must be called once, as early as possible on the real main thread.
	 * Safe to call more than once (idempotent, just re-captures Thread.current()).
	 */
	public static function initMainThread():Void
	{
		_mainThread = sys.thread.Thread.current();
	}

	static inline function isMainThread():Bool
		return _mainThread == null || sys.thread.Thread.current() == _mainThread;
	#end

	static function getTimestamp():String
	{
		var now = Date.now();
		return StringTools.lpad(Std.string(now.getHours()), "0", 2) + ":" +
			   StringTools.lpad(Std.string(now.getMinutes()), "0", 2) + ":" +
			   StringTools.lpad(Std.string(now.getSeconds()), "0", 2) + "." +
			   StringTools.lpad(Std.string(now.getFullYear() % 100), "0", 2) +
			   StringTools.lpad(Std.string(now.getMonth() + 1), "0", 2) +
			   StringTools.lpad(Std.string(now.getDate()), "0", 2);
	}

	static function getStateContext():String
	{
		var stateName = "NoState";

		if (FlxG.state != null)
		{
			stateName = Type.getClassName(Type.getClass(FlxG.state));
			var dotIdx = stateName.lastIndexOf(".");
			if (dotIdx >= 0) stateName = stateName.substring(dotIdx + 1);

			if (Std.isOfType(FlxG.state, flixel.FlxSubState))
				stateName = "SubState>" + stateName;
		}

		return stateName;
	}

	/**
	 * Primary `trace` function with enhanced prefix.
	 * @param data The value to trace
	 * @param severity provides ansi colour coding to better highlight specific messages
	 * @param pos Haxe position info (file:line:column)
	 */
	public static function log(data:Dynamic, severity:Severity = PRINT, ?pos:PosInfos)
	{
		final onMainThread = #if sys isMainThread() #else true #end;

		#if FLX_DEBUG
		if (onMainThread)
		{
			switch (severity)
			{
				case ERROR:
					FlxG.log.error(data, pos);
				case WARN:
					FlxG.log.warn(data, pos);
				case NOTICE:
					FlxG.log.notice(data, pos);
				case PRINT:
			}
		}
		#end

		var prefix:String = "";
		if (detailedPrefix)
		{
			var timestamp = getTimestamp();
			// getStateContext() reads FlxG.state -- also main-thread-owned,
			// same reasoning as above. A background thread gets a fixed
			// label instead of touching it.
			var stateInfo = onMainThread ? getStateContext() : 'BGThread';

			prefix = '[$timestamp] [$stateInfo] ${severity.toString()}';
		}
		else
			prefix = severity.toString();

		var output:String = prefix + haxe.Log.formatOutput(data, pos);

		if (pos != null && detailedPrefix)
		{
			if (output.indexOf(pos.fileName) < 0 && output.indexOf(Std.string(pos.customParams)) < 0)
				output += ' @ ${pos.fileName}:${pos.lineNumber}';
		}

		output = output.fg(getAnsiColourFromSeverity(severity)).reset();

		#if !FORCED_ANSI
		output = output.stripColor();
		#end

		#if sys
		Sys.println(output);
		GameLogger.write(output);
		#else
		trace(output);
		#end
	}

	static function getAnsiColourFromSeverity(severity:Severity)
	{
		return switch (severity)
		{
			case ERROR: AnsiColor.RED;
			case WARN: AnsiColor.YELLOW;
			case NOTICE: AnsiColor.GREEN;
			default: AnsiColor.WHITE;
		}
	}

	public static function getHexColourFromSeverity(severity:Severity)
	{
		return switch (severity)
		{
			case ERROR: FlxColor.RED;
			case WARN: FlxColor.YELLOW;
			case NOTICE: FlxColor.LIME;
			default: FlxColor.WHITE;
		}
	}

	public static function writeDump(content:String, folder:String, fileName:String)
	{
		#if sys
		if (!FileSystem.exists(folder) && !FileSystem.isDirectory(folder))
			FileSystem.createDirectory(folder);

		final dumpPath = '$folder/$fileName' + '_' + Paths.sanitize(Date.now().toString()).replace(':', '_') + '.txt';

		try
			File.saveContent(dumpPath, content)
		catch (e) {}
		#end
	}
}

// Ported from crowplexus's hscript-iris Ansi.hx (see NightmareVision-Android-Support's
// own Logger.hx for the original attribution), self-contained, no external deps.

enum abstract AnsiColor(Int)
{
	final BLACK = 0;
	final RED = 1;
	final GREEN = 2;
	final YELLOW = 3;
	final BLUE = 4;
	final MAGENTA = 5;
	final CYAN = 6;
	final WHITE = 7;
	final DEFAULT = 9;
	final ORANGE = 216;
	final DARK_ORANGE = 215;
	final ORANGE_BRIGHT = 208;
}

class Ansi
{
	public static inline final ESC = "\x1B[";

	inline public static function reset(str:String):String return str + ESC + "0m";

	inline public static function fg(str:String, color:AnsiColor):String return ESC + "38;5;" + color + "m" + str;

	private static var colorSupported:Null<Bool> = null;

	public static function stripColor(output:String):String
	{
		#if sys
		if (colorSupported == null)
		{
			var term = Sys.getEnv("TERM");

			if (term == "dumb")
				colorSupported = false;
			else
			{
				if (colorSupported != true && term != null)
					colorSupported = ~/(?i)-256(color)?$/.match(term)
						|| ~/(?i)^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/.match(term);

				if (colorSupported != true)
					colorSupported = Sys.getEnv("TERM_PROGRAM") == "iTerm.app"
						|| Sys.getEnv("TERM_PROGRAM") == "Apple_Terminal"
						|| Sys.getEnv("COLORTERM") != null
						|| Sys.getEnv("ANSICON") != null
						|| Sys.getEnv("ConEmuANSI") != null
						|| Sys.getEnv("WT_SESSION") != null;
			}
		}

		if (colorSupported)
			return output;
		#end
		return ~/\x1b\[[^m]*m/g.replace(output, "");
	}
}
