package com.netspeedlite.android;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.EnumMap;
import java.util.Map;

/**
 * Main UI for NetSpeedLite: live throughput readouts, 60-second sparkline,
 * Dark/Light/System theme switching, accent palettes, and service controls.
 */
public class MainActivity extends Activity implements SpeedMonitorService.Listener {

    private static final int REQ_POST_NOTIFICATIONS = 42;

    private ScrollView scrollView;
    private LinearLayout rootLayout;

    // Header
    private TextView titleView;
    private TextView subtitleView;
    private TextView statusBadge;
    private TextView themeCycleBtn;

    // Speed Hero Card
    private LinearLayout speedCard;
    private TextView rxLabel;
    private TextView rxValueView;
    private TextView rxUnitView;
    private TextView txLabel;
    private TextView txValueView;
    private TextView txUnitView;
    private View speedDivider;
    private TextView sessionStatsView;
    private TextView peakStatsView;

    // Sparkline Card
    private LinearLayout chartCard;
    private TextView chartTitleView;
    private TextView chartLegendView;
    private SparklineView sparklineView;

    // Controls Card
    private LinearLayout controlsCard;
    private TextView controlsTitleView;
    private TextView toggleServiceBtn;
    private TextView unitToggleBtn;
    private TextView autoStartBtn;
    private TextView accentLabelView;
    private final Map<ThemeManager.AccentTheme, TextView> accentChips =
            new EnumMap<>(ThemeManager.AccentTheme.class);

