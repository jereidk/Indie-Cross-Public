package;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Persistent rolling log file. Android-only: writes every Logger.log() and
 * trace() call, plus every FlxG.log.error/warn/notice/add(), to game.log
 * under SUtil.getPath() (same folder crash.log and the "logs/" crash dumps
 * already live in).
 *
 * Rotation: when game.log exceeds MAX_BYTES, it is renamed to game.log.old
 * (overwriting the previous .old) and a fresh game.log is started.
 * Maximum on-disk footprint: ~4 MB (two files of MAX_BYTES each).
 *
 * Ported from NightmareVision-Android-Support's funkin.backend.GameLogger.
 * Not gated behind a dev-mode flag there -- Indie-Cross-Public has no
 * equivalent of NightmareVision's ClientPrefs.inDevMode, and the whole
 * point of a persistent log is being able to ask a reporting player to
 * pull game.log off their device without first walking them through
 * enabling a hidden setting. Always on.
 */
class GameLogger
{
	static final MAX_BYTES:Int = 2 * 1024 * 1024; // 2 MB per file

	#if android
	static var logPath:String = '';
	static var oldPath:String = '';
	static var _dir:String = '';
	#end

	/**
	 * The writable directory init() resolved (primary external storage, or
	 * the app-sandboxed fallback -- see init()'s own doc comment). Empty
	 * string if init() hasn't run yet, or on a non-Android target. Lets
	 * other Android-only pieces that need to write next to game.log/crash.log
	 * (JavaCrashHandler's install() path, the crash-notice check) reuse the
	 * same writability resolution instead of re-probing it themselves.
	 */
	public static function getDir():String
	{
		#if android
		return _dir;
		#else
		return '';
		#end
	}

	/**
	 * Must be called once, as early as possible in Caching.create().
	 * Opens (or rotates) game.log and installs the haxe.Log.trace interceptor.
	 */
	public static function init():Void
	{
		#if android
		// SUtil.getPath() lives under Environment.getExternalStorageDirectory(),
		// which Android 10/11+ scoped storage blocks writes to unless the app
		// has "All files access" -- most players never grant that. Same
		// primary-then-sandboxed-fallback dance as SUtil.uncaughtErrorHandler()'s
		// own crash-dump save, so game.log actually gets written on a normal
		// unmodified install instead of silently failing every single line.
		var dir:String = SUtil.getPath();
		if (!_dirWritable(dir))
		{
			try
				dir = extension.androidtools.content.Context.getExternalFilesDir(null) + '/';
			catch (e:Dynamic) {}
		}

		_dir = dir;
		logPath = dir + 'game.log';
		oldPath = dir + 'game.log.old';

		try
		{
			if (FileSystem.exists(logPath) && FileSystem.stat(logPath).size > MAX_BYTES)
			{
				if (FileSystem.exists(oldPath)) FileSystem.deleteFile(oldPath);
				FileSystem.rename(logPath, oldPath);
			}
		}
		catch (e:Dynamic) { Sys.println('[GameLogger] Failed to rotate log: ' + Std.string(e)); }

		_write('============================================================');
		_write('SESSION START  ' + Date.now().toString());
		_write('============================================================');

		// Chain onto whatever trace handler is already installed so we
		// capture everything without breaking any existing behaviour.
		final prev = haxe.Log.trace;
		haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos)
		{
			prev(v, pos);
			_write(stamp() + ' [TRACE] ' + haxe.Log.formatOutput(v, pos));
		};

		// FlxG.log.error/warn/notice/add() calls don't go through
		// haxe.Log.trace at all -- they call LogFrontEnd.advanced()
		// directly, which in a release build (FLX_NO_DEBUG-equivalent) is
		// stripped entirely. LogStyle.onLog is the one signal advanced()
		// fires unconditionally, so hooking the four built-in styles here
		// catches all of them without touching any of their call sites.
		final flxLogStyles = [
			flixel.system.debug.log.LogStyle.NORMAL,
			flixel.system.debug.log.LogStyle.WARNING,
			flixel.system.debug.log.LogStyle.ERROR,
			flixel.system.debug.log.LogStyle.NOTICE
		];
		for (style in flxLogStyles)
		{
			style.onLog.add(function(data:Any, ?pos:haxe.PosInfos)
			{
				final formatted = (pos != null) ? haxe.Log.formatOutput(data, pos) : Std.string(data);
				_write(stamp() + ' [FLXLOG] ' + formatted);
			});
		}
		#end
	}

	#if android
	static function _dirWritable(dir:String):Bool
	{
		try
		{
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			final probe = dir + '.write_test';
			File.saveContent(probe, '');
			FileSystem.deleteFile(probe);
			return true;
		}
		catch (e:Dynamic)
			return false;
	}
	#end

	/**
	 * Called by Logger.log() to mirror every formatted log line to the file.
	 * The `line` string already contains the [WARN]/[ERROR]/etc. prefix.
	 */
	public static function write(line:String):Void
	{
		#if android
		if (logPath.length == 0) return;
		_write(stamp() + ' ' + line);
		#end
	}

	static function stamp():String
	{
		final d = Date.now();
		return '[' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()) + ']';
	}

	static inline function pad(n:Int):String
		return StringTools.lpad(Std.string(n), '0', 2);

	static function _write(line:String):Void
	{
		#if android
		if (logPath.length == 0) return;
		try
		{
			final out = File.append(logPath, false);
			out.writeString(line + '\n');
			out.flush();
			out.close();
		}
		catch (e:Dynamic) { Sys.println('[GameLogger] Failed to write to log: ' + Std.string(e)); }
		#end
	}
}
