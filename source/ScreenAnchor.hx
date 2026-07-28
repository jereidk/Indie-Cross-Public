package;

import flixel.FlxG;
import flixel.FlxSprite;

/**
 * Small helpers for keeping menu-state art correct under Screen Mode's
 * "Wide" option (FunkinRatioScaleMode), which grows the live FlxG.width/
 * height beyond the 1280x720 design canvas on screens wider than 16:9 --
 * without touching a single piece of art.
 *
 * Every menu background in this game was drawn/positioned to exactly cover
 * the base 1280x720 canvas (confirmed: menu/BG, story mode/BG and
 * credits/bg/Leader_BG are all still their native 1280x720 with no bleed),
 * so on a Wide-mode screen they'd otherwise leave a visible gap at the
 * revealed edge -- this reads the LIVE FlxG.width/height (already reflecting
 * whatever Screen Mode ended up auto-detected or picked) instead of hardcoding
 * a growth factor, so it needs no per-device tuning and no update when a
 * user changes Screen Mode later.
 */
class ScreenAnchor
{
	/**
	 * Scales `sprite` up further (uniformly, preserving aspect ratio) if the
	 * live canvas is bigger than the 1280x720 design resolution, then
	 * re-centers it -- a no-op on Normal/Stretch mode or any screen that
	 * isn't actually wider/taller than that base canvas (grow <= 1).
	 *
	 * Call this AFTER whatever sizing a state already does for its own
	 * background (its normal daScaling-based setGraphicSize + screenCenter),
	 * not instead of it -- this only adds the extra bit needed to keep
	 * covering a Wide-mode screen on top of that.
	 */
	public static function coverExpand(sprite:FlxSprite):Void
	{
		var growX:Float = FlxG.width / 1280;
		var growY:Float = FlxG.height / 720;
		var grow:Float = Math.max(growX, growY);
		if (grow <= 1.0)
			return;

		sprite.setGraphicSize(Math.ceil(sprite.width * grow), Math.ceil(sprite.height * grow));
		sprite.updateHitbox();
		sprite.screenCenter();
	}
}
