package android.flixel;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import android.flixel.FlxButton;
import Note;

/**
 * Drives a NOTETAP-mode FlxHitbox by tapping the falling note sprites
 * directly instead of a fixed on-screen zone -- ported from NightmareVision-
 * Android-Support's mobile.controls.NoteTapInput, adapted to this codebase's
 * Controls.hx/FlxActionDigital-based input binding instead of their own
 * separate duck-typed interface (see FlxButton.forcePress()/forceRelease()'s
 * doc comment for why that's the right fit here).
 *
 * Lane COMMITMENT happens once per touch-down (whichever live note, if any,
 * is under the touch at that instant) and persists for that same physical
 * touch until release, exactly like a real button. Re-checking overlap every
 * frame instead -- the way FlxButton's own touch-overlap scan works, and the
 * more "obvious" design for a moving target -- would cut a held sustain note
 * short the instant its head note is consumed and the tracked note
 * disappears, since the player's finger isn't necessarily dragging to follow
 * the falling sustain visual. NightmareVision-Android-Support's own
 * NoteTapInput has the identical per-touch commitment for the identical
 * reason (its `_heldTouches` map).
 */
class NoteTapInput
{
	/** Extra hit padding around each note sprite (px, game-logical space) -- matches NightmareVision-Android-Support's own HIT_PAD. */
	static inline var HIT_PAD:Float = 45;

	var hitbox:FlxHitbox;
	var notes:FlxTypedGroup<Note>;
	var camera:FlxCamera;

	// touchPointID -> lane (0=LEFT 1=DOWN 2=UP 3=RIGHT) currently held by that touch
	var heldTouches:Map<Int, Int> = new Map();

	// Reused instead of letting FlxTouch.getScreenPosition() pull a fresh
	// FlxPoint from the pool (and never return it) on every touch-down.
	var touchPosPoint:FlxPoint = FlxPoint.get();

	public function new(hitbox:FlxHitbox, notes:FlxTypedGroup<Note>, camera:FlxCamera)
	{
		this.hitbox = hitbox;
		this.notes = notes;
		this.camera = camera;
	}

	/**
	 * Call once per frame (PlayState.update()) while Note Tap controls are
	 * active. Note this reads whatever position `notes` members already
	 * have as of the START of this frame (last frame's final positions, not
	 * yet re-simulated for the current one) -- a fixed, sub-frame amount of
	 * latency, same as NightmareVision-Android-Support's own version (also
	 * just a plain per-frame update() with no special ordering against the
	 * rest of that frame's note movement).
	 */
	public function update():Void
	{
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				var touchPos = touch.getScreenPosition(camera, touchPosPoint);
				var lane:Int = findNoteLane(touchPos.x, touchPos.y);
				if (lane >= 0)
				{
					heldTouches.set(touch.touchPointID, lane);
					setPressed(lane);
				}
			}
			else if (touch.justReleased)
			{
				var lane:Null<Int> = heldTouches.get(touch.touchPointID);
				if (lane != null)
				{
					heldTouches.remove(touch.touchPointID);

					// Only release when no OTHER finger still holds this same lane.
					var stillHeld:Bool = false;
					for (heldLane in heldTouches)
					{
						if (heldLane == lane)
						{
							stillHeld = true;
							break;
						}
					}
					if (!stillHeld)
						setReleased(lane);
				}
			}
		}
	}

	/**
	 * Finds the lane (0-3) of the nearest live, hittable PLAYER note whose
	 * padded bounding box contains the touch point. Returns -1 if none.
	 */
	function findNoteLane(tx:Float, ty:Float):Int
	{
		var bestLane:Int = -1;
		var bestDist:Float = Math.POSITIVE_INFINITY;

		for (note in notes.members)
		{
			if (note == null || !note.alive || note.isSustainNote) continue;
			if (!note.mustPress || note.tooLate || note.wasGoodHit) continue;

			final cx:Float = note.x + note.width * 0.5;
			final cy:Float = note.y + note.height * 0.5;
			final hw:Float = note.width * 0.5 + HIT_PAD;
			final hh:Float = note.height * 0.5 + HIT_PAD;

			if (Math.abs(tx - cx) <= hw && Math.abs(ty - cy) <= hh)
			{
				final dist:Float = Math.abs(tx - cx) + Math.abs(ty - cy);
				if (dist < bestDist)
				{
					bestDist = dist;
					bestLane = Math.floor(Math.abs(note.noteData));
				}
			}
		}

		return bestLane;
	}

	function buttonForLane(lane:Int):FlxButton
	{
		return switch (lane)
		{
			case 0: hitbox.buttonLeft;
			case 1: hitbox.buttonDown;
			case 2: hitbox.buttonUp;
			case 3: hitbox.buttonRight;
			default: null;
		}
	}

	function setPressed(lane:Int):Void
	{
		var button:FlxButton = buttonForLane(lane);
		if (button != null)
			button.forcePress();
	}

	function setReleased(lane:Int):Void
	{
		var button:FlxButton = buttonForLane(lane);
		if (button != null)
			button.forceRelease();
	}

	public function destroy():Void
	{
		heldTouches.clear();
		touchPosPoint.put();
		hitbox = null;
		notes = null;
		camera = null;
	}
}
