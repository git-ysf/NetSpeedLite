package com.netspeedlite.android;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;
import android.view.View;

/**
 * Lightweight custom View rendering a real-time dual-series throughput sparkline.
 */
public class SparklineView extends View {

    private static final long MIN_SCALE_BYTES = 64L * 1024L; // 64 KB/s floor

    private long[] rxSamples = new long[0];
    private long[] txSamples = new long[0];
    private boolean useBits = false;

    private int downloadColor = 0xFF38BDF8;
    private int uploadColor = 0xFF34D399;
    private int gridColor = 0x22FFFFFF;
    private int labelColor = 0xFF8B949E;

    private final Paint gridPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint labelPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rxLinePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rxFillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint txLinePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint dotPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final Path rxPath = new Path();
    private final Path rxFillPath = new Path();
    private final Path txPath = new Path();

    public SparklineView(Context context) {
        super(context);
        float density = context.getResources().getDisplayMetrics().density;

        gridPaint.setStyle(Paint.Style.STROKE);
        gridPaint.setStrokeWidth(1f * density);

        labelPaint.setTextSize(10.5f * density);

        rxLinePaint.setStyle(Paint.Style.STROKE);
        rxLinePaint.setStrokeWidth(2.2f * density);
        rxLinePaint.setStrokeCap(Paint.Cap.ROUND);
        rxLinePaint.setStrokeJoin(Paint.Join.ROUND);

        rxFillPaint.setStyle(Paint.Style.FILL);

        txLinePaint.setStyle(Paint.Style.STROKE);
        txLinePaint.setStrokeWidth(1.8f * density);
        txLinePaint.setStrokeCap(Paint.Cap.ROUND);
        txLinePaint.setStrokeJoin(Paint.Join.ROUND);

        dotPaint.setStyle(Paint.Style.FILL);
    }

    public void applyPalette(ThemeManager.Palette palette) {
        this.downloadColor = palette.downloadColor;
        this.uploadColor = palette.uploadColor;
        this.gridColor = palette.gridColor;
        this.labelColor = palette.textSecondary;

        gridPaint.setColor(gridColor);
        labelPaint.setColor(labelColor);
        rxLinePaint.setColor(downloadColor);
        txLinePaint.setColor(uploadColor);
        invalidate();
    }

    public void setData(long[] rxHistory, long[] txHistory, boolean useBits) {
        this.rxSamples = rxHistory != null ? rxHistory : new long[0];
        this.txSamples = txHistory != null ? txHistory : new long[0];
        this.useBits = useBits;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        int w = getWidth();
        int h = getHeight();
        if (w <= 0 || h <= 0) {
            return;
        }

        float density = getResources().getDisplayMetrics().density;
        float padTop = 14f * density;
        float padBottom = 8f * density;
        float padLeft = 4f * density;
        float padRight = 4f * density;

        float chartW = Math.max(1f, w - padLeft - padRight);
        float chartH = Math.max(1f, h - padTop - padBottom);

        long maxVal = MIN_SCALE_BYTES;
        for (long v : rxSamples) {
            if (v > maxVal) maxVal = v;
        }
        for (long v : txSamples) {
            if (v > maxVal) maxVal = v;
        }
        // Add 15% headroom
        double scaleMax = maxVal * 1.15;

        // Draw 3 horizontal grid lines (top, mid, bottom)
        for (int i = 0; i <= 2; i++) {
            float y = padTop + (chartH * i / 2f);
            canvas.drawLine(padLeft, y, w - padRight, y, gridPaint);
        }

        // Draw max scale label at top-left
        String maxLabel = SpeedFormatter.formatRate((long) scaleMax, useBits).full();
        canvas.drawText(maxLabel, padLeft + 4f * density, padTop - 3f * density, labelPaint);

        int count = Math.min(rxSamples.length, txSamples.length);
        if (count < 2) {
            return;
        }

        rxPath.reset();
        rxFillPath.reset();
        txPath.reset();

        float stepX = chartW / Math.max(1, count - 1);
        float lastRxX = padLeft;
        float lastRxY = padTop + chartH;
        float lastTxX = padLeft;
        float lastTxY = padTop + chartH;

        for (int i = 0; i < count; i++) {
            float x = padLeft + i * stepX;
            float rxY = (float) (padTop + chartH - (Math.min(rxSamples[i], scaleMax) / scaleMax) * chartH);
            float txY = (float) (padTop + chartH - (Math.min(txSamples[i], scaleMax) / scaleMax) * chartH);

            if (i == 0) {
                rxPath.moveTo(x, rxY);
                rxFillPath.moveTo(x, padTop + chartH);
                rxFillPath.lineTo(x, rxY);
                txPath.moveTo(x, txY);
            } else {
                float prevX = padLeft + (i - 1) * stepX;
                float midX = (prevX + x) * 0.5f;
                rxPath.cubicTo(midX, lastRxY, midX, rxY, x, rxY);
                rxFillPath.cubicTo(midX, lastRxY, midX, rxY, x, rxY);
                txPath.cubicTo(midX, lastTxY, midX, txY, x, txY);
            }

            lastRxX = x;
            lastRxY = rxY;
            lastTxX = x;
            lastTxY = txY;
        }

        rxFillPath.lineTo(lastRxX, padTop + chartH);
        rxFillPath.close();

        int fillStart = (downloadColor & 0x00FFFFFF) | 0x44000000;
        int fillEnd = (downloadColor & 0x00FFFFFF) | 0x04000000;
        rxFillPaint.setShader(new LinearGradient(
                0f, padTop, 0f, padTop + chartH,
                fillStart, fillEnd, Shader.TileMode.CLAMP
        ));

        canvas.drawPath(rxFillPath, rxFillPaint);
        canvas.drawPath(txPath, txLinePaint);
        canvas.drawPath(rxPath, rxLinePaint);

        // Live endpoint dots
        float dotRadius = 3.2f * density;
        dotPaint.setColor(uploadColor);
        canvas.drawCircle(lastTxX, lastTxY, dotRadius * 0.85f, dotPaint);
        dotPaint.setColor(downloadColor);
        canvas.drawCircle(lastRxX, lastRxY, dotRadius, dotPaint);
    }
}
