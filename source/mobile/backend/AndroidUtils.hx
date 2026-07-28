package mobile.backend;

#if android
/**
 * Haxe JNI bridge to mobile.backend.java.AndroidUtils.
 * Ported (minimal subset) from NightmareVision-Android-Support's
 * mobile.backend.AndroidUtils.
 */
class AndroidUtils
{
	static var _setGameplayState = JNI.createStaticMethod(
		"mobile/backend/java/AndroidUtils",
		"setGameplayState",
		"(Z)V"
	);

	static var _getMaxRefreshRate = JNI.createStaticMethod(
		"mobile/backend/java/AndroidUtils",
		"getMaxRefreshRate",
		"()F"
	);

	static var _requestHighRefreshRate = JNI.createStaticMethod(
		"mobile/backend/java/AndroidUtils",
		"requestHighRefreshRate",
		"()V"
	);

	static var _hasPhysicalKeyboard = JNI.createStaticMethod(
		"mobile/backend/java/AndroidUtils",
		"hasPhysicalKeyboard",
		"()Z"
	);

	static var _isExternalStorageManager = JNI.createStaticMethod(
		"mobile/backend/java/AndroidUtils",
		"isExternalStorageManager",
		"()Z"
	);

	static var _requestAllFilesAccess = JNI.createStaticMethod(
		"mobile/backend/java/AndroidUtils",
		"requestAllFilesAccess",
		"()V"
	);

	/**
	 * Signals Android's GameManager what state the app is in (API 33+ only,
	 * silent no-op otherwise). true while actively playing a song, false in
	 * menus/pause/loading.
	 */
	public static inline function setGameplayState(inGameplay:Bool):Void
	{
		try _setGameplayState(inGameplay)
		catch (e:Dynamic) {}
	}

	/**
	 * The highest refresh rate (Hz) any display mode the screen supports
	 * offers. Only meaningful after requestHighRefreshRate() has been called
	 * -- see that function's own doc comment.
	 */
	public static function getMaxRefreshRate():Float
	{
		try return _getMaxRefreshRate()
		catch (e:Dynamic) return 60.0;
	}

	/**
	 * Opts the window into its highest supported display refresh rate mode.
	 * Android defaults every app to 60Hz regardless of the panel's real
	 * capability until this is requested -- call once, early at startup.
	 */
	public static function requestHighRefreshRate():Void
	{
		try _requestHighRefreshRate()
		catch (e:Dynamic) {}
	}

	/**
	 * Whether Android reports a hardware keyboard currently attached
	 * (USB/Bluetooth) -- doesn't count the on-screen soft keyboard or the
	 * game's own virtual pad. Used to block physical-key rebinding on a
	 * touch-only device, where a rebind prompt would otherwise just sit
	 * there for its full timeout with no way to complete it.
	 */
	public static function hasPhysicalKeyboard():Bool
	{
		try return _hasPhysicalKeyboard()
		catch (e:Dynamic) return false;
	}

	/**
	 * Whether the app currently holds the special "All files access"
	 * permission (API 30+; always true before that). WRITE_EXTERNAL_STORAGE/
	 * READ_EXTERNAL_STORAGE alone do NOT grant this on Android 11+ -- without
	 * it, writes to SUtil.getPath()'s folder silently fail every time.
	 */
	public static function isExternalStorageManager():Bool
	{
		try return _isExternalStorageManager()
		catch (e:Dynamic) return false;
	}

	/**
	 * Launches Android's "All files access" settings screen for this app
	 * (API 30+ no-op otherwise). Doesn't block the caller -- boot continues
	 * underneath it.
	 */
	public static function requestAllFilesAccess():Void
	{
		try _requestAllFilesAccess()
		catch (e:Dynamic) {}
	}
}
#end
