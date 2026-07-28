package;

import flash.display.BlendMode;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.system.System;

using StringTools;

class TitleState extends MusicBeatState
{
	static var initialized:Bool = false;

	var textGroup:FlxGroup;

	var bg:FlxSprite;
	var logoBl:FlxSprite;
	var playBttn:FlxSprite;
	var bfSpr:FlxSprite;

	var vidSpr:FlxSprite;
	var videoDone:Bool = false;

	var blackOverlay:FlxSprite;

	var resizeConstant:Float = 1.196;

	override public function create():Void
	{
		trace('hello');

		super.create();

		bg = new FlxSprite();
		bg.frames = Paths.getSparrowAtlas('title/Bg');
		bg.antialiasing = FlxG.save.data.highquality;
		bg.animation.addByPrefix('idle', 'ddddd instance 1', 24, false);
		bg.animation.play('idle', true);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		var cupCircle:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('title/CupCircle', 'preload'));
		cupCircle.setGraphicSize(Std.int(cupCircle.width / resizeConstant));
		cupCircle.antialiasing = FlxG.save.data.highquality;
		cupCircle.blend = BlendMode.ADD;
		cupCircle.updateHitbox();
		cupCircle.screenCenter();
		cupCircle.x -= 300;
		add(cupCircle);

		FlxTween.angle(cupCircle, 0, 360, 10, {type: LOOPING});

