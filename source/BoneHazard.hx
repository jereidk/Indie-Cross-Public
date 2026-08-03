package;

import openfl.display.BitmapData;
import openfl.display.Shape;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.util.FlxColor;

/**
 * A simple sliding "bone" hazard for Sans's UT-mode battle box -- an
 * original vector shape (drawn with Shape, same approach as
 * android/flixel/SimpleJoystick.hx's ring/thumb), not a copy of any
 * Undertale art. Spans the full width of the battle box and slides across
 * it at a fixed height; the ball has to move to a different height before
 * it arrives.
 */
class BoneHazard extends FlxSprite
{
	static var cachedGraphic:FlxGraphic;

	static inline var LENGTH:Float = 1600;
	static inline var THICKNESS:Float = 34;

	var target:FlxSprite;
	var boundaryLeft:Float;
	var boundaryRight:Float;
	var onHit:Void->Void;
	var hasHit:Bool = false;

	/**
	 * @param y World Y the bone travels at (its own vertical center).
	 * @param fromLeft True to enter from the left edge and travel right,
	 *        false for the opposite.
	 * @param speed Horizontal travel speed in px/s.
	 * @param boundaries The battle box (battleBoundaries) it's meant to
	 *        cross -- despawns once well clear of it on the far side.
	 * @param target The sprite (the soul/ball) it can hit.
	 * @param onHit Called at most once per bone, the first frame it
	 *        overlaps `target`.
	 */
	public function new(y:Float, fromLeft:Bool, speed:Float, boundaries:FlxRect, target:FlxSprite, onHit:Void->Void)
	{
		var startX:Float = fromLeft ? (boundaries.x - LENGTH) : (boundaries.x + boundaries.width);

		super(startX, y - THICKNESS / 2);

		this.target = target;
		this.boundaryLeft = boundaries.x - LENGTH * 2;
		this.boundaryRight = boundaries.x + boundaries.width + LENGTH * 2;
		this.onHit = onHit;

		if (cachedGraphic == null)
			cachedGraphic = FlxGraphic.fromBitmapData(createBoneGraphic(), false, 'boneHazardGraphic');
		loadGraphic(cachedGraphic);

		velocity.x = fromLeft ? speed : -speed;
		antialiasing = FlxG.save.data.highquality;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!hasHit && target != null && overlaps(target))
		{
			hasHit = true;
			if (onHit != null)
				onHit();
		}

		if (x < boundaryLeft || x > boundaryRight)
			kill();
	}

	static function createBoneGraphic():BitmapData
	{
		var w:Int = Std.int(LENGTH);
		var knobRadius:Float = THICKNESS * 0.9;
		var h:Int = Std.int(knobRadius * 2.2);

		var shape:Shape = new Shape();
		shape.graphics.beginFill(FlxColor.WHITE, 1);
		shape.graphics.drawRoundRect(knobRadius, h / 2 - THICKNESS / 2, w - knobRadius * 2, THICKNESS, THICKNESS);
		shape.graphics.drawCircle(knobRadius, h / 2 - knobRadius * 0.45, knobRadius * 0.55);
		shape.graphics.drawCircle(knobRadius, h / 2 + knobRadius * 0.45, knobRadius * 0.55);
		shape.graphics.drawCircle(w - knobRadius, h / 2 - knobRadius * 0.45, knobRadius * 0.55);
		shape.graphics.drawCircle(w - knobRadius, h / 2 + knobRadius * 0.45, knobRadius * 0.55);
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(w, h, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}
}
