package;

import flixel.FlxG;
import Sys.sleep;

using StringTools;

#if desktop
import discord_rpc.DiscordRpc;
#elseif android
import mobile.backend.AndroidRPC;
#end

class DiscordClient
{
	public function new()
	{
		#if desktop
		trace("Discord Client starting...");
		DiscordRpc.start({
			clientID: "858855876760043560",
			onReady: onReady,
			onError: onError,
			onDisconnected: onDisconnected
		});
		trace("Discord Client started.");

		while (true)
		{
			DiscordRpc.process();
			sleep(2);
		}

		DiscordRpc.shutdown();
		#end
	}

	public static function shutdown()
	{
		#if desktop
		trace('shuttin');
		DiscordRpc.shutdown();
		#elseif android
		AndroidRPC.shutdown();
		#end
	}

	static function onReady()
	{
		#if desktop
		DiscordRpc.presence({
			details: "In the Menus",
			state: null,
			largeImageKey: 'icon',
			largeImageText: "Artwork by IkuAldena"
		});
		#end
	}

	static function onError(_code:Int, _message:String)
	{
		trace('Error! $_code : $_message');
	}

	static function onDisconnected(_code:Int, _message:String)
	{
		trace('Disconnected! $_code : $_message');
	}

	public static function initialize()
	{
		#if desktop
		var DiscordDaemon = sys.thread.Thread.create(() ->
		{
			new DiscordClient();
		});
		trace("Discord Client initialized");
		#elseif android
		// No Discord IPC socket exists on Android -- this drives a local
		// MediaSession-backed notification instead, which a separate app the
		// player installs themselves (Kizzy, github.com/dead8309/Kizzy) can
		// relay to their Discord account. See AndroidRPC.hx/KizzyHelper.java.
		AndroidRPC.initialize();
		#end
	}

	public static function changePresence(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float)
	{
		#if desktop
		var startTimestamp:Float = if (hasStartTimestamp) Date.now().getTime() else 0;

		if (endTimestamp > 0)
		{
			endTimestamp = startTimestamp + endTimestamp;
		}

		// poly is stupid 🙄 -- stfu u piece of shit

		/*
			if (Type.getClass(FlxG.state) == PlayState)
			{
				if (details.contains(PlayState.instance.storyDifficultyText))
				{
					if (details.contains(PlayState.SONG.song))
					{
						details = 'CONFIDENTIAL [' + PlayState.instance.storyDifficultyText + ']';
					}
				}
			}
			else
			{
				trace('aw hell naw im not on playstate');

				if (details.contains('Freeplay - Listening to '))
				{
					details = 'Freeplay - [CONFIDENTIAL]';
				}
			}
		 */

		DiscordRpc.presence({
			details: details,
			state: state,
			largeImageKey: 'icon',
			largeImageText: "Artwork by IkuAldena",
			smallImageKey: smallImageKey,
			startTimestamp: Std.int(startTimestamp / 1000),
			endTimestamp: Std.int(endTimestamp / 1000)
		});
		#elseif android
		// smallImageKey (a Discord asset-key string on desktop, e.g. "bf") has
		// no Android equivalent here -- ignored, see AndroidRPC.hx's own doc
		// comment. hasStartTimestamp maps onto isPlaying; without a real song
		// duration available at every call site, position/duration are left
		// at 0 (no progress bar) rather than guessing one from endTimestamp
		// alone.
		AndroidRPC.update(details, state, hasStartTimestamp == true);
		#end
	}
}
