package android.flixel;

import openfl.display.Shape;
import openfl.display.BitmapData;
import android.flixel.FlxButton;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxSpriteGroup;

/**
 * A zone with 4 hint's (A hitbox).
 * It's really easy to customize the layout.
 *
 * @author: Saw (M.A. Jigsaw)
 */
class FlxHitbox extends FlxSpriteGroup
{
	public var buttonLeft:FlxButton = new FlxButton(0, 0);
	public var buttonDown:FlxButton = new FlxButton(0, 0);
	public var buttonUp:FlxButton = new FlxButton(0, 0);
	public var buttonRight:FlxButton = new FlxButton(0, 0);

	public var buttonDodge:FlxButton = new FlxButton(0, 0);
	public var buttonAttackLeft:FlxButton = new FlxButton(0, 0);
	public var buttonAttackRight:FlxButton = new FlxButton(0, 0);

	/**
	 * A single dodge/attack button's footprint. Width matches buttonLeft's
	 * own quarter-screen column EXACTLY, so the note-lane notch below only
	 * ever has to trim buttonLeft -- buttonDown/Up/Right stay FULL
	 * FlxG.height in every mode, for the whole song, same as DEFAULT.
	 *
	 * Height is a generous, independently-chosen finger target (NOT tied
	 * to the note-lane math the way the old 540/height-4 band split was) --
	 * this used to shrink all 4 note lanes to a fixed 540px for the WHOLE
	 * song whenever a song had ANY mechanic, whether or not a dodge/attack
	 * window was even active at that moment. Now only buttonLeft gives up
	 * a small corner, sized to how many button rows THIS mode actually
	 * needs (see `rows` below), not a fixed fraction of every song.
	 */
	static inline var BTN_W_DIV:Int = 4; // FlxG.width / 4
	static inline var BTN_H_DIV:Int = 5; // FlxG.height / 5

