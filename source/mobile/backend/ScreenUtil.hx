package mobile.backend;

#if android
import lime.system.JNI;

/**
 * Haxe JNI bridge to mobile.backend.java.ScreenUtil.
 * Ported from NightmareVision-Android-Support's mobile.backend.ScreenUtil.
 * Not yet wired into any UI layout -- see its own doc comments for what's
 * still needed to actually avoid notch/punch-hole overlap on screen.
 */
class ScreenUtil
{
	static var _getSafeInsetTop = JNI.createStaticMethod(
		"mobile/backend/java/ScreenUtil",
		"getSafeInsetTop",
		"()I"
	);

	static var _getSafeInsetBottom = JNI.createStaticMethod(
		"mobile/backend/java/ScreenUtil",
		"getSafeInsetBottom",
		"()I"
	);

	static var _getSafeInsetLeft = JNI.createStaticMethod(
		"mobile/backend/java/ScreenUtil",
		"getSafeInsetLeft",
		"()I"
	);

	static var _getSafeInsetRight = JNI.createStaticMethod(
		"mobile/backend/java/ScreenUtil",
		"getSafeInsetRight",
		"()I"
	);

	/**
	 * Display-cutout (notch/punch-hole) safe insets, in density-independent
	 * pixels -- how far UI needs to stay clear of each edge to avoid being
	 * covered by the cutout. Always 0 below API 28 (no cutout concept
	 * existed yet) or if the device has no cutout at all.
	 */
	public static function getSafeInsetTop():Int
	{
		try return _getSafeInsetTop()
		catch (e:Dynamic) return 0;
	}

	public static function getSafeInsetBottom():Int
	{
		try return _getSafeInsetBottom()
		catch (e:Dynamic) return 0;
	}

	public static function getSafeInsetLeft():Int
	{
		try return _getSafeInsetLeft()
		catch (e:Dynamic) return 0;
	}

	public static function getSafeInsetRight():Int
	{
		try return _getSafeInsetRight()
		catch (e:Dynamic) return 0;
	}
}
#end
