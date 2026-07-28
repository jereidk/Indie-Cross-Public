package mobile.backend;

typedef ResolvedAddress =
{
	var funcName:String;
	var file:Null<String>;
	var line:Null<Int>;
}

/**
 * Loads the per-ABI symbol file (assets/data/symbols-{arm64,armv7}.sym,
 * meant to be generated at build time by a dump_syms-based CI step -- not
 * yet wired up for this project, see Phase 3 of the Logger/crash-handler
 * port) and resolves a batch of native_crash_trace.log rel_pc offsets to
 * function name + file:line.
 *
 * Read via JavaCrashHandler.readRawTextAsset() (Android's AssetManager
 * directly), not openfl.Assets -- see that function's doc comment for why
 * OpenFL's own asset system can't see this file.
 *
 * The .sym file is Breakpad's own plain-text symbol format (see
 * https://chromium.googlesource.com/breakpad/breakpad/+/master/docs/symbol_files.md),
 * a handful of record types this parser cares about:
 *   FUNC <addr_hex> <size_hex> <param_size_hex> <name>   -- a function's
 *     exact address range.
 *   <addr_hex> <size_hex> <line_dec> <filenum_dec>        -- a "bare" line
 *     record (no keyword), attributed to the most recent FUNC, refining a
 *     sub-range of it down to a source file:line.
 *   FILE <number> <path>                                  -- maps a line
 *     record's filenum to a real source path.
 *
 * A SINGLE PASS over the whole file resolves an entire batch of target
 * addresses at once (see resolveBatch()) -- deliberately NOT building a
 * full in-memory index of the file's records first: this file is tens of
 * MB of text, and a batch is always small (one call per crash trace,
 * targeting at most the crashing thread's own unresolved frames), so a
 * rolling "current FUNC" cursor plus a small target-address check per line
 * is both simpler to get right without a local compiler to test against,
 * and far cheaper in memory than materializing every record.
 *
 * Ported from NightmareVision-Android-Support's mobile.backend.SymbolResolver.
 */
class SymbolResolver
{
	static var _content:Null<String> = null;
	static var _loadAttempted:Bool = false;

	/**
	 * Resolves a batch of rel_pc offsets (all from the same crashing
	 * thread/trace) against the given ABI's symbol file in a single pass.
	 * Missing entries in the returned map mean that address couldn't be
	 * resolved (no matching FUNC range, asset missing, parse failure, ...)
	 * -- never throws.
	 */
	public static function resolveBatch(targets:Array<Int>, abi:Null<String>):Map<Int, ResolvedAddress>
	{
		final result = new Map<Int, ResolvedAddress>();
		if (targets.length == 0) return result;

		#if (android && sys)
		if (!ensureLoaded(abi)) return result;

		try
		{
			final content = _content;
			if (content == null) return result;

			final fileNames = new Map<Int, String>();

			var curFuncName:Null<String> = null;
			var inFuncBody = false;

			var pos = 0;
			final len = content.length;
			while (pos < len)
			{
				var nl = content.indexOf('\n', pos);
				if (nl < 0) nl = len;
				var line = content.substring(pos, nl);
				pos = nl + 1;

				// tolerate CRLF line endings
				if (line.length > 0 && line.charCodeAt(line.length - 1) == '\r'.code)
					line = line.substr(0, line.length - 1);

				if (line.length == 0) continue;

				if (StringTools.startsWith(line, 'FILE '))
				{
					inFuncBody = false;
					final rest = line.substr(5);
					final sp = rest.indexOf(' ');
					if (sp > 0)
					{
						final num = Std.parseInt(rest.substring(0, sp));
						if (num != null) fileNames.set(num, rest.substr(sp + 1));
					}
					continue;
				}

				if (StringTools.startsWith(line, 'FUNC '))
				{
					final parsed = parseFuncLine(line.substr(5));
					if (parsed == null)
					{
						inFuncBody = false;
						continue;
					}

					inFuncBody = true;
					curFuncName = parsed.name;
					final funcEnd = parsed.addr + parsed.size;

					// Fallback: even if no line record below ever narrows
					// this further, we at least know which function a
					// target address belongs to.
					for (t in targets)
					{
						if (t >= parsed.addr && t < funcEnd && !result.exists(t))
							result.set(t, {funcName: parsed.name, file: null, line: null});
					}
					continue;
				}

				// MODULE/PUBLIC/INFO/STACK -- not a bare line record, and
				// resets whatever FUNC body we thought we were in.
				if (StringTools.startsWith(line, 'MODULE ')
					|| StringTools.startsWith(line, 'PUBLIC ')
					|| StringTools.startsWith(line, 'INFO ')
					|| StringTools.startsWith(line, 'STACK '))
				{
					inFuncBody = false;
					continue;
				}

				if (!inFuncBody || curFuncName == null) continue;

				final lineRec = parseLineRecord(line);
				if (lineRec == null) continue;

				final lineEnd = lineRec.addr + lineRec.size;
				for (t in targets)
				{
					if (t >= lineRec.addr && t < lineEnd)
					{
						result.set(t, {
							funcName: curFuncName,
							file: fileNames.get(lineRec.fileNum),
							line: lineRec.lineNum
						});
					}
				}
			}

			return result;
		}
		catch (e:Dynamic)
		{
			return result;
		}
		#else
		return result;
		#end
	}

