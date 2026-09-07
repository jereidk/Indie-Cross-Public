package;

import flixel.FlxG;
import flixel.system.scaleModes.RatioScaleMode;
import flixel.math.FlxPoint;
import openfl.display.StageScaleMode;

#if mobile
import mobile.backend.ScreenUtil;
#end

/**
 * Custom scale mode backing the "Screen Mode" option (Options -> Window).
 * Ported from NightmareVision-Android-Support's funkin.backend.FunkinRatioScaleMode,
 * adapted to this codebase's flat package layout and FlxG.save.data-based
 * settings (no ClientPrefs class here) -- FlxG.save.data.screenMode is an
 * Int (0=Normal/fit, 1=Wide/expand, 2=Stretch) instead of their String.
 */
class FunkinRatioScaleMode extends RatioScaleMode
{
	@:isVar public var width(get, set):Null<Int> = null;
	@:isVar public var height(get, set):Null<Int> = null;

	#if mobile
	/**
	 * Notch/cutout position and size in device pixels.
	 */
	public static var notchPosition:FlxPoint = FlxPoint.get(0, 0);
	public static var notchSize:FlxPoint = FlxPoint.get(0, 0);
	#end

	/**
	 * The maximum aspect ratio to allow before adding black bars.
	 * Default: 21:9 (2.33) for ultra-wide screens.
	 */
	public static var maxAspectRatio:Float = 21.0 / 9.0;

	/**
	 * How much extra logical width/height 'Wide' mode revealed beyond the
	 * design resolution (FlxG.initialWidth × FlxG.initialHeight), in game
	 * coordinates. Zero in 'Normal'/'Stretch' mode, or on a screen that
	 * isn't wider/taller than 16:9. UI that wants to deliberately use the
	 * extra space (instead of just staying centered on the original
	 * 1280x720, the default behaviour) can read this.
	 */
	public static var gameCutoutSize:FlxPoint = FlxPoint.get(0, 0);