	/**
	 * Create the zone.
	 */
	public function new(mode:Modes)
	{
		super();

		// True = "Bottom hitboxes", false = "Top Hitboxes" (Options.hx's
		// MechsInputVariants) -- repurposed from choosing which edge the
		// OLD full-width mechanic band sat against to choosing which edge
		// (bottom-left or top-left) this new compact button cluster
		// anchors to instead. PlayState.hx repositions dodgeHud/attackHud
		// to match this same flag, so the icon players see stays exactly
		// on top of whichever corner is actually tappable.
		final bottomAnchored:Bool = FlxG.save.data.mechsInputVariants;

		final btnW:Float = FlxG.width / BTN_W_DIV;
		final btnH:Float = FlxG.height / BTN_H_DIV;

		// How many stacked rows the corner cluster needs -- SINGLEDODGE/
		// SINGLEATTACK need one (just dodge, or just attack); DOUBLE/TRIPLE
		// need two (TRIPLE's second row is attackLeft+attackRight split
		// side by side within the SAME row, not a 3rd row).
		final rows:Int = switch (mode)
		{
			case SINGLEDODGE | SINGLEATTACK: 1;
			case DOUBLE | TRIPLE: 2;
			case DEFAULT: 0;
		}

		final notchH:Float = btnH * rows;
		final leftY:Float = bottomAnchored ? 0 : notchH;
		final leftH:Float = FlxG.height - notchH;
		// row0 is always the UPPER of the two rows (smaller Y), row1 the
		// LOWER one (row0Y + btnH) -- true regardless of anchor direction.
		// What that means in practice flips with bottomAnchored: top-
		// anchored puts row0 at the very top edge and row1 adjacent to the
		// note lanes below it; bottom-anchored puts row0 adjacent to the
		// note lanes above it and row1 at the very bottom edge.
		final row0Y:Float = bottomAnchored ? FlxG.height - notchH : 0;
		final row1Y:Float = row0Y + btnH;

		switch (mode)
		{
			case DEFAULT:
				add(buttonLeft = createHint(0, 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF00FF));
				add(buttonDown = createHint(FlxG.width / 4, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FF00));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF0000));
			case SINGLEATTACK:
				add(buttonLeft = createHint(0, leftY, Std.int(btnW), Std.int(leftH), 0xFF00FF));
				add(buttonDown = createHint(FlxG.width / 4, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FF00));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF0000));
				add(buttonAttackLeft = createHint(0, row0Y, Std.int(btnW), Std.int(btnH), 0xFF0000));
			case SINGLEDODGE:
				add(buttonLeft = createHint(0, leftY, Std.int(btnW), Std.int(leftH), 0xFF00FF));
				add(buttonDown = createHint(FlxG.width / 4, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FF00));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF0000));
				add(buttonDodge = createHint(0, row0Y, Std.int(btnW), Std.int(btnH), 0xFFFF00));
			case DOUBLE:
				add(buttonLeft = createHint(0, leftY, Std.int(btnW), Std.int(leftH), 0xFF00FF));
				add(buttonDown = createHint(FlxG.width / 4, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FF00));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF0000));
				add(buttonDodge = createHint(0, row0Y, Std.int(btnW), Std.int(btnH), 0xFFFF00));
				add(buttonAttackLeft = createHint(0, row1Y, Std.int(btnW), Std.int(btnH), 0xFF0000));
			case TRIPLE:
				add(buttonLeft = createHint(0, leftY, Std.int(btnW), Std.int(leftH), 0xFF00FF));
				add(buttonDown = createHint(FlxG.width / 4, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, 0, Std.int(FlxG.width / 4), FlxG.height, 0x00FF00));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF0000));
				add(buttonDodge = createHint(0, row0Y, Std.int(btnW), Std.int(btnH), 0xFFFF00));
				// attackHud (PlayState.hx) stays ONE undivided visual icon
				// at its normal fixed x, sitting inside the LEFT half below
				// -- it has no dedicated "right" counterpart, so the
				// ATTACKRIGHT half is comfortably finger-sized but visually
				// unmarked. The alternative (stretching or duplicating the
				// icon) risked distorting art nobody previewed; flagged as
				// a follow-up rather than guessed at here. Either half is
				// still a full btnW/2 (~FlxG.width/8) wide, same btnH-tall
				// as every other button in this file, so both stay
				// comfortably tappable with one finger instead of being
				// squeezed into slivers.
				add(buttonAttackLeft = createHint(0, row1Y, Std.int(btnW / 2), Std.int(btnH), 0xFF0000));
				add(buttonAttackRight = createHint(btnW / 2, row1Y, Std.int(btnW / 2), Std.int(btnH), 0xFF0000));
		}

		scrollFactor.set();
	}

	/**
	 * Clean up memory.
	 */
	override function destroy()
	{
		super.destroy();

		buttonLeft = null;
		buttonDown = null;
		buttonUp = null;
		buttonRight = null;
		buttonDodge = null;
		buttonAttackLeft = null;
		buttonAttackRight = null;
	}

	private function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF):BitmapData
	{
		var shape:Shape = new Shape();

		if (FlxG.save.data.gradientHitboxes)
		{
			shape.graphics.beginFill(Color);
			shape.graphics.lineStyle(3, Color, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.lineStyle(0, 0, 0);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
			shape.graphics.beginGradientFill(RADIAL, [Color, FlxColor.TRANSPARENT], [0.6, 0], [0, 255], null, null, null, 0.5);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
		}
		else
		{
			shape.graphics.beginFill(Color);
			shape.graphics.lineStyle(10, Color, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}

		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF):FlxButton
	{
		var hintTween:FlxTween = null;
		var hint:FlxButton = new FlxButton(X, Y);
		hint.loadGraphic(createHintGraphic(Width, Height, Color));
		hint.solid = false;
		hint.immovable = true;
		hint.scrollFactor.set();
		hint.alpha = 0.00001;
		hint.onDown.callback = function()
		{
			if (hintTween != null)
				hintTween.cancel();

			hintTween = FlxTween.tween(hint, {alpha: AndroidControls.getOpacity(true)}, AndroidControls.getOpacity(true) / 100, {
				ease: FlxEase.circInOut,
				onComplete: function(twn:FlxTween)
				{
					hintTween = null;
				}
			});
		}
		hint.onUp.callback = function()
		{
			if (hintTween != null)
				hintTween.cancel();

			hintTween = FlxTween.tween(hint, {alpha: 0.00001}, AndroidControls.getOpacity(true) / 10, {
				ease: FlxEase.circInOut,
				onComplete: function(twn:FlxTween)
				{
					hintTween = null;
				}
			});
		}
		hint.onOut.callback = function()
		{
			if (hintTween != null)
				hintTween.cancel();

			hintTween = FlxTween.tween(hint, {alpha: 0.00001}, AndroidControls.getOpacity(true) / 10, {
				ease: FlxEase.circInOut,
				onComplete: function(twn:FlxTween)
				{
					hintTween = null;
				}
			});
		}
		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		return hint;
	}
}

enum Modes
{
	DEFAULT;
	SINGLEATTACK;
	SINGLEDODGE;
	DOUBLE;
	TRIPLE;
}
