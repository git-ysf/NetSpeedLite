package com.netspeedlite.android;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;

/**
 * Manages Light/Dark/System theme modes, accent color themes, and user preferences.
 */
public final class ThemeManager {

    private static final String PREFS_NAME = "netspeedlite_prefs";
    private static final String KEY_THEME_MODE = "theme_mode";
    private static final String KEY_ACCENT_THEME = "accent_theme";
    private static final String KEY_USE_BITS = "use_bits";
    private static final String KEY_AUTO_START = "auto_start";

    public enum ThemeMode {
        SYSTEM("System"),
        DARK("Dark"),
        LIGHT("Light");

        public final String label;

        ThemeMode(String label) {
            this.label = label;
        }
    }

    public enum AccentTheme {
        CYAN("Cyan", 0xFF38BDF8, 0xFF34D399, 0xFF0284C7, 0xFF059669),
        EMERALD("Emerald", 0xFF10B981, 0xFF60A5FA, 0xFF059669, 0xFF2563EB),
        AMBER("Amber", 0xFFF59E0B, 0xFF38BDF8, 0xFFD97706, 0xFF0284C7),
        VIOLET("Violet", 0xFFA78BFA, 0xFF2DD4BF, 0xFF7C3AED, 0xFF0D9488);

        public final String label;
        public final int darkDownload;
        public final int darkUpload;
        public final int lightDownload;
        public final int lightUpload;

        AccentTheme(String label, int darkDownload, int darkUpload, int lightDownload, int lightUpload) {
            this.label = label;
            this.darkDownload = darkDownload;
            this.darkUpload = darkUpload;
            this.lightDownload = lightDownload;
            this.lightUpload = lightUpload;
        }
    }

    public static final class Palette {
        public final boolean isDark;
        public final int background;
        public final int surface;
        public final int surfaceAlt;
        public final int border;
        public final int textPrimary;
        public final int textSecondary;
        public final int downloadColor;
        public final int uploadColor;
        public final int accentColor;
        public final int gridColor;
        public final int statusActiveBg;
        public final int statusActiveText;
        public final int statusPausedBg;
        public final int statusPausedText;

        private Palette(boolean isDark, AccentTheme accent) {
            this.isDark = isDark;
            if (isDark) {
                this.background = 0xFF0D1117;
                this.surface = 0xFF161B22;
                this.surfaceAlt = 0xFF21262D;
                this.border = 0xFF30363D;
                this.textPrimary = 0xFFF0F6FC;
                this.textSecondary = 0xFF8B949E;
                this.downloadColor = accent.darkDownload;
                this.uploadColor = accent.darkUpload;
                this.accentColor = accent.darkDownload;
                this.gridColor = 0x22FFFFFF;
                this.statusActiveBg = 0xFF132F24;
                this.statusActiveText = 0xFF34D399;
                this.statusPausedBg = 0xFF2D221B;
                this.statusPausedText = 0xFFF59E0B;
            } else {
                this.background = 0xFFF4F6F9;
                this.surface = 0xFFFFFFFF;
                this.surfaceAlt = 0xFFEBF0F5;
                this.border = 0xFFD0D7DE;
                this.textPrimary = 0xFF1F2328;
                this.textSecondary = 0xFF57606A;
                this.downloadColor = accent.lightDownload;
                this.uploadColor = accent.lightUpload;
                this.accentColor = accent.lightDownload;
                this.gridColor = 0x1A000000;
                this.statusActiveBg = 0xFFDCFCE7;
                this.statusActiveText = 0xFF15803D;
                this.statusPausedBg = 0xFFFEF3C7;
                this.statusPausedText = 0xFFB45309;
            }
        }
    }

    private ThemeManager() {
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    public static ThemeMode getThemeMode(Context context) {
        String name = prefs(context).getString(KEY_THEME_MODE, ThemeMode.SYSTEM.name());
        try {
            return ThemeMode.valueOf(name);
        } catch (IllegalArgumentException e) {
            return ThemeMode.SYSTEM;
        }
    }

    public static void setThemeMode(Context context, ThemeMode mode) {
        prefs(context).edit().putString(KEY_THEME_MODE, mode.name()).apply();
    }

    public static AccentTheme getAccentTheme(Context context) {
        String name = prefs(context).getString(KEY_ACCENT_THEME, AccentTheme.CYAN.name());
        try {
            return AccentTheme.valueOf(name);
        } catch (IllegalArgumentException e) {
            return AccentTheme.CYAN;
        }
    }

    public static void setAccentTheme(Context context, AccentTheme accent) {
        prefs(context).edit().putString(KEY_ACCENT_THEME, accent.name()).apply();
    }

    public static boolean isUseBits(Context context) {
        return prefs(context).getBoolean(KEY_USE_BITS, false);
    }

    public static void setUseBits(Context context, boolean useBits) {
        prefs(context).edit().putBoolean(KEY_USE_BITS, useBits).apply();
    }

    public static boolean isAutoStartEnabled(Context context) {
        return prefs(context).getBoolean(KEY_AUTO_START, false);
    }

    public static void setAutoStartEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_AUTO_START, enabled).apply();
    }

    public static Palette resolvePalette(Context context) {
        ThemeMode mode = getThemeMode(context);
        boolean isDark;
        if (mode == ThemeMode.DARK) {
            isDark = true;
        } else if (mode == ThemeMode.LIGHT) {
            isDark = false;
        } else {
            int nightMask = context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
            isDark = (nightMask == Configuration.UI_MODE_NIGHT_YES);
        }
        return new Palette(isDark, getAccentTheme(context));
    }
}