	#if (android && sys)
	/**
	 * Loads (once) and caches the raw .sym text content for the given ABI.
	 * Safe to call repeatedly -- only the first call does any work.
	 */
	static function ensureLoaded(abi:Null<String>):Bool
	{
		if (_content != null) return true;
		if (_loadAttempted) return false;
		_loadAttempted = true;

		try
		{
			final mapped = mapAbi(abi);
			if (mapped == null) return false;

			// Read via JavaCrashHandler's AssetManager-backed reader, not
			// openfl.Assets -- this file is meant to be written into
			// src/main/assets/ by a CI step that runs AFTER Lime's own asset
			// manifest is already finalized, so OpenFL's Assets.exists()/
			// getContent() would never see it even though it's genuinely
			// inside the APK (see JavaCrashHandler.java's readRawTextAsset()
			// doc comment).
			final path = 'data/symbols-$mapped.sym';
			final content = mobile.backend.JavaCrashHandler.readRawTextAsset(path);
			if (content == null || content.length == 0) return false;

			_content = content;
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	/**
	 * Parses a FUNC record's fields after the leading "FUNC " keyword:
	 * "[m] <addr_hex> <size_hex> <param_size_hex> <name>" -- name extends
	 * to end of line and may itself contain spaces (a demangled C++
	 * signature routinely does), so it's taken as everything after the
	 * third space rather than split on whitespace.
	 */
	static function parseFuncLine(rest0:String):Null<{addr:Int, size:Int, name:String}>
	{
		var rest = rest0;
		if (StringTools.startsWith(rest, 'm ')) rest = rest.substr(2);

		final sp1 = rest.indexOf(' ');
		if (sp1 < 0) return null;
		final addrHex = rest.substring(0, sp1);
		rest = rest.substr(sp1 + 1);

		final sp2 = rest.indexOf(' ');
		if (sp2 < 0) return null;
		final sizeHex = rest.substring(0, sp2);
		rest = rest.substr(sp2 + 1);

		final sp3 = rest.indexOf(' ');
		if (sp3 < 0) return null;
		final name = rest.substr(sp3 + 1);

		final addr = Std.parseInt('0x' + addrHex);
		final size = Std.parseInt('0x' + sizeHex);
		if (addr == null || size == null) return null;

		return {addr: addr, size: size, name: name};
	}

	/**
	 * Parses a bare line record: "<addr_hex> <size_hex> <line_dec> <filenum_dec>".
	 * No trailing free-text field, so plain space-splitting is safe here.
	 */
	static function parseLineRecord(line:String):Null<{addr:Int, size:Int, lineNum:Int, fileNum:Int}>
	{
		final sp1 = line.indexOf(' ');
		if (sp1 < 0) return null;
		final addrHex = line.substring(0, sp1);
		var rest = line.substr(sp1 + 1);

		final sp2 = rest.indexOf(' ');
		if (sp2 < 0) return null;
		final sizeHex = rest.substring(0, sp2);
		rest = rest.substr(sp2 + 1);

		final sp3 = rest.indexOf(' ');
		if (sp3 < 0) return null;
		final lineDec = rest.substring(0, sp3);
		final fileDec = rest.substr(sp3 + 1);

		final addr = Std.parseInt('0x' + addrHex);
		final size = Std.parseInt('0x' + sizeHex);
		final lineNum = Std.parseInt(lineDec);
		final fileNum = Std.parseInt(fileDec);
		if (addr == null || size == null || lineNum == null || fileNum == null) return null;

		return {addr: addr, size: size, lineNum: lineNum, fileNum: fileNum};
	}

	/**
	 * Maps Android's own Build.SUPPORTED_ABIS[0] naming (what actually gets
	 * stamped into a trace file's "abi=" header field) to this project's own
	 * symbol file suffix. Returns null for anything not shipped (x86, etc.)
	 * or unrecognized.
	 */
	static function mapAbi(abi:Null<String>):Null<String>
	{
		if (abi == null) return null;
		if (abi.indexOf('arm64') == 0) return 'arm64';
		if (abi.indexOf('armeabi') == 0) return 'armv7';
		return null;
	}
	#end
}
