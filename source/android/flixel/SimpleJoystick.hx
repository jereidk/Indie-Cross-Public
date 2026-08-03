package android.flixel;

import openfl.display.BitmapData;
import openfl.display.Shape;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;

/**
 * A minimal analog thumbstick visual for touch controls: a thin white ring
 * marking how far the thumb can travel, and a solid white ball for the
 * thumb itself. Both drawn with plain vector shapes, no sprite sheet.
 *
 * This class only draws and positions those two pieces -- it has no touch
 * handling of its own. The caller (e.g. PlayState's UT-mode movement block)
 * already has to read raw touches itself to move whatever this joystick is
 * driving, so it just writes the resulting thumb position back via
 * `thumb.x`/`thumb.y` directly instead of this class tracking the same
 * touch a second time.
 */
class SimpleJoystick extends FlxSpriteGroup
{
	public var ring:FlxSprite;
	public var thumb:FlxSprite;
	public var radius(default, null):Float;

	static inline var RING_THICKNESS:Float = 4;
	static inline var THUMB_RADIUS_RATIO:Float = 0.35;

	public function new(x:Float, y:Float, radius:Float)
	{
		super(x, y);

		this.radius = radius;
		var thumbRadius:Float = radius * THUMB_RADIUS_RATIO;

		ring = new FlxSprite(0, 0);
		ring.loadGraphic(createRingGraphic(radius));
		ring.x -= ring.width * 0.5;
		ring.y -= ring.height * 0.5;
		ring.scrollFactor.set();
		ring.solid = false;
		ring.immovable = true;
		#if FLX_DEBUG
		ring.ignoreDrawDebug = true;
		#end
		add(ring);

		thumb = new FlxSprite(0, 0);
		thumb.loadGraphic(createThumbGraphic(thumbRadius));
		thumb.x -= thumb.width * 0.5;
		thumb.y -= thumb.height * 0.5;
		thumb.scrollFactor.set();
		thumb.solid = false;
		thumb.immovable = true;
		#if FLX_DEBUG
		thumb.ignoreDrawDebug = true;
		#end
		add(thumb);

		scrollFactor.set();
		moves = false;
	}

	function createRingGraphic(radius:Float):BitmapData
	{
		var size:Int = Std.int(radius * 2);
		var shape:Shape = new Shape();
		shape.graphics.lineStyle(RING_THICKNESS, FlxColor.WHITE, 0.8);
		shape.graphics.drawCircle(radius, radius, radius - RING_THICKNESS * 0.5);

		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	function createThumbGraphic(radius:Float):BitmapData
	{
		var size:Int = Std.int(radius * 2);
		var shape:Shape = new Shape();
		shape.graphics.beginFill(FlxColor.WHITE, 0.9);
		shape.graphics.drawCircle(radius, radius, radius);
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}
}
