package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets;
import openfl.display.BitmapData;
import openfl.display3D.textures.Texture;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.Lib;
#if (android && cpp)
import openfl.display3D.Context3D;
import openfl.events.Event;
#end

using StringTools;

@:access(openfl.display3D.textures.TextureBase)
class Paths
{
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedTextures:Map<String, Texture> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static var localTrackedAssets:Array<String> = [];

	// ── GPU Render (Options -> Render Type 1/2) context-loss recovery ──────
	// The gpurender path in returnGraphic() below uploads a bitmap to a raw
	// Texture and immediately disposeImage()s the CPU pixel buffer to save
	// RAM -- same technique NightmareVision-Android-Support's gpuCaching
	// option uses, but that one tracks every such bitmap and re-decodes it
	// on Android's CONTEXT3D_CREATE (fired whenever the app backgrounds and
	// comes back, which destroys the whole GL context). This codebase never
	// had that tracking: any sprite atlas loaded while a GPU render mode is
	// active (getSparrowAtlas() always passes gpurender=true, so this is
	// most of the game's art) went permanently black after the very first
	// time the app was backgrounded, with no way to recover short of
	// restarting. Mirrors mobile.backend.AstcLoader's own recovery pattern
	// (re-read the source, upload into a fresh Texture, steal its GL handle
	// into the ORIGINAL tracked Texture object so nothing holding a
	// reference to it needs to change).
	#if (android && cpp)
	static var _gpuRenderRecovery:Map<String, {texture:Texture, width:Int, height:Int}> = [];
	static var _gpuRenderListenerInstalled:Bool = false;

	static function installGpuRenderContextHandler():Void
	{
		if (_gpuRenderListenerInstalled) return;
		_gpuRenderListenerInstalled = true;
		FlxG.stage.stage3Ds[0].addEventListener(Event.CONTEXT3D_CREATE, _onGpuRenderContextRestored);
	}

