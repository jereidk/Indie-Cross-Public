package;

#if android
import extension.androidtools.os.Build;
import extension.androidtools.os.Build.VERSION;
#end
import flixel.FlxG;
import flixel.graphics.tile.FlxDrawBaseItem;
import openfl.Lib;
#if sys
import sys.io.File;
#end

using StringTools;

/**
 * Per-session performance/diagnostics log: frame pacing, stutter spikes,
 * memory jumps, state-load cost. Written to perf.log next to game.log and
 * crash.log, TRUNCATED at every launch (unlike game.log, which rolls) --
 * this is meant to answer "why did it lag in the run I just did", so an
 * older session's noise is only in the way.
 *
 * Deliberately built only from things that still exist in the SHIPPED
 * build. Project.xml defines FLX_NO_DEBUG unless="debug", and flixel
 * inverts that into "no FLX_DEBUG" (FlxDefines.hx's defineInversion), so
 * a release APK has none of the debugger's own instrumentation:
 *
 *  - FlxBasic.activeCount/visibleCount only ever increment inside
 *    `#if FLX_DEBUG` (FlxBasic.update/draw), so they read 0 forever here
 *    and are NOT used.
 *  - FlxGame's own debugger.stats.flixelUpdate/flixelDraw timings are
 *    likewise debug-only, so update/draw cost is measured here directly
 *    off FlxG.signals.pre/postUpdate + pre/postDraw with Lib.getTimer().
 *  - FlxDrawBaseItem.drawCalls IS usable: it's a plain public static, and
 *    both its reset (FlxGame.draw) and its increment (FlxDrawBaseItem.
 *    render) sit outside the FLX_DEBUG gate.
 *
 * Lines are buffered in memory and flushed on the slow events (heartbeat,
 * summary, state switch) rather than written as they happen -- a profiler
 * that opens/closes a file mid-frame would itself cause the stutter it's
 * trying to record.
 */
class PerfLogger
{
	/** Seconds between HEARTBEAT lines. */
	static inline var HEARTBEAT_INTERVAL:Float = 5.0;

	/** Seconds between SUMMARY lines. */
	static inline var SUMMARY_INTERVAL:Float = 60.0;

	/** A frame this many times the running median counts as a spike... */
	static inline var SPIKE_FACTOR:Float = 2.5;

	/** ...but never below this, so normal jitter at high FPS isn't "a spike". */
	static inline var SPIKE_MIN_MS:Float = 40.0;

	/** Cap on SPIKE lines per second; the rest are only counted. */
	static inline var MAX_SPIKES_PER_SEC:Int = 3;

	/** A single-frame heap jump this big (MB) gets its own MEMORY line. */
	static inline var MEMORY_JUMP_MB:Float = 16.0;

	/** Frames kept for median/p95 (~4s at 60fps). */
	static inline var WINDOW:Int = 240;

	/** Buffered lines are force-flushed past this many, whatever else happens. */
	static inline var MAX_BUFFERED:Int = 64;

	static var active:Bool = false;

	#if sys
	static var logPath:String = '';
	static var buffer:Array<String> = [];
	#end

	// --- frame timing -------------------------------------------------

	static var startedAt:Float = 0;
	static var lastFrameEnd:Float = -1;

	static var frameTimes:Array<Float> = [];
	static var frameIndex:Int = 0;
	static var frameFilled:Int = 0;

	/** Median recomputed once a second, not per frame (sorting is not free). */
	static var refMedian:Float = 16.7;
	static var lastMedianCalc:Float = 0;

	static var updStart:Float = 0;
	static var drawStart:Float = 0;
	static var updMs:Float = 0;
	static var drawMs:Float = 0;

	// --- interval accounting ------------------------------------------

	static var lastHeartbeat:Float = 0;
	static var lastSummary:Float = 0;

	static var hbFrames:Int = 0;
	static var hbWorst:Float = 0;

	static var sumFrames:Int = 0;
	static var sumTotalMs:Float = 0;
	static var sumWorst:Float = 0;
	static var sumSpikes:Int = 0;

	static var spikeSecond:Int = -1;
	static var spikesThisSecond:Int = 0;
	static var spikesSuppressed:Int = 0;

	static var lastMemCurrent:Float = -1;

	// --- state switch timing ------------------------------------------

	static var switchStart:Float = 0;
	static var switchingFrom:String = '';

