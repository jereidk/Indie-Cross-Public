package;

import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;

using StringTools;

class ControlsOverlay extends FlxSpriteGroup
{
	var controlsHelp:FlxText;

	public function new()
	{
		super();

		// y=10 used to sit right on top of Main's FPS/MEM debug counters
		// (also anchored near the top-left corner, toggleable via Options) --
		// 85 clears their combined ~70px block (FPS line + MEM's 2 lines).
		controlsHelp = new FlxText(10, 85, 0, HelperFunctions.getSongData(PlayState.SONG.song.toLowerCase(), 'mech'), 32);
		controlsHelp.scrollFactor.set();
		controlsHelp.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		controlsHelp.alignment = LEFT;
		controlsHelp.font = HelperFunctions.returnHudFont(controlsHelp);
		controlsHelp.updateHitbox();
		if (controlsHelp.text == "CONTROLS\n")
			controlsHelp.alpha = 0.00001;
		add(controlsHelp);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	public function setAlpha(alpha:Float)
	{
		controlsHelp.alpha = alpha;
	}

	public function fade()
	{
		FlxTween.tween(controlsHelp, {alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			startDelay: (Conductor.crochet / 1000) * 8,
			onComplete: function(twn:FlxTween)
			{
				kill();
			}
		});
	}
}