	static function _onGpuRenderContextRestored(_:Dynamic):Void
	{
		var context3D:Null<Context3D> = Lib.current.stage.context3D;
		if (context3D == null) return;

		var restored = 0;
		var failed = 0;
		var toRemove:Array<String> = [];

		for (path => entry in _gpuRenderRecovery)
		{
			if (!FlxG.bitmap.checkCache(path))
			{
				toRemove.push(path);
				continue;
			}

			// useCache=false: force a fresh decode -- the cached copy is this
			// exact bitmap, whose CPU image was already disposed on upload.
			var fresh:Null<BitmapData> = null;
			try
			{
				fresh = OpenFlAssets.getBitmapData(path, false);
			}
			catch (e:Dynamic) {}

			if (fresh == null)
			{
				trace('Paths: GPU render context restore -- "$path" missing, cannot restore');
				toRemove.push(path);
				failed++;
				continue;
			}

			try
			{
				var freshTex = context3D.createTexture(entry.width, entry.height, BGRA, true);
				freshTex.uploadFromBitmapData(fresh);
				entry.texture.__textureID = freshTex.__textureID;
				freshTex.__textureID = 0; // orphan wrapper -- ownership moved to entry.texture
				fresh.dispose();
				fresh.disposeImage();
				restored++;
			}
			catch (e:Dynamic)
			{
				trace('Paths: GPU render context restore upload failed for "$path" -- $e');
				failed++;
			}
		}

		for (key in toRemove)
			_gpuRenderRecovery.remove(key);

		if (restored > 0 || failed > 0)
			trace('Paths: GPU render context restored -- $restored texture(s) re-uploaded, $failed failed');
	}
	#end

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		var counter:Int = 0;
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key))
			{
				// get rid of it
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null)
				{
					var isTexture:Bool = currentTrackedTextures.exists(key);
					if (isTexture)
					{
						var texture = currentTrackedTextures.get(key);
						texture.dispose();
						texture = null;
						currentTrackedTextures.remove(key);
						#if (android && cpp)
						_gpuRenderRecovery.remove(key);
						#end
					}
					OpenFlAssets.cache.removeBitmapData(key);
					OpenFlAssets.cache.clearBitmapData(key);
					OpenFlAssets.cache.clear(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);
					#if (android && cpp)
					mobile.backend.AstcLoader.removeTracking(key);
					#end
					counter++;
				}
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		var counterAssets:Int = 0;

		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key))
			{
				OpenFlAssets.cache.removeBitmapData(key);
				OpenFlAssets.cache.clearBitmapData(key);
				OpenFlAssets.cache.clear(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
				counterAssets++;
			}
		}

		// clear all sounds that are cached
		var counterSound:Int = 0;
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && key != null)
			{
				// trace('test: ' + dumpExclusions, key);
				OpenFlAssets.cache.removeSound(key);
				OpenFlAssets.cache.clearSounds(key);
				currentTrackedSounds.remove(key);
				counterSound++;
			}
		}

		// Clear everything everything that's left
		var counterLeft:Int = 0;
		for (key in OpenFlAssets.cache.getKeys())
		{
			if (!localTrackedAssets.contains(key) && key != null)
			{
				OpenFlAssets.cache.clear(key);
				counterLeft++;
			}
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
	}

	static public var currentLevel:String;

	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if (currentLevel != 'shared')
			{
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);

	inline static function getLibraryPathForce(file:String, library:String)
		return '$library:assets/$library/$file';

	inline public static function getPreloadPath(file:String = '')
		return 'assets/$file';

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
		return getPath(file, type, library);

	inline static public function txt(key:String, ?library:String)
		return getPath('data/$key.txt', TEXT, library);

	inline static public function xml(key:String, ?library:String)
		return getPath('data/$key.xml', TEXT, library);

	inline static public function json(key:String, ?library:String)
		return getPath('data/$key.json', TEXT, library);

	inline static public function jsonHidden(key:String)
		return getPath('data/$key.json', TEXT, 'hiddenContent');

	inline static public function lua(key:String, ?library:String)
		return getPath('data/$key.lua', TEXT, library);

	inline static public function video(key:String)
		return 'assets/videos/$key.mp4';

	static public function sound(key:String, ?library:String, ?cache:Bool = true):Sound
		return returnSound('sounds', key, library, cache);

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String, ?cache:Bool = true)
		return returnSound('sounds', key + FlxG.random.int(min, max), library, cache);

	inline static public function music(key:String, ?library:String, ?cache:Bool = true):Sound
		return returnSound('music', key, library, cache);

	inline static public function voices(song:String, ?cache:Bool = true, ?type:String = 'none'):Sound
	{
		final songFormat:String = StringTools.replace(song, " ", "-").toLowerCase();
		return switch (type)
		{
			case 'hidden':
				return returnSound('songs', songFormat + '/Voices', 'hiddenContent', cache);
			case 'easy':
				return returnSound('songs', songFormat + '/Voices-easy', null, cache);
			default:
				return returnSound('songs', songFormat + '/Voices', null, cache);
		}
	}

	inline static public function inst(song:String, ?cache:Bool = true, ?type:String = 'none'):Sound
	{
		final songFormat:String = StringTools.replace(song, " ", "-").toLowerCase();
		return switch (type)
		{
			case 'hidden':
				return returnSound('songs', songFormat + '/Inst', 'hiddenContent', cache);
			case 'easy':
				return returnSound('songs', songFormat + '/Inst-easy', null, cache);
			default:
				return returnSound('songs', songFormat + '/Inst', null, cache);
		}
	}

	inline static public function image(key:String, ?library:String, ?gpurender:Bool = false):FlxGraphic
		return returnGraphic(key, library, gpurender);

	inline static public function font(key:String)
		return 'assets/fonts/$key';

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
		return FlxAtlasFrames.fromSparrow(image(key, library, true), file('images/$key.xml', library));

	inline static public function getPackerAtlas(key:String, ?library:String)
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library, true), file('images/$key.txt', library));

	public static function returnGraphic(key:String, ?library:String, ?gpurender:Bool = false):FlxGraphic
	{
		var path:String = getPath('images/$key.png', IMAGE, library);
		if (OpenFlAssets.exists(path, IMAGE))
		{
			if (!currentTrackedAssets.exists(path))
			{
				var newGraphic:FlxGraphic = null;
				var bitmap:BitmapData = null;
				var loadedFromAstc = false;

				// On Android, try loading a GPU-compressed ASTC override first
				// (assets/images/foo.png -> assets/images/foo.astc, same dir).
				// Falls through to the normal PNG path below if ASTC is
				// unsupported on this device, no .astc sibling exists, or
				// loading fails for any reason -- the PNG always stays the
				// source of truth. See mobile.backend.AstcLoader.
				#if (android && cpp)
				if (mobile.backend.AstcSupport.isSupported)
				{
					bitmap = mobile.backend.AstcLoader.tryLoad(path);
					loadedFromAstc = bitmap != null;
				}
				#end

				if (bitmap == null)
					bitmap = OpenFlAssets.getBitmapData(path);

				// An ASTC-loaded bitmap is already a GPU-resident texture with
				// no CPU pixel buffer (BitmapData.fromTexture()) -- the
				// gpurender branch below exists to manually upload PNG pixels
				// into a Texture, which would fail/corrupt on a bitmap that
				// has no pixels to read. Skip straight to the plain wrap path;
				// the ASTC texture already achieves what gpurender is for.
				if (gpurender && !loadedFromAstc)
				{
					switch (FlxG.save.data.render)
					{
						case 1:
							var texture = FlxG.stage.context3D.createTexture(bitmap.width, bitmap.height, BGRA, true);
							texture.uploadFromBitmapData(bitmap);
							currentTrackedTextures.set(path, texture);
							#if (android && cpp)
							_gpuRenderRecovery.set(path, {texture: texture, width: bitmap.width, height: bitmap.height});
							installGpuRenderContextHandler();
							#end
							bitmap.dispose();
							bitmap.disposeImage();
							bitmap = null;
							newGraphic = FlxGraphic.fromBitmapData(BitmapData.fromTexture(texture), false, path);
						case 2:
							var texture = Lib.current.stage.context3D.createTexture(bitmap.width, bitmap.height, BGRA, true);
							texture.uploadFromBitmapData(bitmap);
							currentTrackedTextures.set(path, texture);
							#if (android && cpp)
							_gpuRenderRecovery.set(path, {texture: texture, width: bitmap.width, height: bitmap.height});
							installGpuRenderContextHandler();
							#end
							bitmap.dispose();
							bitmap.disposeImage();
							bitmap = null;
							newGraphic = FlxGraphic.fromBitmapData(BitmapData.fromTexture(texture), false, path);
						default:
							newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path);
					}
				}
				else
					newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path);

				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}

			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}

		// Every caller of Paths.image()/getSparrowAtlas()/etc. assumes a real
		// FlxGraphic comes back and hands it straight to loadGraphic()/
		// FlxAtlasFrames.fromSparrow() with no null check -- a missing asset
		// used to return null here, which crashes several calls deeper with
		// no indication a missing image was the actual cause (e.g. Android's
		// case-sensitive filesystem catching a typo'd path that worked fine
		// on a case-insensitive dev machine, or a chart's noteData indexing
		// past the end of Note.hx's typeFile array). Falling back to
		// Flixel's own bundled logo keeps the game running with an obviously
		// wrong sprite instead of crashing outright, and the trace here
		// names exactly which path failed.
		trace('Paths.returnGraphic: missing image "$path" (key="$key", library="${library}") -- returning flixel logo placeholder');
		return FlxG.bitmap.add('flixel/images/logo/default.png');
	}

	public static function returnSound(path:String, key:String, ?library:String, ?cache:Bool = true):Sound
	{
		var oggPath:String;
		var wavPath:String;

		if (path == 'songs' && library == null)
		{
			oggPath = getPath('$key.ogg', SOUND, 'songs');
			wavPath = getPath('$key.wav', SOUND, 'songs');
		}
		else
		{
			oggPath = getPath('$path/$key.ogg', SOUND, library);
			wavPath = getPath('$path/$key.wav', SOUND, library);
		}

		// .ogg is what every bundled asset actually ships as -- checked
		// first so the common case still costs a single exists() lookup.
		// .wav is only a fallback for a loose/mod file that isn't
		// ogg-encoded (NightmareVision-Android-Support's Paths.hx does the
		// same ogg-then-wav probe).
		var gottenPath:String = oggPath;
		if (!OpenFlAssets.exists(oggPath, SOUND) && OpenFlAssets.exists(wavPath, SOUND))
			gottenPath = wavPath;

		if (OpenFlAssets.exists(gottenPath, SOUND))
		{
			if (!currentTrackedSounds.exists(gottenPath))
				currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(gottenPath, cache));

			localTrackedAssets.push(gottenPath);
			return currentTrackedSounds.get(gottenPath);
		}

		// Same reasoning as returnGraphic()'s fallback above -- callers never
		// null-check a Paths.sound()/music() result.
		trace('Paths.returnSound: missing sound "$gottenPath" (key="$key", library="${library}") -- returning beep placeholder');
		return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
	}
}