	/**
	 * Call once, as early as possible (Caching.create(), right after
	 * GameLogger.init()). Safe to call twice.
	 */
	public static function init():Void
	{
		#if sys
		if (active)
			return;

		var dir:String = GameLogger.getDir();
		if (dir == null || dir.length == 0)
			return;

		logPath = dir + 'perf.log';
		startedAt = Lib.getTimer();
		lastHeartbeat = 0;
		lastSummary = 0;
		lastMedianCalc = 0;

		try
		{
			// File.write (not append) -- one file per session, overwritten.
			var out = File.write(logPath, false);
			out.writeString(buildHeader());
			out.flush();
			out.close();
		}
		catch (e:Dynamic)
		{
			Sys.println('[PerfLogger] Failed to open perf.log: ' + Std.string(e));
			return;
		}

		FlxG.signals.preUpdate.add(onPreUpdate);
		FlxG.signals.postUpdate.add(onPostUpdate);
		FlxG.signals.preDraw.add(onPreDraw);
		FlxG.signals.postDraw.add(onPostDraw);
		FlxG.signals.preStateSwitch.add(onPreStateSwitch);
		FlxG.signals.postStateSwitch.add(onPostStateSwitch);
		FlxG.signals.focusLost.add(onFocusLost);
		FlxG.signals.focusGained.add(onFocusGained);

		active = true;
		#end
	}

	/**
	 * Free-form marker, for wiring up "something notable happened here"
	 * from gameplay code (a mechanic firing, a cutscene starting, ...).
	 */
	public static function mark(what:String):Void
	{
		#if sys
		if (!active)
			return;
		write('MARK', what);
		#end
	}

	#if sys
	// --- per-frame hooks ----------------------------------------------

	static function onPreUpdate():Void
	{
		updStart = Lib.getTimer();
	}

	static function onPostUpdate():Void
	{
		updMs = Lib.getTimer() - updStart;
	}

	static function onPreDraw():Void
	{
		drawStart = Lib.getTimer();
	}

	static function onPostDraw():Void
	{
		var now:Float = Lib.getTimer();
		drawMs = now - drawStart;

		if (lastFrameEnd < 0)
		{
			// First frame after init/refocus has no meaningful predecessor.
			lastFrameEnd = now;
			return;
		}

		var frameMs:Float = now - lastFrameEnd;
		lastFrameEnd = now;

		pushFrame(frameMs);

		hbFrames++;
		if (frameMs > hbWorst)
			hbWorst = frameMs;

		sumFrames++;
		sumTotalMs += frameMs;
		if (frameMs > sumWorst)
			sumWorst = frameMs;

		var elapsed:Float = (now - startedAt) / 1000;

		if (elapsed - lastMedianCalc >= 1.0)
		{
			refMedian = computeMedian();
			lastMedianCalc = elapsed;
		}

		checkSpike(frameMs, elapsed);
		checkMemory();

		if (elapsed - lastHeartbeat >= HEARTBEAT_INTERVAL)
		{
			heartbeat();
			lastHeartbeat = elapsed;
		}

		if (elapsed - lastSummary >= SUMMARY_INTERVAL)
		{
			summary();
			lastSummary = elapsed;
		}
	}

	static function pushFrame(ms:Float):Void
	{
		frameTimes[frameIndex] = ms;
		frameIndex = (frameIndex + 1) % WINDOW;
		if (frameFilled < WINDOW)
			frameFilled++;
	}

	static function checkSpike(frameMs:Float, elapsed:Float):Void
	{
		var threshold:Float = refMedian * SPIKE_FACTOR;
		if (threshold < SPIKE_MIN_MS)
			threshold = SPIKE_MIN_MS;

		if (frameMs < threshold)
			return;

		sumSpikes++;

		// Rate-limit: a genuine stall can produce a burst of these, and
		// logging every one both floods the file and adds cost right where
		// the game is already struggling.
		var sec:Int = Std.int(elapsed);
		if (sec != spikeSecond)
		{
			spikeSecond = sec;
			spikesThisSecond = 0;
		}

		spikesThisSecond++;
		if (spikesThisSecond > MAX_SPIKES_PER_SEC)
		{
			spikesSuppressed++;
			return;
		}

		var ratio:Float = refMedian > 0 ? frameMs / refMedian : 0;
		write('SPIKE', 'frame=' + fmt(frameMs) + 'ms median=' + fmt(refMedian) + 'ms (' + fmt(ratio) + 'x)');
	}

	static function checkMemory():Void
	{
		var cur:Float = memMB(2);
		if (lastMemCurrent >= 0)
		{
			var delta:Float = cur - lastMemCurrent;
			if (delta >= MEMORY_JUMP_MB)
				write('MEMORY', '+' + fmt(delta) + ' MB in one frame');
		}
		lastMemCurrent = cur;
	}

