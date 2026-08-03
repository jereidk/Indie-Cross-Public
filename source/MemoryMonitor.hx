package;

import cpp.vm.Gc;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;

// https://imgur.com/a/LVkQmqe
#if windows
@:headerCode("
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
// are you serious?? 
// do i have to include this after windows.h to not get outrageous compilation errors??????
// one side of my brains loves c++ and the other one hates it
")
#end
class MemoryMonitor extends TextField
{
	private var times:Array<Float>;
	private var memPeak:Float = 0;

	public function new(inX:Float = 10.0, inY:Float = 10.0, inCol:Int = 0x000000)
	{
		super();

		x = inX;
		y = inY;
		selectable = false;
		defaultTextFormat = new TextFormat("_sans", 24, inCol);

		addEventListener(Event.ENTER_FRAME, onEnter);
		width = 300;
		height = 140;
	}

	public function setSize(size:Float):Void
	{
		var currentColor:Int = textColor;
		defaultTextFormat = new TextFormat("_sans", Std.int(size), currentColor);
		setTextFormat(defaultTextFormat);

		// width/height are a fixed box (not auto-sizing), scaled here from
		// the same 150x70 @ 12px baseline the constructor used to hardcode,
		// so 3 lines of text (blank/MEM/MEM peak) don't get clipped at
		// bigger sizes.
		var scale:Float = size / 12;
		width = 150 * scale;
		height = 70 * scale;
	}

	private function onEnter(_)
	{
		#if windows
		// now be an ACTUAL real man and get the memory from plain & straight c++
		var actualMem:Float = obtainMemory();
		#else
		// be a real man and calculate memory from hxcpp
		var actualMem:Float = Gc.memInfo64(3); // update: this sucks
		#end
		var mem:Float = Math.round(actualMem / 1024 / 1024 * 100) / 100;
		if (mem > memPeak)
			memPeak = mem;

		if (visible)
		{
			text = "\nMEM: " + mem + " MB\nMEM peak: " + memPeak + " MB";
		}
	}

	#if windows // planning to do the same for linux but im lazy af so rn it'll use the hxcpp gc
	@:functionCode("
		// ily windows api <3
		auto memhandle = GetCurrentProcess();
		PROCESS_MEMORY_COUNTERS pmc;

		if (GetProcessMemoryInfo(memhandle, &pmc, sizeof(pmc)))
			return(pmc.WorkingSetSize);
		else
			return 0;
	")
	function obtainMemory():Dynamic
	{
		return 0;
	}
	#end
}
