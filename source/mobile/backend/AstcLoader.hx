package mobile.backend;

import flixel.FlxG;

#if (android && cpp)
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.ASTCTexture;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.textures.TextureBase;
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
 * The original PNGs are never touched and always serve as fallback.
 * On devices that do not expose GL_KHR_texture_compression_astc_ldr
 * the loader returns null and the caller falls through to the PNG.
 *
 * Context-loss recovery: Android destroys the GPU context when the app is
 * backgrounded. BitmapData.fromTexture() has no CPU pixels and cannot be
 * restored automatically by OpenFL. This class registers a CONTEXT3D_CREATE
 * listener that re-uploads every tracked ASTC texture, patching the existing
 * ASTCTexture's GL handle in-place so all live BitmapData instances
 * automatically see fresh GPU data.
 *
 * PNG fallback: if the .astc file is missing when the context is restored
 * (e.g. DLC uninstalled, SD-card corruption), the loader falls back to the
 * original PNG and switches that entry permanently to PNG-restore mode so
 * future restore cycles also use the PNG.
 *
 * Ported from NightmareVision-Android-Support's mobile/backend/AstcLoader.hx.
 * Not ported: the gpuCaching integration (trackGpuCached/_gpuCachedBitmaps/
 * _restoreGpuCachedBitmap) -- that existed only to work with NightmareVision's
 * own FunkinCache.cacheBitmap() memory-pressure feature, which Indie-Cross-
 * Public's Paths.hx has no equivalent of.
 */
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.BitmapData)
class AstcLoader
{
	#if (android && cpp)
	// Keyed by PNG path (= Paths.hx cache key).
	static var _recovery:Map<String, {
		astcPath:      String,
		astcTex:       ASTCTexture,
		width:         Int,
		height:        Int,
		isPngFallback: Bool,
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
				astcPath:      astcPath,
				astcTex:       result.astcTex,
				width:         result.width,
				height:        result.height,
				isPngFallback: false,
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
	 * Called when the Stage3D context is created or recreated after context loss.
	 * For each tracked texture:
	 *   • isPngFallback == false (ASTC mode): re-reads from disk/APK. On missing
	 *     file, falls through to PNG fallback.
	 *   • isPngFallback == true: re-uploads from the original PNG.
	 *
	 * On the initial CONTEXT3D_CREATE (before any ASTC textures are loaded) the
	 * recovery map is empty and this function returns immediately.
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

			// PNG fallback mode — the .astc was missing on a previous restore;
			// this entry now permanently uses the PNG source.
			if (entry.isPngFallback)
			{
				if (_restoreFromPng(context3D, pngPath))
					restored++;
				else
				{
					toRemove.push(pngPath);
					failed++;
				}
				continue;
			}

			// ASTC mode: re-read from disk/APK on every restore.
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
				// .astc file disappeared (DLC removed, SD-card corruption, etc.).
				// Attempt PNG fallback so live sprites are not permanently black.
				trace('AstcLoader: context restore — ${entry.astcPath} missing, trying PNG fallback');
				if (_restoreFromPng(context3D, pngPath))
					restored++;
				else
				{
					toRemove.push(pngPath);
					failed++;
				}
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
				// GL upload error (driver-side failure). PNG fallback won't help
				// since the context itself may be in a bad state. Skip and log.
				trace('AstcLoader: context restore upload failed for ${entry.astcPath} — $e');
				failed++;
			}
		}

		for (key in toRemove)
			_recovery.remove(key);

		if (restored > 0 || failed > 0)
			trace('AstcLoader: context restored — $restored textures re-uploaded, $failed failed');
	}

	/**
	 * Restores a tracked texture from its PNG counterpart.
	 *
	 * Creates a temporary RectangleTexture, uploads the PNG BitmapData to it
	 * via OpenFL's standard path (handles BGRA/RGBA format internally), then
	 * transfers the GL handle to entry.astcTex (still a valid TextureBase to
	 * patch in place -- the live BitmapData's __texture already permanently
	 * references that same object). Sets the temporary wrapper's __textureID
	 * to 0 so any future cleanup call on it is a harmless no-op
	 * (gl.deleteTexture(0) is defined as a no-op by the GL spec).
	 *
	 * Permanently marks the entry as PNG mode (isPngFallback = true) so all
	 * subsequent context-restore cycles also re-upload from PNG without
	 * retrying the ASTC.
	 */
	static function _restoreFromPng(context3D:Context3D, pngPath:String):Bool
	{
		var entry = _recovery.get(pngPath);
		if (entry == null) return false;

		var pngBitmap:Null<BitmapData> = null;
		try
		{
			if (sys.FileSystem.exists(pngPath))
				pngBitmap = BitmapData.fromFile(pngPath);
			else if (OflAssets.exists(pngPath))
				// useCache=false: always decode fresh — the cached copy may have had disposeImage() called on it
				pngBitmap = OflAssets.getBitmapData(pngPath, false);
		}
		catch (e:Dynamic) {}

		if (pngBitmap == null)
		{
			trace('AstcLoader: PNG fallback failed for $pngPath — file not found');
			return false;
		}

		if (pngBitmap.width != entry.width || pngBitmap.height != entry.height)
			trace('AstcLoader: PNG fallback size mismatch for $pngPath — PNG ${pngBitmap.width}x${pngBitmap.height}, ASTC was ${entry.width}x${entry.height}');

		// Upload PNG pixels via OpenFL's standard path (format conversion handled
		// internally) into a temporary RectangleTexture, then steal its GL handle.
		var gl = context3D.gl;
		var tempTex:RectangleTexture = context3D.createRectangleTexture(
			pngBitmap.width, pngBitmap.height, Context3DTextureFormat.BGRA, false);
		tempTex.uploadFromBitmapData(pngBitmap);

		var uploadErr:Int = gl.getError();
		if (uploadErr != 0)
		{
			trace('AstcLoader: PNG fallback upload error 0x${StringTools.hex(uploadErr, 4)} for $pngPath');
			tempTex.dispose();
			pngBitmap.dispose();
			return false;
		}

		var handle = tempTex.__textureID;
		tempTex.__textureID = 0; // orphan wrapper — handle ownership moves to entry.astcTex
		entry.astcTex.__textureID = handle;
		pngBitmap.dispose();

		// Mark entry as PNG mode for all future context-restore cycles.
		entry.isPngFallback = true;

		trace('AstcLoader: PNG fallback succeeded for $pngPath');
		return true;
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
