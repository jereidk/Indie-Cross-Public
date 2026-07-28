package;

#if android
import extension.androidtools.Permissions;
import extension.androidtools.os.Build.VERSION;
import extension.androidtools.os.Build.VERSION_CODES;
import extension.androidtools.os.Environment;
import extension.androidtools.widget.Toast;
#end
import flash.system.System;
import flixel.FlxG;
import haxe.CallStack.StackItem;
import haxe.CallStack;
import haxe.io.Path;
import lime.app.Application;
import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
import openfl.utils.Assets;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * ...
 * @author: Saw (M.A. Jigsaw)
 */
class SUtil
{
	static final videoFiles:Array<String> = [
		"credits",
		"gose",
		"intro",
		"bendy/1.5",
		"bendy/1",
		"bendy/2",
		"bendy/3",
		"bendy/4",
		"bendy/4ez",
		"bendy/5",
		"bendy/bgscene",
		"bendy/bgscenephotosensitive",
		"cuphead/1",
		"cuphead/2",
		"cuphead/3",
		"cuphead/4",
		"cuphead/cup",
		"cuphead/the devil",
		"sans/1",
		"sans/2",
		"sans/3",
		"sans/3b",
		"sans/4",
		"sans/4b"
	];

	/**
	 * A simple function that checks for storage permissions and game files/folders
	 */
	public static function check()
	{
		#if android
		if (VERSION.SDK_INT >= VERSION_CODES.M)
		{
			// extension-androidtools' Permissions.getGrantedPermissions() is bound to the same
			// native JNI method as requestPermissions() (wrong arity, and the native side returns
			// void, not a permission array) -- there's no working synchronous permission-check in
			// this library anymore, so just request unconditionally (a no-op dialog-wise if
			// already granted) and let the try/catch below handle an actual denial.
			Permissions.requestPermissions(['WRITE_EXTERNAL_STORAGE', 'READ_EXTERNAL_STORAGE']);

			/**
			 * Basically for now i can't force the app to stop while its requesting a android permission, so this makes the app to stop while its requesting the specific permission
			 */
			Application.current.window.alert('If you accepted the permissions you are all good!' + "\nIf you didn't then expect a crash"
				+ 'Press Ok to see what happens',
				'Permissions?');
		}
		else
		{
			Application.current.window.alert('Please grant the game storage permissions in app settings' + '\nPress Ok to close the app', 'Permissions?');
			System.exit(1);
		}

		try
		{
			if (!FileSystem.exists(SUtil.getPath()))
				FileSystem.createDirectory(SUtil.getPath());

			if (!FileSystem.exists(SUtil.getPath() + "assets"))
				FileSystem.createDirectory(SUtil.getPath() + "assets");

			if (!FileSystem.exists(SUtil.getPath() + 'assets/videos'))
				FileSystem.createDirectory(SUtil.getPath() + 'assets/videos');

			if (!FileSystem.exists(SUtil.getPath() + 'assets/videos/bendy'))
				FileSystem.createDirectory(SUtil.getPath() + 'assets/videos/bendy');

			if (!FileSystem.exists(SUtil.getPath() + 'assets/videos/cuphead'))
				FileSystem.createDirectory(SUtil.getPath() + 'assets/videos/cuphead');

			if (!FileSystem.exists(SUtil.getPath() + 'assets/videos/sans'))
				FileSystem.createDirectory(SUtil.getPath() + 'assets/videos/sans');

			for (vid in videoFiles)
				SUtil.copyContent(Paths.video(vid), SUtil.getPath() + Paths.video(vid));
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * This returns the external storage path that the game will use
	 */
	public static function getPath():String
	{
		#if android
		return Environment.getExternalStorageDirectory() + '/' + '.' + Application.current.meta.get('file') + '/';
		#else
		return '';
		#end
	}

	/**
	 * Uncaught error handler, original made by: sqirra-rng
	 */
	public static function uncaughtErrorHandler()
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, function(u:UncaughtErrorEvent)
		{
			var callStack:Array<StackItem> = CallStack.exceptionStack(true);
			var errMsg:String = '';

			for (stackItem in callStack)
			{
				switch (stackItem)
				{
					case CFunction:
						errMsg += 'a C function\n';
					case Module(m):
						errMsg += 'module ' + m + '\n';
					case FilePos(s, file, line, column):
						errMsg += file + ' (line ' + line + ')\n';
					case Method(cname, meth):
						errMsg += cname == null ? "<unknown>" : cname + '.' + meth + '\n';
					case LocalFunction(n):
						errMsg += 'local function ' + n + '\n';
				}
			}

			errMsg += u.error;

			// Extra runtime context so a saved crash log is actually useful for
			// tracking down bugs that only reproduce mid-gameplay (e.g. which
			// song/step a NullObjectReference happened on) instead of just the
			// bare stack trace above.
			errMsg += '\n\n--- Context ---\n';
			errMsg += 'Time: ' + Date.now().toString() + '\n';
			try
			{
				if (PlayState.instance != null && PlayState.SONG != null)
				{
					errMsg += 'Song: ' + PlayState.SONG.song + ' (curStep=' + PlayState.instance.curStep + ')\n';
				}
				else
				{
					errMsg += 'Song: none (not in PlayState)\n';
				}
			}
			catch (e:Dynamic) {}
			try
			{
				errMsg += 'Memory: ' + Math.round(System.totalMemory / 1024 / 1024) + ' MB\n';
			}
			catch (e:Dynamic) {}
			#if android
			try
			{
				errMsg += 'Android SDK: ' + VERSION.SDK_INT + ' (' + VERSION.RELEASE + ')\n';
			}
			catch (e:Dynamic) {}
			#end

			var logFileName:String = Application.current.meta.get('file')
				+ '-'
				+ Date.now().toString().replace(' ', '-').replace(':', "'")
				+ '.log';
			var saved:Bool = false;
			var savedBaseDir:String = null;

			try
			{
				if (!FileSystem.exists(SUtil.getPath() + 'logs'))
					FileSystem.createDirectory(SUtil.getPath() + 'logs');

				File.saveContent(SUtil.getPath() + 'logs/' + logFileName, errMsg + '\n');
				saved = true;
				savedBaseDir = SUtil.getPath();
			}
			catch (e:Dynamic) {}

			// SUtil.getPath() lives under Environment.getExternalStorageDirectory(),
			// which Android 10/11+ scoped storage blocks writes to unless the app
			// has the special "All files access" permission -- WRITE_EXTERNAL_STORAGE
			// alone doesn't grant that on modern Android, so the save above silently
			// fails there. Context.getExternalFilesDir() is the app's own sandboxed
			// external directory: always writable, no extra permission needed, on
			// every Android version -- fall back to it so a crash log survives even
			// when the primary path is blocked.
			#if android
			if (!saved)
			{
				try
				{
					var fallbackDir:String = extension.androidtools.content.Context.getExternalFilesDir(null) + '/';
					if (!FileSystem.exists(fallbackDir + 'logs'))
						FileSystem.createDirectory(fallbackDir + 'logs');

					File.saveContent(fallbackDir + 'logs/' + logFileName, errMsg + '\n');
					saved = true;
					savedBaseDir = fallbackDir;
				}
				catch (e:Dynamic) {}
			}

			if (!saved)
				Toast.makeText("Error!\nClouldn't save the crash dump because:\nboth the primary and fallback storage paths failed", Toast.LENGTH_LONG);
			else
			{
				// Fixed, predictable path (not timestamped like the "logs/"
				// dump above) -- Caching.hx checks for this on the NEXT
				// launch to show "the game closed unexpectedly last time"
				// and consumes (deletes) it so it's only ever reported once.
				try
					File.saveContent(savedBaseDir + 'crash.log', errMsg)
				catch (e:Dynamic) {}
			}
			#end

			Sys.println(errMsg);
			Application.current.window.alert(errMsg, 'Error!');

			System.exit(1);
		});
	}

	public static function saveContent(fileName:String = 'file', fileExtension:String = '.json',
			fileData:String = 'you forgot to add something in your code lol')
	{
		try
		{
			if (!FileSystem.exists(SUtil.getPath() + 'saves'))
				FileSystem.createDirectory(SUtil.getPath() + 'saves');

			File.saveContent(SUtil.getPath() + 'saves/' + fileName + fileExtension, fileData);
			Toast.makeText("File Saved Successfully!", Toast.LENGTH_LONG);
		}
		#if android
		catch (e:Dynamic)
		Toast.makeText("Error!\nClouldn't save the file because:\n" + e, Toast.LENGTH_LONG);
		#end
	}

	public static function copyContent(copyPath:String, savePath:String)
	{
		try
		{
			if (!FileSystem.exists(savePath) && Assets.exists(copyPath))
				File.saveBytes(savePath, Assets.getBytes(copyPath));
		}
		#if android
		catch (e:Dynamic)
		Toast.makeText("Error!\nClouldn't copy the file because:\n" + e, Toast.LENGTH_LONG);
		#end
	}
}
