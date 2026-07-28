package mobile.backend.java;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.os.Build;
import org.haxe.extension.Extension;

/**
 * Small set of Android-specific window/hardware queries that don't fit
 * anywhere else. Ported (minimal subset) from NightmareVision-Android-
 * Support's mobile.backend.java.AndroidUtils -- only the four methods this
 * project actually has a use for; the rest of that class (fullscreen mode
 * toggling, mod-folder scanning/opening, app restart) belongs to a mods/DLC
 * system this project doesn't have.
 */
public class AndroidUtils extends Extension {

    /**
     * Signals Android's GameManager what state the app is in (API 33+ only).
     * true  -> MODE_GAMEPLAY_INTERRUPTIBLE (active gameplay)
     * false -> MODE_NONE (menus, pause, loading)
     * Lets the OS make better performance/thermal scheduling decisions
     * (Android's "Game Mode"). Silent no-op on API < 33 or if the call fails.
     */
    public static void setGameplayState(final boolean inGameplay) {
        if (Build.VERSION.SDK_INT < 33) return;
        final Activity activity = mainActivity;
        if (activity == null) return;
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Object gm = activity.getSystemService(Context.GAME_SERVICE);
                    if (gm == null) return;
                    // Reflection instead of a compile-time android.app.GameManager/
                    // GameState reference -- keeps this compiling against any
                    // compileSdkVersion, same reasoning as JavaCrashHandler's
                    // ApplicationExitInfo reflection use.
                    Class<?> gameStateClass = Class.forName("android.app.GameState");
                    // GameState(boolean isLoading, int mode) -- API 33 GameState mode
                    // literals: MODE_UNKNOWN=0, MODE_NONE=1, MODE_GAMEPLAY_INTERRUPTIBLE=2
                    Object gameState = gameStateClass
                        .getConstructor(boolean.class, int.class)
                        .newInstance(false, inGameplay ? 2 : 1);
                    gm.getClass()
                        .getMethod("setGameState", gameStateClass)
                        .invoke(gm, gameState);
                } catch (Exception e) {
                    android.util.Log.w("AndroidUtils", "setGameplayState: " + e);
                }
            }
        });
    }

    /**
     * The highest refresh rate (Hz) any display mode the screen supports
     * offers. Android always reports 60 here unless requestHighRefreshRate()
     * has been called (the OS defaults to 60Hz even on 90/120Hz-capable
     * panels until an app explicitly opts in), so call that first if you
     * want this to reflect what the hardware can actually do.
     */
    public static float getMaxRefreshRate() {
        final Activity activity = mainActivity;
        if (activity == null) return 60f;

        try {
            android.view.Display display = getDisplay(activity);
            if (display == null) return 60f;

            float maxRate = display.getRefreshRate();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                for (android.view.Display.Mode mode : display.getSupportedModes()) {
                    if (mode.getRefreshRate() > maxRate) maxRate = mode.getRefreshRate();
                }
            }
            return maxRate;
        } catch (Exception e) {
            android.util.Log.e("AndroidUtils", "getMaxRefreshRate failed: " + e);
            return 60f;
        }
    }

    /**
     * Opts the window into its highest supported display refresh rate mode.
     * Android defaults every app to 60Hz regardless of the panel's real
     * capability until this is requested -- for a rhythm game, that caps
     * visual smoothness (and the perceived precision of hitting notes) on
     * every 90/120Hz-capable device for no reason. Call once, early at
     * startup; doesn't persist itself, so it needs requesting again on
     * every launch.
     */
    public static void requestHighRefreshRate() {
        final Activity activity = mainActivity;
        if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;

        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    android.view.Display display = getDisplay(activity);
                    if (display == null) return;

                    android.view.Display.Mode best = display.getMode();
                    for (android.view.Display.Mode mode : display.getSupportedModes()) {
                        if (mode.getRefreshRate() > best.getRefreshRate()) best = mode;
                    }

                    android.view.WindowManager.LayoutParams params = activity.getWindow().getAttributes();
                    params.preferredDisplayModeId = best.getModeId();
                    activity.getWindow().setAttributes(params);
                } catch (Exception e) {
                    android.util.Log.e("AndroidUtils", "requestHighRefreshRate failed: " + e);
                }
            }
        });
    }

    /**
     * Whether the OS currently reports a hardware keyboard attached
     * (USB/Bluetooth) -- Configuration.keyboard is NOKEYS on a touch-only
     * device with nothing plugged in, QWERTY/12KEY once one is connected.
     * The on-screen soft keyboard and the game's own virtual pad don't
     * affect this value at all, which is exactly what's needed here:
     * neither can generate the physical key press a keybind rebind needs.
     */
    public static boolean hasPhysicalKeyboard() {
        final Activity activity = mainActivity;
        if (activity == null) return false;
        try {
            return activity.getResources().getConfiguration().keyboard != Configuration.KEYBOARD_NOKEYS;
        } catch (Exception e) {
            android.util.Log.e("AndroidUtils", "hasPhysicalKeyboard failed: " + e);
            return false;
        }
    }

    /**
     * Whether the app currently holds the special "All files access"
     * permission (API 30+; always true before that -- scoped storage,
     * the whole reason this permission exists, doesn't apply pre-30).
     * WRITE_EXTERNAL_STORAGE/READ_EXTERNAL_STORAGE alone do NOT grant this
     * on Android 11+: without it, writes to
     * Environment.getExternalStorageDirectory() (SUtil.getPath()'s folder)
     * silently fail every time, which is what this method exists to detect.
     */
    public static boolean isExternalStorageManager() {
        if (Build.VERSION.SDK_INT < 30) return true;
        try {
            return android.os.Environment.isExternalStorageManager();
        } catch (Exception e) {
            android.util.Log.e("AndroidUtils", "isExternalStorageManager failed: " + e);
            return false;
        }
    }

    /**
     * Launches Android's own "All files access" settings screen for this
     * app (API 30+ no-op otherwise). A separate Activity -- doesn't block
     * the caller; boot continues underneath it, and the player can back out
     * without granting anything (in which case isExternalStorageManager()
     * keeps reporting false and SUtil.getPath()'s writes keep failing the
     * same way they always have -- this only ever adds a way to fix that,
     * never removes the previous silent-failure behavior).
     */
    public static void requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < 30) return;
        final Activity activity = mainActivity;
        if (activity == null) return;
        try {
            android.content.Intent intent = new android.content.Intent(
                android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                android.net.Uri.parse("package:" + activity.getPackageName()));
            activity.startActivity(intent);
        } catch (Exception e) {
            android.util.Log.e("AndroidUtils", "requestAllFilesAccess failed: " + e);
            // Some OEMs/emulators don't support the per-app deep link -- fall
            // back to the general "All files access" management screen.
            try {
                activity.startActivity(new android.content.Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
            } catch (Exception e2) {
                android.util.Log.e("AndroidUtils", "requestAllFilesAccess fallback failed: " + e2);
            }
        }
    }

    private static android.view.Display getDisplay(Activity activity) {
        if (Build.VERSION.SDK_INT >= 30) {
            return activity.getDisplay();
        }
        return activity.getWindowManager().getDefaultDisplay();
    }
}