	static function heartbeat():Void
	{
		var median:Float = computeMedian();
		var p95:Float = computePercentile(0.95);
		var fpsNow:Float = median > 0 ? 1000 / median : 0;
		var fpsLow:Float = hbWorst > 0 ? 1000 / hbWorst : 0;

		var extra:String = 'fps=' + Std.int(fpsNow) + ' low=' + Std.int(fpsLow) + ' median=' + fmt(median) + 'ms p95=' + fmt(p95)
			+ 'ms worst=' + fmt(hbWorst) + 'ms frames=' + hbFrames;

		if (spikesSuppressed > 0)
		{
			extra += ' spikes_hidden=' + spikesSuppressed;
			spikesSuppressed = 0;
		}

		write('HEARTBEAT', extra);

		hbFrames = 0;
		hbWorst = 0;
		flush();
	}

	static function summary():Void
	{
		var mean:Float = sumFrames > 0 ? sumTotalMs / sumFrames : 0;
		var fps:Float = mean > 0 ? 1000 / mean : 0;

		write('SUMMARY', 'frames=' + sumFrames + ' mean=' + fmt(mean) + 'ms (' + Std.int(fps) + ' fps) worst=' + fmt(sumWorst) + 'ms spikes='
			+ sumSpikes);

		sumFrames = 0;
		sumTotalMs = 0;
		sumWorst = 0;
		sumSpikes = 0;
		flush();
	}

	// --- state / focus hooks ------------------------------------------

	static function onPreStateSwitch():Void
	{
		switchStart = Lib.getTimer();
		switchingFrom = stateName();
		write('STATE_OUT', switchingFrom);
	}

	static function onPostStateSwitch():Void
	{
		var took:Float = Lib.getTimer() - switchStart;
		write('STATE_IN', stateName() + ' took=' + Std.int(took) + 'ms from=' + switchingFrom);

		// A state switch resets pacing: the transition frame itself is not a
		// gameplay stutter, and counting it would poison the median for the
		// next few seconds.
		lastFrameEnd = -1;
		flush();
	}

	static function onFocusLost():Void
	{
		write('FOCUS', 'lost');
		flush();
	}

	static function onFocusGained():Void
	{
		write('FOCUS', 'gained');
		// Time spent in the background is not a frame time.
		lastFrameEnd = -1;
	}

	// --- metrics ------------------------------------------------------

	/**
	 * The common `| ...` metrics block every event line carries.
	 */
	static function metrics():String
	{
		var s:String = '';

		// hxcpp's Immix GC exposes four different numbers (Immix.cpp's
		// MEM_INFO_* enum): 1=Reserved (taken from the OS), 2=Current
		// (allocated right now), 3=Large (large-object allocations only).
		// Worth logging all three -- note the game's own on-screen MEM
		// counter (MemoryMonitor.hx) shows index 3, i.e. large objects
		// only, NOT total RAM, so they read very differently on purpose.
		s += 'mem=' + fmt(memMB(2)) + 'MB large=' + fmt(memMB(3)) + 'MB reserved=' + fmt(memMB(1)) + 'MB';

		// Texture cache: Paths.currentTrackedAssets is this game's own
		// FlxGraphic cache. Summing width*height*4 is an upper-bound
		// estimate of the uncompressed footprint (an ASTC-loaded graphic
		// actually costs far less on the GPU), but the count and the trend
		// are what matter for spotting a leak.
		var texCount:Int = 0;
		var texBytes:Float = 0;
		try
		{
			for (g in Paths.currentTrackedAssets)
			{
				if (g == null)
					continue;
				texCount++;
				texBytes += g.width * g.height * 4;
			}
		}
		catch (e:Dynamic) {}
		s += ' tex=' + texCount + '/' + fmt(texBytes / 1048576) + 'MB';

		s += ' draw=' + FlxDrawBaseItem.drawCalls;
		s += ' upd=' + fmt(updMs) + 'ms drw=' + fmt(drawMs) + 'ms';
		s += ' elapsed=' + fmt(FlxG.elapsed * 1000) + 'ms';
		s += ' state=' + stateName();

		// Gameplay context, when there is one -- a spike is much easier to
		// act on when it names the song and step it happened at. Gated on the
		// CURRENT state actually being a PlayState, not just on
		// PlayState.instance being non-null: that static outlives the state
		// itself, so checking it alone would tag menu lag with whatever song
		// was played last.
		try
		{
			if (Std.isOfType(FlxG.state, PlayState) && PlayState.instance != null && PlayState.SONG != null)
			{
				s += ' song=' + PlayState.SONG.song + ' step=' + PlayState.instance.curStep;
				if (PlayState.instance.notes != null)
					s += ' notes=' + PlayState.instance.notes.countLiving();
			}
		}
		catch (e:Dynamic) {}

		return s;
	}

