package mobile.backend.java;

import android.app.Activity;
import android.graphics.Rect;
import android.os.Build;
import android.view.Display;
import android.view.DisplayCutout;
import android.view.View;
import android.view.WindowInsets;
import org.haxe.extension.Extension;

import java.util.List;

/**
 * Reports display cutout (notch/punch-hole) information for Android devices.
 * Ported from NightmareVision-Android-Support (which follows FunkinCrew/Funkin's
 * own cutout-detection pattern).
 */
public class ScreenUtil extends Extension {

    private static int cachedTop    = -1;
    private static int cachedBottom =  0;
    private static int cachedLeft   =  0;
    private static int cachedRight  =  0;

    private static void ensureCached() {
        if (cachedTop >= 0) return;

        cachedTop = 0;

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return;

        Activity activity = mainActivity;
        if (activity == null) return;

        try {
            View decorView = activity.getWindow().getDecorView();
            WindowInsets windowInsets = decorView.getRootWindowInsets();
            if (windowInsets == null) return;

            DisplayCutout cutout = windowInsets.getDisplayCutout();
            if (cutout == null) return;

            float density = activity.getResources().getDisplayMetrics().density;
            if (density <= 0f) density = 1f;

            // Use safe insets for compatibility
            cachedTop    = Math.round(cutout.getSafeInsetTop()    / density);
            cachedBottom = Math.round(cutout.getSafeInsetBottom() / density);
            cachedLeft   = Math.round(cutout.getSafeInsetLeft()   / density);
            cachedRight  = Math.round(cutout.getSafeInsetRight()  / density);
        } catch (Exception e) {
            // Graceful fallback — zeros remain.
        }
    }

    /**
     * Returns array of cutout bounding rectangles.
     * Each rect is [x, y, width, height] in pixels.
     */
    public static float[][] getCutoutDimensions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return new float[0][0];
        }

        Activity activity = mainActivity;
        if (activity == null) return new float[0][0];

        try {
            View decorView = activity.getWindow().getDecorView();
            WindowInsets windowInsets = decorView.getRootWindowInsets();
            if (windowInsets == null) return new float[0][0];

            DisplayCutout cutout = windowInsets.getDisplayCutout();
            if (cutout == null) return new float[0][0];

            List<Rect> boundingRects = cutout.getBoundingRects();
            if (boundingRects == null || boundingRects.isEmpty()) {
                return new float[0][0];
            }

            float density = activity.getResources().getDisplayMetrics().density;
            if (density <= 0f) density = 1f;

            float[][] result = new float[boundingRects.size()][4];
            for (int i = 0; i < boundingRects.size(); i++) {
                Rect rect = boundingRects.get(i);
                result[i][0] = Math.round(rect.left / density);
                result[i][1] = Math.round(rect.top / density);
                result[i][2] = Math.round(rect.width() / density);
                result[i][3] = Math.round(rect.height() / density);
            }
            return result;
        } catch (Exception e) {
            return new float[0][0];
        }
    }

    public static int getSafeInsetTop()    { ensureCached(); return cachedTop;    }
    public static int getSafeInsetBottom() { ensureCached(); return cachedBottom; }
    public static int getSafeInsetLeft()   { ensureCached(); return cachedLeft;   }
    public static int getSafeInsetRight()  { ensureCached(); return cachedRight;  }

    /**
     * The display's CURRENTLY ACTIVE refresh rate in Hz -- not a cached
     * value, queried fresh every call, so it reflects a refresh-rate switch
     * the user makes in Android's own display settings (60/90/120Hz etc.)
     * while the game is already running. getDefaultDisplay() is deprecated
     * on API 30+ but still functional there; not worth a second codepath
     * through Activity.getDisplay() (API 30+ only) just to silence that.
     */
    public static float getRefreshRate() {
        try {
            Activity activity = mainActivity;
            if (activity == null) return 60f;

            Display display = activity.getWindowManager().getDefaultDisplay();
            if (display == null) return 60f;

            float rate = display.getRefreshRate();
            return rate > 0f ? rate : 60f;
        } catch (Exception e) {
            return 60f;
        }
    }
}
