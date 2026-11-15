package com.softchip.tourchip

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
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 講解廣播的前景服務：App 到背景、螢幕關掉也繼續講（麥克風）或聽（媒體播放）。
 * 只在廣播連線時開，結束就關；常駐通知點了回到 App。
 * Dart 端：lib/tour/cast.dart（MethodChannel tourchip/cast：start {speaking, title, text}、stop）
 */
class CastService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val speaking = intent?.getBooleanExtra("speaking", false) ?: false
        val title = intent?.getStringExtra("title") ?: ""
        val text = intent?.getStringExtra("text") ?: ""
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, intent?.getStringExtra("channel") ?: "Live talk", NotificationManager.IMPORTANCE_LOW))
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.apply { addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP) }
        val pi = PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n: Notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_flag)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (speaking) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            else ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else 0
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, n, type)
        } catch (e: Exception) {
            // 系統不讓開（例如在背景才要開）：不影響廣播本身，只是到背景可能會停
            stopSelf()
        }
        return START_NOT_STICKY
    }

    companion object {
        const val CHANNEL = "cast_live"
        const val NOTIFICATION_ID = 7302
    }
}

class CastChannel(private val context: Context, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "tourchip/cast").setMethodCallHandler { call, result ->
            val i = Intent(context, CastService::class.java)
            when (call.method) {
                "start" -> {
                    i.putExtra("speaking", call.argument<Boolean>("speaking") ?: false)
                    i.putExtra("title", call.argument<String>("title") ?: "")
                    i.putExtra("text", call.argument<String>("text") ?: "")
                    i.putExtra("channel", call.argument<String>("channel") ?: "Live talk")
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i) else context.startService(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stop" -> {
                    context.stopService(i)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