	public override function updateGameSize(Width:Int, Height:Int):Void
	{
		// `width`/`height` (the get/set-wrapped properties on this class) are a
		// separate "force a custom resolution" override (see resetSize()) that
		// nothing currently sets to a non-null value, so these getters always
		// resolve to FlxG.initialWidth/Height -- the stable, never-mutated design
		// resolution. Reading them (rather than the live FlxG.width/height,
		// which 'Wide' mode is about to change) keeps this ratio calculation
		// correct even if updateGameSize() runs again before FlxG.width gets
		// reset back to normal (e.g. a live orientation change).
		var designWidth:Float = width;
		var designHeight:Float = height;
		var ratio:Float = designWidth / designHeight;
		var realRatio:Float = Width / Height;

		// Check if screen is wider than max aspect ratio
		var isUltraWide:Bool = realRatio > maxAspectRatio;

		// screenMode: 0 = Normal (fit, keeps 16:9 with black bars),
		// 1 = Wide (expand), 2 = Stretch (fills exactly, may distort).
		var doStretch:Bool = false;
		var doExpand:Bool = false;
		#if mobile
		if (FlxG.save.data.screenMode == 2 && !isUltraWide)
			doStretch = true;
		else if (FlxG.save.data.screenMode == 1)
			doExpand = true;
		#end

		var scaleY:Bool = realRatio < ratio;
		if (fillScreen || doStretch)
		{
			scaleY = !scaleY;
		}

		// On mobile, adjust for notch/cutout
		#if mobile
		var notch = ScreenUtil.safeArea();
		var safeTop:Float = notch.top;
		var safeLeft:Float = notch.left;
		var safeRight:Float = notch.right;

		// Update notch info for mobile UI elements
		if (safeTop > 0 || safeLeft > 0)
		{
			notchPosition.set(safeLeft, safeTop);
			notchSize.set(safeLeft + safeRight, safeTop);
		}
		else
		{
			notchPosition.set(0, 0);
			notchSize.set(0, 0);
		}
		#end

		var finalWidth:Int = Std.int(designWidth);
		var finalHeight:Int = Std.int(designHeight);

		if (doExpand)
		{
			// Grow the actual logical resolution (FlxG.width/height), not just
			// the render target, so a wider/taller-than-16:9 screen reveals more
			// of the game world at a UNIFORM scale -- as opposed to letting
			// scale.x/scale.y diverge, which would silently stretch every
			// sprite non-uniformly (circles into ovals) on any screen wider
			// than 16:9.
			final clampedRatio:Float = Math.min(realRatio, maxAspectRatio);

			if (realRatio > ratio)
			{
				// Wider than 16:9 (the common case: landscape phones/tablets):
				// keep height at the design value, grow width to match.
				finalHeight = Std.int(designHeight);
				finalWidth = Math.ceil(designHeight * clampedRatio);

				// If the screen is wider than maxAspectRatio, finalWidth is
				// clamped and no longer matches the raw device width -- scale
				// gameSize.x by the SAME factor as gameSize.y (Height/finalHeight)
				// so scale.x == scale.y stays true (updateScaleOffset() below
				// divides gameSize by FlxG.width/height). Otherwise this reduces
				// to gameSize.x == Width exactly, same as the unclamped case.
				final deviceScale:Float = Height / finalHeight;
				gameSize.x = finalWidth * deviceScale;
				gameSize.y = Height;
			}
			else
			{
				// Narrower/taller than 16:9 (unusual for a landscape-locked game,
				// but handled symmetrically): keep width, grow height instead.
				final clampedInvRatio:Float = Math.min(1 / realRatio, maxAspectRatio);
				finalWidth = Std.int(designWidth);
				finalHeight = Math.ceil(designWidth * clampedInvRatio);

				final deviceScale:Float = Width / finalWidth;
				gameSize.y = finalHeight * deviceScale;
				gameSize.x = Width;
			}

			gameCutoutSize.set(finalWidth - designWidth, finalHeight - designHeight);
		}
		else
		{
			gameCutoutSize.set(0, 0);

			if (scaleY)
			{
				gameSize.x = Width;
				gameSize.y = Math.floor(gameSize.x / ratio);
			}
			else
			{
				gameSize.y = Height;
				gameSize.x = Math.floor(gameSize.y * ratio);
			}

			// Stretch: fill both dimensions exactly, ignoring `ratio` entirely --
			// a deliberate non-uniform stretch (sprites can distort), not
			// another aspect-preserving fit variant. The scaleY branches above
			// (shared with plain 'fit') always kept gameSize's OTHER axis at
			// design_size * ratio, which on a screen wider (or taller) than
			// 16:9 made gameSize bigger than the real device size in that other
			// axis -- the base RatioScaleMode then scaled that oversized render
			// target down uniformly to actually fit the screen, which visually
			// *cropped/zoomed in* instead of stretching to fill, despite this
			// mode's own description already promising "fills screen (may
			// distort)". Overwrite whatever the branches above computed.
			if (doStretch)
			{
				gameSize.x = Width;
				gameSize.y = Height;
			}
		}

		@:privateAccess
		{
			for (c in FlxG.cameras.list)
			{
				if (c.width == FlxG.width && c.height == FlxG.height)
				{
					c.width = finalWidth;
					c.height = finalHeight;
				}
			}

			FlxG.width = finalWidth;
			FlxG.height = finalHeight;
		}
	}

