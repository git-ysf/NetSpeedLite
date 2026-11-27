package com.netspeedlite.android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.net.TrafficStats;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.SystemClock;

import java.util.concurrent.CopyOnWriteArraySet;

/**
 * ForegroundService that samples TrafficStats every second, maintains a 60-second
 * history ring buffer, and updates a live speed notification in the status bar.
 */
public class SpeedMonitorService extends Service {

    public static final String ACTION_STOP = "com.netspeedlite.android.ACTION_STOP";
    public static final String ACTION_REFRESH = "com.netspeedlite.android.ACTION_REFRESH";

    private static final String CHANNEL_ID = "netspeedlite_live_speed";
    private static final int NOTIFICATION_ID = 1001;
    private static final long SAMPLE_INTERVAL_MS = 1000L;
    private static final int HISTORY_CAPACITY = 60;

    public static final class Snapshot {
        public final boolean running;
        public final long rxBytesPerSec;
        public final long txBytesPerSec;
        public final long peakRxBytesPerSec;
        public final long peakTxBytesPerSec;
        public final long sessionRxBytes;
        public final long sessionTxBytes;
        public final long[] rxHistory;
        public final long[] txHistory;

        public Snapshot(
                boolean running,
                long rxBytesPerSec,
                long txBytesPerSec,
                long peakRxBytesPerSec,
                long peakTxBytesPerSec,
                long sessionRxBytes,
                long sessionTxBytes,
                long[] rxHistory,
                long[] txHistory) {
            this.running = running;
            this.rxBytesPerSec = rxBytesPerSec;
            this.txBytesPerSec = txBytesPerSec;
            this.peakRxBytesPerSec = peakRxBytesPerSec;
            this.peakTxBytesPerSec = peakTxBytesPerSec;
            this.sessionRxBytes = sessionRxBytes;
            this.sessionTxBytes = sessionTxBytes;
            this.rxHistory = rxHistory;
            this.txHistory = txHistory;
        }
    }

    public interface Listener {
        void onSpeedUpdated(Snapshot snapshot);
    }

    private static final CopyOnWriteArraySet<Listener> LISTENERS = new CopyOnWriteArraySet<>();
    private static volatile boolean isRunning = false;
    private static volatile Snapshot latestSnapshot = emptySnapshot(false);

    private final Handler handler = new Handler(Looper.getMainLooper());
    private NotificationManager notificationManager;

    private long lastRxBytes = TrafficStats.UNSUPPORTED;
    private long lastTxBytes = TrafficStats.UNSUPPORTED;
    private long lastSampleTimeMs = 0L;

    private long sessionRxBytes = 0L;
    private long sessionTxBytes = 0L;
    private long peakRxBytesPerSec = 0L;
    private long peakTxBytesPerSec = 0L;

    private final long[] rxRing = new long[HISTORY_CAPACITY];
    private final long[] txRing = new long[HISTORY_CAPACITY];
    private int ringHead = 0;
    private int ringCount = 0;

    private final Runnable sampleRunnable = new Runnable() {
        @Override
        public void run() {
            if (!isRunning) {
                return;
            }
            sampleOnce();
            handler.postDelayed(this, SAMPLE_INTERVAL_MS);
        }
    };

    public static void addListener(Listener listener) {
        if (listener != null) {
            LISTENERS.add(listener);
            listener.onSpeedUpdated(latestSnapshot);
        }
    }

    public static void removeListener(Listener listener) {
        if (listener != null) {
            LISTENERS.remove(listener);
        }
    }

    public static boolean isServiceRunning() {
        return isRunning;
    }

    public static Snapshot getLatestSnapshot() {
        return latestSnapshot;
    }

    private static Snapshot emptySnapshot(boolean running) {
        return new Snapshot(running, 0L, 0L, 0L, 0L, 0L, 0L, new long[0], new long[0]);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        notificationManager = getSystemService(NotificationManager.class);
        ensureNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopMonitoring();
            return START_NOT_STICKY;
        }

        if (intent != null && ACTION_REFRESH.equals(intent.getAction()) && isRunning) {
            Snapshot snap = latestSnapshot;
            updateNotification(snap.rxBytesPerSec, snap.txBytesPerSec);
            return START_STICKY;
        }

        if (!isRunning) {
            isRunning = true;
            lastRxBytes = safeTotalRxBytes();
            lastTxBytes = safeTotalTxBytes();
            lastSampleTimeMs = SystemClock.elapsedRealtime();

            Notification initial = buildNotification(0L, 0L);
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, initial, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
            } else {
                startForeground(NOTIFICATION_ID, initial);
            }

            latestSnapshot = buildSnapshot(0L, 0L, true);
            notifyListeners(latestSnapshot);

