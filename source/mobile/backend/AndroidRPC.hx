package mobile.backend;

#if android
import lime.system.JNI;

/**
 * Haxe JNI bridge to mobile.backend.java.KizzyHelper.
 * Ported from NightmareVision-Android-Support's mobile.backend.AndroidRPC.
 *
 * Simplified from the original: doesn't resolve a per-character album-art
 * bitmap (that needed funkin.Paths/HealthIcon/StorageSystem lookups this
 * codebase has no equivalent of) -- always passes null for imagePath, so
 * KizzyHelper.java falls back to the app's own launcher icon. Character-
 * specific album art can be added later by resolving a real file path here.
 */
class AndroidRPC
{
	private static var _init:Dynamic = null;
	private static var _update:Dynamic = null;
	private static var _shutdown:Dynamic = null;

	public static function initialize()
	{
		if (_init == null)
			_init = JNI.createStaticMethod("mobile/backend/java/KizzyHelper", "initialize", "()V");

		try
			_init()
		catch (e:Dynamic)
			trace("JNI Init Error: " + e);
	}

	/**
	 * @param isPlaying `false` reports `PlaybackState.STATE_PAUSED` -- Kizzy's own
	 *   Media RPC polls this MediaSession independently of when we last called
	 *   update(), so leaving it on STATE_PLAYING would keep showing "still playing"
	 *   in Discord indefinitely after the player actually paused.
	 * @param positionMs Current elapsed playback position in milliseconds --
	 *   only meaningful (and only shown by Kizzy at all) while isPlaying.
	 * @param durationMs Total song length in milliseconds. 0 (the default)
	 *   disables Kizzy's progress bar.
	 */
	public static function update(title:String, artist:String, isPlaying:Bool = true, positionMs:Float = 0, durationMs:Float = 0)
	{
		if (_update == null)
		{
			// Java-side takes `int`, not `long` ("J") -- a song position/duration
			// in milliseconds comfortably fits an Int (max ~24 days).
			_update = JNI.createStaticMethod("mobile/backend/java/KizzyHelper", "updateStatus", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ZII)V");
		}

		try
			_update(title, artist, null, isPlaying, Std.int(positionMs), Std.int(durationMs))
		catch (e:Dynamic)
			trace("JNI Update Error: " + e);
	}

	public static function shutdown()
	{
		if (_shutdown == null)
			_shutdown = JNI.createStaticMethod("mobile/backend/java/KizzyHelper", "shutdown", "()V");

		try
			_shutdown()
		catch (e:Dynamic)
			trace("JNI Shutdown Error: " + e);
	}
}
#end
