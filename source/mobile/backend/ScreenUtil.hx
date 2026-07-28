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

	static var _cachedSafeArea:Null<{top:Float, bottom:Float, left:Float, right:Float}> = null;

	/**
	 * Same 4 insets as getSafeInsetTop/Bottom/Left/Right, combined into one
	 * struct and rescaled from device pixels into HaxeFlixel's own logical
	 * game-coordinate space (FlxG.width/height, e.g. 1280x720) instead of the
	 * real screen's raw pixel dimensions -- what FunkinRatioScaleMode needs
	 * to keep UI clear of a notch/punch-hole. Cached after the first call;
	 * call invalidate() on orientation changes.
	 */
	public static function safeArea():{top:Float, bottom:Float, left:Float, right:Float}
	{
		if (_cachedSafeArea != null) return _cachedSafeArea;

		var top = 0.0, bottom = 0.0, left = 0.0, right = 0.0;

		try
		{
			var stageH:Float = flixel.FlxG.stage.stageHeight;
			var stageW:Float = flixel.FlxG.stage.stageWidth;
			if (stageH > 0 && stageW > 0)
			{
				var scaleH = flixel.FlxG.height / stageH;
				var scaleW = flixel.FlxG.width / stageW;
				top = getSafeInsetTop() * scaleH;
				bottom = getSafeInsetBottom() * scaleH;
				left = getSafeInsetLeft() * scaleW;
				right = getSafeInsetRight() * scaleW;
			}
		}
		catch (e:Dynamic) {}

		_cachedSafeArea = {top: top, bottom: bottom, left: left, right: right};
		return _cachedSafeArea;
	}

	/** Discard the cached safeArea() result (e.g. on orientation change). */
	public static inline function invalidate():Void
		_cachedSafeArea = null;
}
#end