            handler.removeCallbacks(sampleRunnable);
            handler.postDelayed(sampleRunnable, SAMPLE_INTERVAL_MS);
        }

        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        isRunning = false;
        handler.removeCallbacks(sampleRunnable);
        latestSnapshot = buildSnapshot(0L, 0L, false);
        notifyListeners(latestSnapshot);
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void stopMonitoring() {
        isRunning = false;
        handler.removeCallbacks(sampleRunnable);
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    private void sampleOnce() {
        long nowMs = SystemClock.elapsedRealtime();
        long currentRx = safeTotalRxBytes();
        long currentTx = safeTotalTxBytes();

        long elapsedMs = Math.max(200L, nowMs - lastSampleTimeMs);
        long deltaRx = (lastRxBytes >= 0 && currentRx >= lastRxBytes) ? (currentRx - lastRxBytes) : 0L;
        long deltaTx = (lastTxBytes >= 0 && currentTx >= lastTxBytes) ? (currentTx - lastTxBytes) : 0L;

        lastRxBytes = currentRx;
        lastTxBytes = currentTx;
        lastSampleTimeMs = nowMs;

        long rxPerSec = (deltaRx * 1000L) / elapsedMs;
        long txPerSec = (deltaTx * 1000L) / elapsedMs;

        sessionRxBytes += deltaRx;
        sessionTxBytes += deltaTx;
        if (rxPerSec > peakRxBytesPerSec) {
            peakRxBytesPerSec = rxPerSec;
        }
        if (txPerSec > peakTxBytesPerSec) {
            peakTxBytesPerSec = txPerSec;
        }

        appendHistory(rxPerSec, txPerSec);

        latestSnapshot = buildSnapshot(rxPerSec, txPerSec, true);
        updateNotification(rxPerSec, txPerSec);
        notifyListeners(latestSnapshot);
    }

    private void appendHistory(long rx, long tx) {
        rxRing[ringHead] = rx;
        txRing[ringHead] = tx;
        ringHead = (ringHead + 1) % HISTORY_CAPACITY;
        if (ringCount < HISTORY_CAPACITY) {
            ringCount++;
        }
    }

    private Snapshot buildSnapshot(long rxPerSec, long txPerSec, boolean running) {
        long[] rxHist = new long[ringCount];
        long[] txHist = new long[ringCount];
        int start = (ringHead - ringCount + HISTORY_CAPACITY) % HISTORY_CAPACITY;
        for (int i = 0; i < ringCount; i++) {
            int idx = (start + i) % HISTORY_CAPACITY;
            rxHist[i] = rxRing[idx];
            txHist[i] = txRing[idx];
        }
        return new Snapshot(
                running,
                rxPerSec,
                txPerSec,
                peakRxBytesPerSec,
                peakTxBytesPerSec,
                sessionRxBytes,
                sessionTxBytes,
                rxHist,
                txHist
        );
    }

    private void notifyListeners(Snapshot snapshot) {
        for (Listener listener : LISTENERS) {
            listener.onSpeedUpdated(snapshot);
        }
    }

    private long safeTotalRxBytes() {
        long val = TrafficStats.getTotalRxBytes();
        return val == TrafficStats.UNSUPPORTED ? 0L : val;
    }

    private long safeTotalTxBytes() {
        long val = TrafficStats.getTotalTxBytes();
        return val == TrafficStats.UNSUPPORTED ? 0L : val;
    }

    private void ensureNotificationChannel() {
        if (notificationManager == null) {
            return;
        }
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Live Network Speed",
                NotificationManager.IMPORTANCE_LOW
        );
        channel.setDescription("Displays real-time download and upload throughput");
        channel.setShowBadge(false);
        channel.setSound(null, null);
        channel.enableVibration(false);
        notificationManager.createNotificationChannel(channel);
    }

    private void updateNotification(long rxPerSec, long txPerSec) {
        if (notificationManager != null && isRunning) {
            notificationManager.notify(NOTIFICATION_ID, buildNotification(rxPerSec, txPerSec));
        }
    }

    private Notification buildNotification(long rxPerSec, long txPerSec) {
        boolean useBits = ThemeManager.isUseBits(this);
        String rxText = SpeedFormatter.formatRate(rxPerSec, useBits).full();
        String txText = SpeedFormatter.formatRate(txPerSec, useBits).full();
        String title = "\u2193 " + rxText + "   \u2191 " + txText;
        String body = "Session: \u2193 " + SpeedFormatter.formatBytes(sessionRxBytes)
                + "  \u2191 " + SpeedFormatter.formatBytes(sessionTxBytes);

        Intent openIntent = new Intent(this, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent openPending = PendingIntent.getActivity(
                this, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Intent stopIntent = new Intent(this, SpeedMonitorService.class);
        stopIntent.setAction(ACTION_STOP);
        PendingIntent stopPending = PendingIntent.getService(
                this, 1, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        return new Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(SpeedFormatter.createSpeedNotificationIcon(rxPerSec + txPerSec, useBits))
                .setContentTitle(title)
                .setContentText(body)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setContentIntent(openPending)
                .addAction(new Notification.Action.Builder(null, "Stop", stopPending).build())
                .build();
    }
}