	static function memMB(which:Int):Float
	{
		#if cpp
		try
		{
			return cpp.vm.Gc.memInfo64(which) / 1048576;
		}
		catch (e:Dynamic)
		{
			return 0;
		}
		#else
		return 0;
		#end
	}

	static function stateName():String
	{
		try
		{
			if (FlxG.state == null)
				return 'NoState';
			var n:String = Type.getClassName(Type.getClass(FlxG.state));
			var dot:Int = n.lastIndexOf('.');
			return dot >= 0 ? n.substring(dot + 1) : n;
		}
		catch (e:Dynamic)
		{
			return '?';
		}
	}

	// --- window stats -------------------------------------------------

	static function sortedWindow():Array<Float>
	{
		var copy:Array<Float> = [];
		for (i in 0...frameFilled)
			copy.push(frameTimes[i]);
		copy.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return copy;
	}

	static function computeMedian():Float
	{
		if (frameFilled == 0)
			return refMedian;
		var s = sortedWindow();
		return s[Std.int(s.length / 2)];
	}

	static function computePercentile(p:Float):Float
	{
		if (frameFilled == 0)
			return 0;
		var s = sortedWindow();
		var idx:Int = Std.int(s.length * p);
		if (idx >= s.length)
			idx = s.length - 1;
		return s[idx];
	}

	// --- output -------------------------------------------------------

	static function write(kind:String, detail:String):Void
	{
		var t:Float = (Lib.getTimer() - startedAt) / 1000;
		var stamp:String = StringTools.lpad(fmt(t), ' ', 9);
		var line:String = '[' + stamp + 's] ' + StringTools.rpad(kind, ' ', 10) + ' ' + detail + ' | ' + metrics();

		buffer.push(line);
		if (buffer.length >= MAX_BUFFERED)
			flush();
	}

	static function flush():Void
	{
		if (buffer.length == 0 || logPath.length == 0)
			return;

		try
		{
			var out = File.append(logPath, false);
			for (line in buffer)
				out.writeString(line + '\n');
			out.flush();
			out.close();
		}
		catch (e:Dynamic)
		{
			Sys.println('[PerfLogger] Failed to write perf.log: ' + Std.string(e));
		}

		buffer = [];
	}

	static function fmt(v:Float):String
	{
		var r:Float = Math.round(v * 10) / 10;
		var s:String = Std.string(r);
		if (s.indexOf('.') < 0)
			s += '.0';
		return s;
	}

	// --- header -------------------------------------------------------

	static function buildHeader():String
	{
		var h:String = 'Indie Cross performance log\n';
		h += 'date      : ' + Date.now().toString() + '\n';

		try
			h += 'version   : ' + Lib.application.meta['version'] + '\n'
		catch (e:Dynamic) {}

		#if android
		try
		{
			h += 'device    : ' + Build.MANUFACTURER + ' ' + Build.MODEL + '\n';
			h += 'soc       : ' + Build.HARDWARE + '\n';
			h += 'android   : SDK ' + VERSION.SDK_INT + ' (' + VERSION.RELEASE + ')\n';
		}
		catch (e:Dynamic) {}
		#end

		// Same GL query AstcSupport.check() already relies on; 0x1F00/0x1F01/
		// 0x1F02 are GL_VENDOR/GL_RENDERER/GL_VERSION.
		#if (android && cpp)
		try
		{
			h += 'gpu       : ' + lime.graphics.opengl.GL.getString(0x1F01) + '\n';
			h += 'gl        : ' + lime.graphics.opengl.GL.getString(0x1F02) + '\n';
			h += 'astc      : ' + (mobile.backend.AstcSupport.isSupported ? 'supported' : 'not supported') + '\n';
		}
		catch (e:Dynamic) {}
		#end

		try
		{
			h += 'window    : ' + FlxG.stage.stageWidth + 'x' + FlxG.stage.stageHeight + ' (game ' + FlxG.width + 'x' + FlxG.height + ')\n';
			h += 'framerate : update=' + FlxG.updateFramerate + ' draw=' + FlxG.drawFramerate + '\n';
		}
		catch (e:Dynamic) {}

		try
		{
			h += 'settings  : fpsCap=' + FlxG.save.data.fpsCap + ' highquality=' + FlxG.save.data.highquality + ' screenMode='
				+ FlxG.save.data.screenMode + ' render=' + FlxG.save.data.render + ' optimize=' + FlxG.save.data.optimize + ' photosensitive='
				+ FlxG.save.data.photosensitive + '\n';
		}
		catch (e:Dynamic) {}

		h += 'path      : ' + logPath + '\n';
		h += 'note      : mem=GC current, large=large-object only (what the on-screen MEM counter shows), reserved=taken from OS\n';
		h += '\n';
		return h;
	}
	#end
}
