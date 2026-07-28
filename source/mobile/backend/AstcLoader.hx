package mobile.backend;

import flixel.FlxG;

#if (android && cpp)
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.textures.ASTCTexture;
import openfl.utils.Assets as OflAssets;
import openfl.events.Event;
#end

using StringTools;

/**
 * Loads raw ASTC texture files into OpenFL BitmapData backed by a GPU-side
 * compressed texture, via Context3D.createASTCTexture() -- the same public
 * API openfl.utils.Assets.getBitmapData() already uses internally to
 * transparently load any APK-bundled ASTC-only asset.
 *
 * ASTC files live next to their PNG counterpart with a .astc extension:
 *   assets/images/characters/bf.png  →  assets/images/characters/bf.astc
 * The PNGs stay in the repo/APK (non-Android targets, and any image outside
 * the 500-4096px conversion range, still load the PNG directly -- see
 * Paths.hx's returnGraphic()) but on Android, once a .astc exists and the
 * device supports it, that image is ASTC-only end to end: initial load,
 * AND context-loss recovery below, never fall back to decoding the PNG.
 * The .astc file is a permanent bundled asset (not removable DLC), so
 * there is no realistic scenario where it goes missing but the PNG doesn't.
 *
 * Context-loss recovery: Android destroys the GPU context when the app is
 * backgrounded. BitmapData.fromTexture() has no CPU pixels and cannot be
 * restored automatically by OpenFL. This class registers a CONTEXT3D_CREATE
 * listener that re-reads the same .astc file and re-uploads it, patching the
 * existing ASTCTexture's GL handle in-place so all live BitmapData instances
 * automatically see fresh GPU data.
 *
 * Ported from NightmareVision-Android-Support's mobile/backend/AstcLoader.hx.
 * Not ported: the gpuCaching integration (trackGpuCached/_gpuCachedBitmaps/
 * _restoreGpuCachedBitmap) -- that existed only to work with NightmareVision's
 * own FunkinCache.cacheBitmap() memory-pressure feature, which Indie-Cross-
 * Public's Paths.hx has no equivalent of. Also not ported: NightmareVision's
 * PNG-fallback recovery path (_restoreFromPng) -- Android is meant to depend
 * on ASTC alone once it's loaded one, never falling back to the PNG.
 */
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.BitmapData)
class AstcLoader
{
	#if (android && cpp)
	// Keyed by PNG path (= Paths.hx cache key).
	static var _recovery:Map<String, {
		astcPath: String,
		astcTex:  ASTCTexture,
		width:    Int,
		height:   Int,
	}> = [];
	static var _listenerInstalled:Bool = false;
	#end

	/**
	 * Installs the CONTEXT3D_CREATE listener that re-uploads all tracked ASTC
	 * textures after an OpenGL context loss/restore cycle.
	 * Safe to call multiple times — only installs once.
	 * Call from Caching.hx right after AstcSupport.check().
	 */
	public static function installContextHandler():Void
	{
		#if (android && cpp)
		if (_listenerInstalled) return;
		_listenerInstalled = true;
		FlxG.stage.stage3Ds[0].addEventListener(Event.CONTEXT3D_CREATE, _onContextRestored);
		#end
	}

	/**
	 * Removes a PNG cache key from the recovery map.
	 * Call when a texture is evicted from Paths.hx's tracking so it is not
	 * re-uploaded on context restoration.
	 */
	public static function removeTracking(cacheKey:String):Void
	{
		#if (android && cpp)
		_recovery.remove(cacheKey);
		#end
	}

	/**
	 * Derives the ASTC path for a PNG path and attempts to load it.
	 * Checks external storage first, then falls back to bundled APK assets.
	 * The returned BitmapData is registered for automatic context-loss recovery.
	 * Returns null if ASTC is unsupported, no .astc exists, or loading fails.
	 */
	public static function tryLoad(pngPath:String):Null<BitmapData>
	{
		#if (android && cpp)
		if (!AstcSupport.isSupported) return null;

		var astcPath = deriveAstcPath(pngPath);
		if (astcPath == null) return null;

		// External storage (extracted APK assets, DLC overrides) takes priority.
		if (sys.FileSystem.exists(astcPath))
		{
			try
			{
				var bytes = sys.io.File.getBytes(astcPath);
				return loadAndTrack(pngPath, astcPath, bytes);
			}
			catch (e:Dynamic)
			{
				trace('AstcLoader: failed to read $astcPath — $e');
				return null;
			}
		}

		// Bundled APK asset — allows shipping pre-compressed ASTC inside the APK.
		if (OflAssets.exists(astcPath))
		{
			var bytes = OflAssets.getBytes(astcPath);
			if (bytes != null) return loadAndTrack(pngPath, astcPath, bytes);
		}

		return null;
		#else
		return null;
		#end
	}

	// ---------------------------------------------------------------------------

	#if (android && cpp)

