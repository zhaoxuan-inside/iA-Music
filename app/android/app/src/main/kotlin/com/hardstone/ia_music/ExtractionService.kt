package com.hardstone.ia_music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * 提取前台服务（WS3/REQ-EXT-04）：下载进行期间保持前台优先级，
 * 离开页面/切后台不被系统回收；通知展示实时进度。
 *
 * 生命周期由 MainActivity 驱动：
 * * download 方法开始 → ACTION_START（携带 Dart 侧本地化标题）
 * * progress 事件（≥5% 步进）→ ACTION_UPDATE
 * * 终态（完成/失败/取消/暂停）→ ACTION_STOP
 */
class ExtractionService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: DEFAULT_TITLE
                startForegroundCompat(buildNotification(this, title, 0, false))
            }
            ACTION_UPDATE -> {
                val pct = intent.getIntExtra(EXTRA_PERCENT, 0)
                val title = intent.getStringExtra(EXTRA_TITLE) ?: DEFAULT_TITLE
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIF_ID, buildNotification(this, title, pct, true))
            }
            else -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    companion object {
        const val TAG = "ia_extract_fg"
        const val CHANNEL_ID = "ia_extraction"
        const val NOTIF_ID = 0x1A
        const val DEFAULT_TITLE = "提取任务进行中"
        const val ACTION_START = "com.hardstone.ia_music.extract.START"
        const val ACTION_UPDATE = "com.hardstone.ia_music.extract.UPDATE"
        const val ACTION_STOP = "com.hardstone.ia_music.extract.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_PERCENT = "percent"

        fun start(ctx: Context, title: String) {
            val i = Intent(ctx, ExtractionService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_TITLE, title)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun update(ctx: Context, title: String, percent: Int) {
            val i = Intent(ctx, ExtractionService::class.java)
                .setAction(ACTION_UPDATE)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_PERCENT, percent)
            ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.startService(
                Intent(ctx, ExtractionService::class.java).setAction(ACTION_STOP)
            )
        }

        private fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                    nm.createNotificationChannel(
                        NotificationChannel(
                            CHANNEL_ID, DEFAULT_TITLE,
                            NotificationManager.IMPORTANCE_LOW
                        )
                    )
                }
            }
        }

        private fun buildNotification(
            ctx: Context,
            title: String,
            percent: Int,
            withProgress: Boolean
        ): Notification {
            ensureChannel(ctx)
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val contentIntent = PendingIntent.getActivity(
                ctx, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(ctx, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(ctx)
            }
            b.setContentTitle(title)
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setContentIntent(contentIntent)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
            if (withProgress) {
                b.setContentText("$percent%")
                    .setProgress(100, percent, percent <= 0)
            }
            return b.build()
        }
    }
}