    private ThemeManager.Palette palette;
    private SpeedMonitorService.Snapshot currentSnapshot = SpeedMonitorService.getLatestSnapshot();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        applyTheme();
        renderSnapshot(currentSnapshot);
    }

    @Override
    protected void onStart() {
        super.onStart();
        SpeedMonitorService.addListener(this);
    }

    @Override
    protected void onStop() {
        SpeedMonitorService.removeListener(this);
        super.onStop();
    }

    @Override
    public void onSpeedUpdated(SpeedMonitorService.Snapshot snapshot) {
        currentSnapshot = snapshot;
        renderSnapshot(snapshot);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            startMonitorService();
        }
    }

    private void buildUi() {
        scrollView = new ScrollView(this);
        scrollView.setFillViewport(true);

        rootLayout = new LinearLayout(this);
        rootLayout.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(16);
        rootLayout.setPadding(pad, dp(20), pad, dp(24));
        scrollView.addView(rootLayout, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        // 1. Header Row
        LinearLayout headerRow = new LinearLayout(this);
        headerRow.setOrientation(LinearLayout.HORIZONTAL);
        headerRow.setGravity(Gravity.CENTER_VERTICAL);

        LinearLayout titleCol = new LinearLayout(this);
        titleCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams titleColLp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        headerRow.addView(titleCol, titleColLp);

        titleView = new TextView(this);
        titleView.setText("NetSpeedLite");
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        titleView.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        titleCol.addView(titleView);

        subtitleView = new TextView(this);
        subtitleView.setText("Zero-dependency live network monitor");
        subtitleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        titleCol.addView(subtitleView);

        statusBadge = createPillButton("");
        statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        statusBadge.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        LinearLayout.LayoutParams badgeLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        badgeLp.setMarginEnd(dp(8));
        headerRow.addView(statusBadge, badgeLp);

        themeCycleBtn = createPillButton("Theme");
        themeCycleBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        themeCycleBtn.setOnClickListener(v -> cycleThemeMode());
        headerRow.addView(themeCycleBtn);

        rootLayout.addView(headerRow, marginBottom(dp(16)));

        // 2. Hero Live Speed Card
        speedCard = createCard();
        LinearLayout speedColumns = new LinearLayout(this);
        speedColumns.setOrientation(LinearLayout.HORIZONTAL);
        speedColumns.setBaselineAligned(false);

        // Download Column
        LinearLayout rxCol = new LinearLayout(this);
        rxCol.setOrientation(LinearLayout.VERTICAL);
        rxLabel = new TextView(this);
        rxLabel.setText("\u2193 DOWNLOAD");
        rxLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        rxLabel.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        rxCol.addView(rxLabel);

        rxValueView = new TextView(this);
        rxValueView.setText("0");
        rxValueView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        rxValueView.setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD));
        rxValueView.setFontFeatureSettings("tnum");
        rxCol.addView(rxValueView);

        rxUnitView = new TextView(this);
        rxUnitView.setText("B/s");
        rxUnitView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        rxCol.addView(rxUnitView);

        speedColumns.addView(rxCol, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        // Upload Column
        LinearLayout txCol = new LinearLayout(this);
        txCol.setOrientation(LinearLayout.VERTICAL);
        txLabel = new TextView(this);
        txLabel.setText("\u2191 UPLOAD");
        txLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        txLabel.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        txCol.addView(txLabel);

        txValueView = new TextView(this);
        txValueView.setText("0");
        txValueView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        txValueView.setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD));
        txValueView.setFontFeatureSettings("tnum");
        txCol.addView(txValueView);

        txUnitView = new TextView(this);
        txUnitView.setText("B/s");
        txUnitView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        txCol.addView(txUnitView);

        speedColumns.addView(txCol, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        speedCard.addView(speedColumns);

        speedDivider = new View(this);
        LinearLayout.LayoutParams divLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(1));
        divLp.topMargin = dp(14);
        divLp.bottomMargin = dp(12);
        speedCard.addView(speedDivider, divLp);

        sessionStatsView = new TextView(this);
        sessionStatsView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        sessionStatsView.setFontFeatureSettings("tnum");
        speedCard.addView(sessionStatsView, marginBottom(dp(4)));

        peakStatsView = new TextView(this);
        peakStatsView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        peakStatsView.setFontFeatureSettings("tnum");
        speedCard.addView(peakStatsView);

        rootLayout.addView(speedCard, marginBottom(dp(14)));

        // 3. Live Sparkline Card
        chartCard = createCard();
        LinearLayout chartHeader = new LinearLayout(this);
        chartHeader.setOrientation(LinearLayout.HORIZONTAL);
        chartHeader.setGravity(Gravity.CENTER_VERTICAL);

        chartTitleView = new TextView(this);
        chartTitleView.setText("Live Throughput (60s)");
        chartTitleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        chartTitleView.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        chartHeader.addView(chartTitleView, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        chartLegendView = new TextView(this);
        chartLegendView.setText("\u2193 DL   \u2191 UL");
        chartLegendView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        chartHeader.addView(chartLegendView);

        chartCard.addView(chartHeader, marginBottom(dp(8)));

        sparklineView = new SparklineView(this);
        chartCard.addView(sparklineView, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(170)));

        rootLayout.addView(chartCard, marginBottom(dp(14)));

        // 4. Controls & Themes Card
        controlsCard = createCard();
        controlsTitleView = new TextView(this);
        controlsTitleView.setText("Controls & Appearance");
        controlsTitleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        controlsTitleView.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        controlsCard.addView(controlsTitleView, marginBottom(dp(12)));

        toggleServiceBtn = createActionButton();
        toggleServiceBtn.setOnClickListener(v -> toggleService());
        controlsCard.addView(toggleServiceBtn, marginBottom(dp(10)));

        LinearLayout togglesRow = new LinearLayout(this);
        togglesRow.setOrientation(LinearLayout.HORIZONTAL);

        unitToggleBtn = createActionButton();
        unitToggleBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        unitToggleBtn.setOnClickListener(v -> toggleUnits());
        LinearLayout.LayoutParams unitLp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        unitLp.setMarginEnd(dp(8));
        togglesRow.addView(unitToggleBtn, unitLp);

        autoStartBtn = createActionButton();
        autoStartBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        autoStartBtn.setOnClickListener(v -> toggleAutoStart());
        togglesRow.addView(autoStartBtn, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        controlsCard.addView(togglesRow, marginBottom(dp(14)));

        accentLabelView = new TextView(this);
        accentLabelView.setText("Accent Theme");
        accentLabelView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        controlsCard.addView(accentLabelView, marginBottom(dp(8)));

        LinearLayout accentRow = new LinearLayout(this);
        accentRow.setOrientation(LinearLayout.HORIZONTAL);
        ThemeManager.AccentTheme[] themes = ThemeManager.AccentTheme.values();
        for (int i = 0; i < themes.length; i++) {
            final ThemeManager.AccentTheme accent = themes[i];
            TextView chip = createPillButton(accent.label);
            chip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
            chip.setGravity(Gravity.CENTER);
            chip.setOnClickListener(v -> {
                ThemeManager.setAccentTheme(this, accent);
                applyTheme();
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
            if (i < themes.length - 1) {
                lp.setMarginEnd(dp(6));
            }
            accentRow.addView(chip, lp);
            accentChips.put(accent, chip);
        }
        controlsCard.addView(accentRow);

        rootLayout.addView(controlsCard);

        setContentView(scrollView);
    }

    private void applyTheme() {
        palette = ThemeManager.resolvePalette(this);
        ThemeManager.ThemeMode mode = ThemeManager.getThemeMode(this);
        ThemeManager.AccentTheme activeAccent = ThemeManager.getAccentTheme(this);

        scrollView.setBackgroundColor(palette.background);

        Window window = getWindow();
        if (window != null) {
            window.setStatusBarColor(palette.background);
            window.setNavigationBarColor(palette.background);
            if (Build.VERSION.SDK_INT >= 30 && window.getInsetsController() != null) {
                int mask = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                        | android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
                window.getInsetsController().setSystemBarsAppearance(palette.isDark ? 0 : mask, mask);
            }
        }

        titleView.setTextColor(palette.textPrimary);
        subtitleView.setTextColor(palette.textSecondary);

        themeCycleBtn.setText(mode.label);
        themeCycleBtn.setTextColor(palette.textPrimary);
        themeCycleBtn.setBackground(makeRoundedRect(palette.surfaceAlt, palette.border, dp(1), dp(16)));

        styleCard(speedCard);
        rxLabel.setTextColor(palette.downloadColor);
        rxValueView.setTextColor(palette.textPrimary);
        rxUnitView.setTextColor(palette.textSecondary);
        txLabel.setTextColor(palette.uploadColor);
        txValueView.setTextColor(palette.textPrimary);
        txUnitView.setTextColor(palette.textSecondary);
        speedDivider.setBackgroundColor(palette.border);
        sessionStatsView.setTextColor(palette.textSecondary);
        peakStatsView.setTextColor(palette.textSecondary);

        styleCard(chartCard);
        chartTitleView.setTextColor(palette.textPrimary);
        chartLegendView.setTextColor(palette.textSecondary);
        sparklineView.applyPalette(palette);

        styleCard(controlsCard);
        controlsTitleView.setTextColor(palette.textPrimary);
        accentLabelView.setTextColor(palette.textSecondary);

        for (Map.Entry<ThemeManager.AccentTheme, TextView> entry : accentChips.entrySet()) {
            boolean selected = entry.getKey() == activeAccent;
            TextView chip = entry.getValue();
            int chipColor = palette.isDark ? entry.getKey().darkDownload : entry.getKey().lightDownload;
            if (selected) {
                chip.setTextColor(0xFFFFFFFF);
                chip.setBackground(makeRoundedRect(chipColor, chipColor, dp(1), dp(14)));
            } else {
                chip.setTextColor(palette.textPrimary);
                chip.setBackground(makeRoundedRect(palette.surfaceAlt, palette.border, dp(1), dp(14)));
            }
        }

        refreshToggleLabels();
        renderSnapshot(currentSnapshot);
    }

    private void renderSnapshot(SpeedMonitorService.Snapshot snapshot) {
        if (palette == null) {
            return;
        }
        boolean useBits = ThemeManager.isUseBits(this);
        boolean running = snapshot != null && snapshot.running;

        if (running) {
            statusBadge.setText("ACTIVE");
            statusBadge.setTextColor(palette.statusActiveText);
            statusBadge.setBackground(makeRoundedRect(palette.statusActiveBg, palette.statusActiveBg, 0, dp(14)));

            toggleServiceBtn.setText("Stop Live Monitor");
            toggleServiceBtn.setTextColor(0xFFFFFFFF);
            toggleServiceBtn.setBackground(makeRoundedRect(0xFFDC2626, 0xFFDC2626, 0, dp(12)));
        } else {
            statusBadge.setText("PAUSED");
            statusBadge.setTextColor(palette.statusPausedText);
            statusBadge.setBackground(makeRoundedRect(palette.statusPausedBg, palette.statusPausedBg, 0, dp(14)));

            toggleServiceBtn.setText("Start Live Monitor");
            toggleServiceBtn.setTextColor(0xFFFFFFFF);
            toggleServiceBtn.setBackground(makeRoundedRect(palette.accentColor, palette.accentColor, 0, dp(12)));
        }

        long rxRate = snapshot != null ? snapshot.rxBytesPerSec : 0L;
        long txRate = snapshot != null ? snapshot.txBytesPerSec : 0L;
        SpeedFormatter.FormattedSpeed rxFmt = SpeedFormatter.formatRate(rxRate, useBits);
        SpeedFormatter.FormattedSpeed txFmt = SpeedFormatter.formatRate(txRate, useBits);

        rxValueView.setText(rxFmt.value);
        rxUnitView.setText(rxFmt.unit);
        txValueView.setText(txFmt.value);
        txUnitView.setText(txFmt.unit);

        long sessRx = snapshot != null ? snapshot.sessionRxBytes : 0L;
        long sessTx = snapshot != null ? snapshot.sessionTxBytes : 0L;
        long peakRx = snapshot != null ? snapshot.peakRxBytesPerSec : 0L;
        long peakTx = snapshot != null ? snapshot.peakTxBytesPerSec : 0L;

        sessionStatsView.setText("Session:  \u2193 " + SpeedFormatter.formatBytes(sessRx)
                + "   \u2191 " + SpeedFormatter.formatBytes(sessTx));
        peakStatsView.setText("Peak:       \u2193 " + SpeedFormatter.formatRate(peakRx, useBits).full()
                + "   \u2191 " + SpeedFormatter.formatRate(peakTx, useBits).full());

        if (snapshot != null) {
            sparklineView.setData(snapshot.rxHistory, snapshot.txHistory, useBits);
        }
    }

    private void refreshToggleLabels() {
        boolean useBits = ThemeManager.isUseBits(this);
        unitToggleBtn.setText(useBits ? "Unit: Bits/s" : "Unit: Bytes/s");
        unitToggleBtn.setTextColor(palette.textPrimary);
        unitToggleBtn.setBackground(makeRoundedRect(palette.surfaceAlt, palette.border, dp(1), dp(12)));

        boolean autoStart = ThemeManager.isAutoStartEnabled(this);
        autoStartBtn.setText(autoStart ? "Boot Start: ON" : "Boot Start: OFF");
        autoStartBtn.setTextColor(palette.textPrimary);
        autoStartBtn.setBackground(makeRoundedRect(palette.surfaceAlt, palette.border, dp(1), dp(12)));
    }

    private void toggleService() {
        if (SpeedMonitorService.isServiceRunning()) {
            Intent stop = new Intent(this, SpeedMonitorService.class);
            stop.setAction(SpeedMonitorService.ACTION_STOP);
            startService(stop);
        } else {
            if (Build.VERSION.SDK_INT >= 33
                    && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQ_POST_NOTIFICATIONS);
                return;
            }
            startMonitorService();
        }
    }

    private void startMonitorService() {
        Intent intent = new Intent(this, SpeedMonitorService.class);
        startForegroundService(intent);
    }

    private void toggleUnits() {
        boolean next = !ThemeManager.isUseBits(this);
        ThemeManager.setUseBits(this, next);
        refreshToggleLabels();
        renderSnapshot(currentSnapshot);
        if (SpeedMonitorService.isServiceRunning()) {
            Intent refresh = new Intent(this, SpeedMonitorService.class);
            refresh.setAction(SpeedMonitorService.ACTION_REFRESH);
            startService(refresh);
        }
    }

    private void toggleAutoStart() {
        ThemeManager.setAutoStartEnabled(this, !ThemeManager.isAutoStartEnabled(this));
        refreshToggleLabels();
    }

    private void cycleThemeMode() {
        ThemeManager.ThemeMode[] modes = ThemeManager.ThemeMode.values();
        ThemeManager.ThemeMode current = ThemeManager.getThemeMode(this);
        ThemeManager.ThemeMode next = modes[(current.ordinal() + 1) % modes.length];
        ThemeManager.setThemeMode(this, next);
        applyTheme();
    }

    private LinearLayout createCard() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        int p = dp(16);
        card.setPadding(p, p, p, p);
        return card;
    }

    private void styleCard(LinearLayout card) {
        card.setBackground(makeRoundedRect(palette.surface, palette.border, dp(1), dp(16)));
    }

    private TextView createPillButton(String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setPadding(dp(12), dp(6), dp(12), dp(6));
        return tv;
    }

    private TextView createActionButton() {
        TextView tv = new TextView(this);
        tv.setGravity(Gravity.CENTER);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f);
        tv.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        tv.setPadding(dp(14), dp(12), dp(14), dp(12));
        return tv;
    }

    private GradientDrawable makeRoundedRect(int fillColor, int strokeColor, int strokeWidth, int radiusPx) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(fillColor);
        if (strokeWidth > 0) {
            d.setStroke(strokeWidth, strokeColor);
        }
        d.setCornerRadius(radiusPx);
        return d;
    }

    private LinearLayout.LayoutParams marginBottom(int px) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.bottomMargin = px;
        return lp;
    }

    private int dp(int dp) {
        return Math.round(dp * getResources().getDisplayMetrics().density);
    }
}
