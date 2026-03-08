package com.igalia.wolvic.crashreporting;

import android.app.ActivityManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
// TODO: Deprecated JobIntentService, see https://github.com/Igalia/wolvic/issues/805
import androidx.core.app.JobIntentService;

import com.igalia.wolvic.BuildConfig;
import com.igalia.wolvic.R;
import com.igalia.wolvic.VRBrowserActivity;
import com.igalia.wolvic.browser.SettingsStore;
import com.igalia.wolvic.browser.api.WRuntime;
import com.igalia.wolvic.browser.engine.EngineProvider;
import com.igalia.wolvic.utils.SystemUtils;

import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.UUID;

public class CrashReporterService extends JobIntentService {

    private static final String LOGTAG = SystemUtils.createLogtag(CrashReporterService.class);

    public static final String CRASH_ACTION = BuildConfig.APPLICATION_ID + ".CRASH_ACTION";
    public static final String DATA_TAG = "intent";
    public static final String CRASH_FILE_PREFIX = "crashfile-";

    private static final int PID_CHECK_INTERVAL = 100;
    private static final int JOB_ID = 1000;
    private static final String NOTIFICATION_CHANNEL_ID = "wolvic_crash_reporter";
    private static final int NOTIFICATION_ID = 9001;
    // Threshold used to fix Infinite restart loop on startup crashes.
    // See https://github.com/MozillaReality/FirefoxReality/issues/651
    public static final long MAX_RESTART_COUNT = 2;
    private static final int MAX_PID_CHECK_COUNT = 5;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(LOGTAG, "onStartCommand");
        // Must call startForeground() immediately when started via startForegroundService(),
        // otherwise Android throws ForegroundServiceDidNotStartInTimeException (e.g. on Quest).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ensureNotificationChannel();
            Notification notification = buildForegroundNotification();
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enqueueWork(this, CrashReporterService.class, JOB_ID, intent);
        }

        return super.onStartCommand(intent, flags, startId);
    }

    private void ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    getString(R.string.crash_reporter_channel_name),
                    NotificationManager.IMPORTANCE_LOW);
            channel.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) {
                nm.createNotificationChannel(channel);
            }
        }
    }

    private Notification buildForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent activityIntent = new Intent(this, VRBrowserActivity.class);
            activityIntent.setPackage(BuildConfig.APPLICATION_ID);
            activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            PendingIntent pending = PendingIntent.getActivity(this, 0, activityIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            return new Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                    .setContentTitle(getString(R.string.crash_reporter_notification_title))
                    .setContentText(getString(R.string.crash_reporter_notification_text))
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentIntent(pending)
                    .setPriority(Notification.PRIORITY_LOW)
                    .build();
        }
        return null;
    }

    @NonNull
    public static ArrayList<String> findCrashFiles(@NonNull Context aContext) {
        ArrayList<String> files = new ArrayList<>();
        String[] allFiles = aContext.fileList();
        for (String value: allFiles) {
            if (value.startsWith(CRASH_FILE_PREFIX)) {
                files.add(value);
            }
        }
        return files;
    }
    
    @Override
    protected void onHandleWork(@NonNull Intent intent) {
        if (!EngineProvider.INSTANCE.isRuntimeCreated()) {
            Log.e(LOGTAG, "Application crashed during startup, before the engine's runtime had been created.");
            return;
        }
        String action = intent.getAction();
        WRuntime.CrashReportIntent crash = EngineProvider.INSTANCE.getOrCreateRuntime(getBaseContext()).getCrashReportIntent();
        if (crash.action_crashed.equals(action)) {
            final int activityPid = SettingsStore.getInstance(getBaseContext()).getPid();
            boolean fatal = intent.getBooleanExtra(crash.extra_crash_fatal, false);
            long count = SettingsStore.getInstance(getBaseContext()).getCrashRestartCount();
            boolean cancelRestart = count > MAX_RESTART_COUNT;
            if (cancelRestart || BuildConfig.DISABLE_CRASH_RESTART) {
                Log.e(LOGTAG, "Too many restarts. Abort crash reporter service.");
                return;
            }

            if (fatal) {
                Log.d(LOGTAG, "Main process crash " + intent);
                final String dumpFile = intent.getStringExtra(crash.extra_minidump_path) + "\n";
                final String extraFile = intent.getStringExtra(crash.extra_extras_path);
                final String crashFile = CRASH_FILE_PREFIX + UUID.randomUUID().toString().replaceAll("-", "") + ".txt";
                try (FileOutputStream file = getBaseContext().openFileOutput(crashFile, 0)) {
                    file.write(dumpFile.getBytes());
                    file.write(extraFile.getBytes());
                    Log.d(LOGTAG, "Wrote crashfile: " + crashFile);
                } catch (IOException e) {
                    Log.e(LOGTAG, "Failed to create crash file: '" + crashFile + "' error: " + e.getMessage());
                }
                if (activityPid == 0) {
                    Log.e(LOGTAG, "Application was quitting. Crash reporter will not trigger a restart.");
                    return;
                }
                final ActivityManager activityManager = (ActivityManager) this.getSystemService(Context.ACTIVITY_SERVICE);
                if (activityManager == null) {
                    return;
                }

                int pidCheckCount = 0;
                do {
                    boolean activityFound = false;
                    for (final ActivityManager.RunningAppProcessInfo info : activityManager.getRunningAppProcesses()) {
                        if (activityPid == info.pid) {
                            activityFound = true;
                            Log.e(LOGTAG, "Main activity still running: " + activityPid);
                            break;
                        } else {
                            Log.d(LOGTAG, "Main activity not found: " + activityPid);
                        }
                    }

                    if (!activityFound || (pidCheckCount > MAX_PID_CHECK_COUNT)) {
                        intent.setClass(CrashReporterService.this, VRBrowserActivity.class);
                        intent.setPackage(BuildConfig.APPLICATION_ID);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(intent);
                        break;

                    } else {
                        pidCheckCount++;
                        try {
                            Thread.sleep(PID_CHECK_INTERVAL);
                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        }
                    }

                } while (true);

            } else {
                Log.d(LOGTAG, "Content process crash " + intent);
                Intent broadcastIntent = new Intent(CRASH_ACTION);
                broadcastIntent.putExtra(DATA_TAG, intent);
                sendBroadcast(broadcastIntent, BuildConfig.APPLICATION_ID + "." + getString(R.string.app_permission_name));
            }
        }

        Log.d(LOGTAG, "Crash reporter job finished");
    }

    public static void submitCaughtException(@NonNull Exception exception) {

    }

}
