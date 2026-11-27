package com.netspeedlite.android;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.drawable.Icon;

import java.util.Locale;

/**
 * Formats network speeds, byte totals, and renders live status-bar speed icons.
 */
public final class SpeedFormatter {

    private SpeedFormatter() {
    }

    public static final class FormattedSpeed {
        public final String value;
        public final String unit;

        public FormattedSpeed(String value, String unit) {
            this.value = value;
            this.unit = unit;
        }

        public String full() {
            return value + " " + unit;
        }
    }

    /**
     * Formats a rate given in bytes per second into either Bytes/s or Bits/s.
     */
    public static FormattedSpeed formatRate(long bytesPerSec, boolean useBits) {
        long clamped = Math.max(0L, bytesPerSec);
        if (useBits) {
            double bits = clamped * 8.0;
            if (bits < 1000.0) {
                return new FormattedSpeed(String.format(Locale.US, "%.0f", bits), "bps");
            } else if (bits < 1_000_000.0) {
                return new FormattedSpeed(formatCompact(bits / 1000.0), "Kbps");
            } else if (bits < 1_000_000_000.0) {
                return new FormattedSpeed(formatCompact(bits / 1_000_000.0), "Mbps");
            } else {
                return new FormattedSpeed(formatCompact(bits / 1_000_000_000.0), "Gbps");
            }
        } else {
            if (clamped < 1024L) {
                return new FormattedSpeed(String.valueOf(clamped), "B/s");
            } else if (clamped < 1024L * 1024L) {
                return new FormattedSpeed(formatCompact(clamped / 1024.0), "KB/s");
            } else if (clamped < 1024L * 1024L * 1024L) {
                return new FormattedSpeed(formatCompact(clamped / (1024.0 * 1024.0)), "MB/s");
            } else {
                return new FormattedSpeed(formatCompact(clamped / (1024.0 * 1024.0 * 1024.0)), "GB/s");
            }
        }
    }

    /**
     * Formats cumulative byte count into a human-readable string.
     */
    public static String formatBytes(long bytes) {
        long clamped = Math.max(0L, bytes);
        if (clamped < 1024L) {
            return clamped + " B";
        } else if (clamped < 1024L * 1024L) {
            return formatCompact(clamped / 1024.0) + " KB";
        } else if (clamped < 1024L * 1024L * 1024L) {
            return formatCompact(clamped / (1024.0 * 1024.0)) + " MB";
        } else {
            return String.format(Locale.US, "%.2f GB", clamped / (1024.0 * 1024.0 * 1024.0));
        }
    }

    private static String formatCompact(double val) {
        if (val >= 100.0) {
            return String.format(Locale.US, "%.0f", val);
        } else if (val >= 10.0) {
            return String.format(Locale.US, "%.1f", val);
        } else {
            return String.format(Locale.US, "%.2f", val);
        }
    }

    /**
     * Renders a crisp 96x96 monochrome status-bar icon displaying the current speed.
     */
    public static Icon createSpeedNotificationIcon(long totalBytesPerSec, boolean useBits) {
        FormattedSpeed speed = formatRate(totalBytesPerSec, useBits);
        String topText = speed.value;
        if (topText.length() > 4) {
            topText = topText.substring(0, 4);
        }
        String bottomText = speed.unit;

        final int size = 96;
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        Paint valuePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        valuePaint.setColor(Color.WHITE);
        valuePaint.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        valuePaint.setTextAlign(Paint.Align.CENTER);
        valuePaint.setTextSize(topText.length() <= 3 ? 42f : 34f);

        Paint unitPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        unitPaint.setColor(Color.WHITE);
        unitPaint.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        unitPaint.setTextAlign(Paint.Align.CENTER);
        unitPaint.setTextSize(26f);

        canvas.drawText(topText, size / 2f, 46f, valuePaint);
        canvas.drawText(bottomText, size / 2f, 82f, unitPaint);

        return Icon.createWithBitmap(bitmap);
    }
}