		var sansCircle:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('title/SansCircle', 'preload'));
		sansCircle.setGraphicSize(Std.int(sansCircle.width / resizeConstant));
		sansCircle.antialiasing = FlxG.save.data.highquality;
		sansCircle.blend = BlendMode.ADD;
		sansCircle.updateHitbox();
		sansCircle.screenCenter();
		sansCircle.y -= 170;
		add(sansCircle);

		FlxTween.angle(sansCircle, 0, -360, 6, {type: LOOPING});

		var bendyCircle:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('title/BendyCircle', 'preload'));
		bendyCircle.setGraphicSize(Std.int(bendyCircle.width / resizeConstant));
		bendyCircle.antialiasing = FlxG.save.data.highquality;
		bendyCircle.blend = BlendMode.ADD;
		bendyCircle.updateHitbox();
		bendyCircle.screenCenter();
		bendyCircle.x += 300;
		add(bendyCircle);

		FlxTween.angle(bendyCircle, 0, 360, 8, {type: LOOPING});

		logoBl = new FlxSprite();
		logoBl.frames = Paths.getSparrowAtlas('title/Logo');
		logoBl.antialiasing = FlxG.save.data.highquality;
		logoBl.animation.addByPrefix('bump', 'Tween 11 instance 1', 24, false);
		logoBl.animation.play('bump');
		logoBl.setGraphicSize(Std.int(logoBl.width / resizeConstant));
		logoBl.updateHitbox();
		logoBl.screenCenter();
		logoBl.x -= 285;
		logoBl.y -= 25;
		logoBl.blend = BlendMode.ADD;
		add(logoBl);

		playBttn = new FlxSprite(660, 570);
		playBttn.frames = Paths.getSparrowAtlas('title/Playbutton');
		playBttn.animation.addByPrefix('idle', 'Button instance 1', 24, true);
		playBttn.animation.play('idle', true);
		playBttn.setGraphicSize(Std.int(playBttn.width / 1.1));
		playBttn.antialiasing = FlxG.save.data.highquality;
		playBttn.blend = BlendMode.ADD;
		add(playBttn);

		var playText:FlxSprite = new FlxSprite(playBttn.x + 50, playBttn.y + 10).loadGraphic(Paths.image('title/PlayText'));
		playText.setGraphicSize(Std.int(playText.width / 1.1));
		playText.antialiasing = FlxG.save.data.highquality;
		add(playText);

		bfSpr = new FlxSprite(690, 180);
		bfSpr.frames = Paths.getSparrowAtlas('title/BF');
		bfSpr.animation.addByPrefix('idle', 'BF idle dance instance 1', 24, false);
		bfSpr.animation.play('idle', true);
		bfSpr.antialiasing = FlxG.save.data.highquality;
		bfSpr.blend = BlendMode.ADD;
		add(bfSpr);

		blackOverlay = new FlxSprite().makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		blackOverlay.updateHitbox();
		blackOverlay.screenCenter();
		blackOverlay.scrollFactor.set();
		add(blackOverlay);

		creditsText = new FlxText(0, FlxG.height - 26, 0, "the credits would be shown in the menu", 18);
		creditsText.alpha = 0.00001;
		creditsText.setFormat(HelperFunctions.returnMenuFont(creditsText), 18, FlxColor.WHITE, RIGHT);
		creditsText.scrollFactor.set();
		creditsText.screenCenter(X);
		add(creditsText);

		vidSpr = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(vidSpr);

		startIntro();
	}

	var hold:Bool = false;
	var time:Float = 0;
	var creditsText:FlxText;
	var skipText:FlxText;

	function startIntro()
	{
		Conductor.changeBPM(Main.menubpm);
		persistentUpdate = true;

		if (!videoDone && !initialized)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();

			#if android
			skipText = new FlxText(0, FlxG.height - 26, 0, "Press Back on your phone to skip", 18);
			#else
			skipText = new FlxText(0, FlxG.height - 26, 0, "Press Enter to skip", 18);
			#end
			skipText.alpha = 0.00001;
			skipText.setFormat(HelperFunctions.returnMenuFont(skipText), 18, FlxColor.WHITE, RIGHT);
			skipText.scrollFactor.set();
			skipText.screenCenter(X);

			var video:VideoHandler = new VideoHandler();
			video.allowSkip = FlxG.save.data.watchedTitleVid;
			video.finishCallback = function()
			{
				videoDone = true;
				FlxG.sound.playMusic(Paths.music(Main.menuMusic), 0);
				FlxG.sound.music.fadeIn(4, 0, 1);
				vidSpr.visible = false;
				remove(skipText);
				FlxTween.tween(blackOverlay, {alpha: 0}, 1);
			};
			FlxG.save.data.watchedTitleVid = true;
			video.playMP4(Paths.video('intro'), false, vidSpr, false, true, false);

			if (video.allowSkip)
			{
				add(skipText);
				FlxTween.tween(skipText, {alpha: 1}, 1, {ease: FlxEase.quadIn});
				FlxTween.tween(skipText, {alpha: 0}, 1, {ease: FlxEase.quadIn, startDelay: 4});
			}
			else
			{
				MainMenuState.showKeybindsMenu = true;
			}
		}

		if (initialized)
		{
			vidSpr.visible = false;
			videoDone = true;
			blackOverlay.alpha = 0.00001;

			if (FlxG.sound.music == null || !FlxG.sound.music.active)
			{
				FlxG.sound.playMusic(Paths.music(Main.menuMusic), 0);
				FlxG.sound.music.fadeIn(4, 0, 1);
			}
		}
		else
		{
			initialized = true;
		}
	}

	var transitioning:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		if (FlxG.keys.justPressed.I && FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT)
		{
			MainMenuState.showCredits = true;
			FlxG.sound.play(Paths.sound('confirmMenu', 'preload'));
		}

		if ((FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.R) #if android || FlxG.android.justReleased.BACK #end && videoDone)
		{
			restart();
		}

		#if debug
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.A && videoDone)
		{
			FlxG.switchState(() -> new AnimState());
		}
		#end

		var pressed:Bool = controls.ACCEPT;

		#if android
		for (touch in FlxG.touches.list)
			if (touch.justReleased && !FlxG.android.justReleased.BACK)
				pressed = true;

		if (FlxG.android.justReleased.BACK && videoDone)
			MainMenuState.showCredits = true;
		#end

		if ((!transitioning && videoDone) && pressed)
			accept();

		if (FlxG.keys.justPressed.ANY && !videoDone)
		{
			var key = FlxG.keys.getIsDown()[0].ID;

			if (key != "ENTER")
			{
				FlxTween.tween(skipText, {alpha: 1}, 1, {ease: FlxEase.quadIn});
				FlxTween.tween(skipText, {alpha: 0}, 1, {ease: FlxEase.quadIn, startDelay: 4});
			}
		}

		super.update(elapsed);
	}

	function accept()
	{
		flash(FlxColor.WHITE, 1);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

		transitioning = true;

		new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			FlxG.switchState(() -> new MainMenuState());
		});
	}

	override function beatHit()
	{
		super.beatHit();

		if (bg != null)
		{
			bg.animation.play('idle', true);
		}
		if (logoBl != null)
		{
			logoBl.animation.play('bump', true);
		}
		if (bfSpr != null)
		{
			bfSpr.animation.play('idle', true);
		}

		FlxG.log.add(curBeat);
	}

	function flash(color:FlxColor, duration:Float)
	{
		FlxG.camera.stopFX();
		FlxG.camera.flash(color, duration);
	}

	public static function restart()
	{
		FlxG.resetGame();
	}
}
