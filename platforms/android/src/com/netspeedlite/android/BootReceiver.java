package com.netspeedlite.android;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Starts the network speed monitor service on device boot if enabled in preferences.
 */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent != null && Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            if (ThemeManager.isAutoStartEnabled(context)) {
                Intent serviceIntent = new Intent(context, SpeedMonitorService.class);
                context.startForegroundService(serviceIntent);
            }
        }
    }
}