	/**
	 * Loads ASTC bytes, wraps in BitmapData, and registers in the recovery map
	 * so the texture survives an OpenGL context loss/restore cycle.
	 */
	public static function loadAndTrack(pngPath:String, astcPath:String, bytes:haxe.io.Bytes):Null<BitmapData>
	{
		try
		{
			var result = _loadInternal(astcPath, bytes);
			if (result == null) return null;

			_recovery.set(pngPath, {
				astcPath: astcPath,
				astcTex:  result.astcTex,
				width:    result.width,
				height:   result.height,
			});

			return result.bitmap;
		}
		catch (e:Dynamic)
		{
			trace('AstcLoader: failed to load $astcPath — $e');
			return null;
		}
	}

	/**
	 * Uploads the ASTC bytes to the GPU via Context3D.createASTCTexture() --
	 * the same public OpenFL API openfl.utils.Assets.getBitmapData() already
	 * uses for every APK-bundled ASTC asset -- and wraps the result in a
	 * BitmapData. createASTCTexture() does its own header parsing/validation
	 * and GL upload internally, so there is no manual magic-byte/block-size
	 * parsing or raw GL call here to get wrong.
	 */
	static function _loadInternal(path:String, bytes:haxe.io.Bytes):Null<{bitmap:BitmapData, astcTex:ASTCTexture, width:Int, height:Int}>
	{
		var context3D:Null<Context3D> = openfl.Lib.current.stage.context3D;
		if (context3D == null) return null;

		try
		{
			var astcTex = context3D.createASTCTexture(bytes);
			var bitmap = BitmapData.fromTexture(astcTex);
			return {bitmap: bitmap, astcTex: astcTex, width: astcTex.__width, height: astcTex.__height};
		}
		catch (e:Dynamic)
		{
			trace('AstcLoader: createASTCTexture failed for $path — $e');
			return null;
		}
	}

	/**
	 * Called when the Stage3D context is created or recreated after context
	 * loss. For every tracked texture, re-reads the SAME .astc file (disk
	 * first, then bundled APK asset) and re-uploads it -- never the PNG.
	 * The .astc is a permanent bundled asset, not removable DLC, so a
	 * missing-file failure here just means something else is badly wrong
	 * (corrupted install); logging and evicting the entry is the correct
	 * response, not silently swapping the whole texture stack over to PNG.
	 *
	 * On the initial CONTEXT3D_CREATE (before any ASTC textures are loaded)
	 * the recovery map is empty and this function returns immediately.
	 */
	static function _onContextRestored(_:Dynamic):Void
	{
		var context3D:Null<Context3D> = openfl.Lib.current.stage.context3D;
		if (context3D == null) return;

		var restored = 0;
		var failed = 0;
		var toRemove:Array<String> = [];

		for (pngPath => entry in _recovery)
		{
			// If the graphic is no longer in FlxG.bitmap the sprite that owned it was
			// destroyed without going through Paths.hx's removeTracking. Nothing left
			// to restore — skip the GPU upload and evict this entry.
			if (!FlxG.bitmap.checkCache(pngPath))
			{
				toRemove.push(pngPath);
				continue;
			}

			var bytes:Null<haxe.io.Bytes> = null;
			try
			{
				if (sys.FileSystem.exists(entry.astcPath))
					bytes = sys.io.File.getBytes(entry.astcPath);
				else if (OflAssets.exists(entry.astcPath))
					bytes = OflAssets.getBytes(entry.astcPath);
			}
			catch (e:Dynamic) {}

			if (bytes == null)
			{
				trace('AstcLoader: context restore — ${entry.astcPath} missing, cannot restore');
				toRemove.push(pngPath);
				failed++;
				continue;
			}

			// The old __textureID is a dead handle after context loss; the driver
			// already freed all GPU resources. Build a fresh ASTCTexture against
			// the (also fresh) context3D purely to get a new, valid GL handle,
			// then steal it into the ORIGINAL entry.astcTex object -- the live
			// BitmapData's __texture already permanently references that same
			// object, so patching its __textureID in place is all that's needed
			// for the renderer to pick up the new handle on the next draw.
			try
			{
				var freshTex = context3D.createASTCTexture(bytes);
				entry.astcTex.__textureID = freshTex.__textureID;
				freshTex.__textureID = 0; // orphan wrapper -- ownership moved to entry.astcTex
				restored++;
			}
			catch (e:Dynamic)
			{
				// GL upload error (driver-side failure). Skip and log.
				trace('AstcLoader: context restore upload failed for ${entry.astcPath} — $e');
				failed++;
			}
		}

		for (key in toRemove)
			_recovery.remove(key);

		if (restored > 0 || failed > 0)
			trace('AstcLoader: context restored — $restored textures re-uploaded, $failed failed');
	}

	#end // android && cpp

	/**
	 * Derives the ASTC file path from a PNG asset path.
	 * The .astc file lives next to the .png — only the extension changes.
	 *
	 *   assets/images/characters/bf.png  →  assets/images/characters/bf.astc
	 */
	public static function deriveAstcPath(pngPath:String):Null<String>
	{
		if (!pngPath.endsWith('.png')) return null;
		return pngPath.substr(0, pngPath.length - 4) + '.astc';
	}
}