	/**
	 * "Render Scale" (Options -> Performance). Shrinks the actual GPU
	 * backbuffer instead of just how big the game LOOKS -- everything below
	 * this class already reacts to `stage.stageWidth`/`stageHeight`
	 * changing (FlxGame.onResize reads them straight off FlxG.stage, feeds
	 * them into updateGameSize() above, and every FlxCamera recomputes its
	 * own totalScaleX/Y from FlxG.scaleMode.scale right after), so the only
	 * missing piece is making `stage.stageWidth`/`stageHeight` actually BE
	 * smaller than the device's real pixel size instead of always matching
	 * it 1:1.
	 *
	 * That's `Stage.__logicalWidth`/`__logicalHeight` (OpenFL's old Flash-
	 * style `Stage.scaleMode` machinery, confirmed by reading FunkinCrew's
	 * openfl fork at the exact commit this project pins in .hxpkg): normally
	 * 0 here (nothing else in this codebase ever touches them), which routes
	 * `Stage.__resize()` straight to `stageWidth = windowWidth` -- the raw
	 * device size -- and THAT is what `context3D.configureBackBuffer()`
	 * allocates the GPU's actual render target at (Stage.hx:1382-1384,
	 * 3721-3723). Giving `__logicalWidth`/`__logicalHeight` a real value
	 * takes the other branch instead: `stageWidth = __logicalWidth`, so the
	 * backbuffer -- and therefore every sprite/note/shader's real per-pixel
	 * GPU cost -- shrinks with it, while `stage.scaleMode = EXACT_FIT` makes
	 * OpenFL upscale that smaller backbuffer back up to fill the real
	 * screen when presenting (one cheap GPU blit, not a second letterbox
	 * pass -- width and height are scaled by the exact same factor below, so
	 * the logical canvas keeps the device's real aspect ratio and EXACT_FIT
	 * reduces to a uniform stretch; this class's own updateGameSize() above
	 * still does 100% of the actual Normal/Wide/Stretch letterbox math, now
	 * just against a proportionally smaller Width/Height).
	 *
	 * `__setLogicalSize` is `@:noCompletion private` -- no public OpenFL API
	 * exposes this Flash-era mechanism directly -- but this file already
	 * reaches into Flixel/OpenFL internals the same way a few lines down
	 * (the `@:privateAccess` block in updateGameSize() above), so this
	 * follows the same established pattern rather than vendoring a patched
	 * copy of Stage.hx just for one call.
	 *
	 * Reads the device's TRUE physical size from `FlxG.stage.window` (Lime's
	 * own Window, `width`/`height`/`scale`) rather than `FlxG.stage.
	 * stageWidth`/`stageHeight` -- once this function has run once, THOSE
	 * already reflect whatever smaller logical size the last call picked,
	 * so reading them back here would compound the scale on every call
	 * instead of always computing fresh from the real screen.
	 */
	public static function applyRenderScale(scale:Float):Void
	{
		var window = FlxG.stage.window;
		var nativeWidth:Int = Std.int(window.width * window.scale);
		var nativeHeight:Int = Std.int(window.height * window.scale);

		FlxG.stage.scaleMode = StageScaleMode.EXACT_FIT;

		@:privateAccess
		FlxG.stage.__setLogicalSize(Std.int(nativeWidth * scale), Std.int(nativeHeight * scale));
	}

	public function resetSize()
	{
		width = null;
		height = null;
		#if mobile
		notchPosition.set(0, 0);
		notchSize.set(0, 0);
		#end
	}

	/**
	 * Resets the scale mode to apply preference changes immediately.
	 * Called when screenMode preference changes.
	 */
	public static function resetScaleMode():Void
	{
		if (FlxG.scaleMode != null)
		{
			var mode = cast(FlxG.scaleMode, FunkinRatioScaleMode);
			if (mode != null)
			{
				mode.width = null;
				mode.height = null;
				mode.resetSize();
				@:privateAccess
				FlxG.game.onResize(null);
			}
		}
	}

	private inline function get_width():Null<Int> return this.width == null ? FlxG.initialWidth : this.width;

	private inline function get_height():Null<Int> return this.height == null ? FlxG.initialHeight : this.height;

	private inline function set_width(v:Null<Int>):Null<Int>
	{
		this.width = v;
		@:privateAccess
		FlxG.game.onResize(null);
		return v;
	}

	private inline function set_height(v:Null<Int>):Null<Int>
	{
		this.height = v;
		@:privateAccess
		FlxG.game.onResize(null);
		return v;
	}
}
