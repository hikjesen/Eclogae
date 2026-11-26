package com.wander.eclogae.floatinglyrics

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import com.wander.eclogae.R

internal class FloatingLyricsLockNotification(private val context: Context) {
  private companion object {
    const val CHANNEL_ID = "eclogae_floating_lyrics_lock"
    const val NOTIFICATION_ID = 0x464C
  }

  private val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

  fun show() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
      context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    ) return

    manager.createNotificationChannel(
      NotificationChannel(CHANNEL_ID, "悬浮歌词解锁", NotificationManager.IMPORTANCE_LOW).apply {
        setSound(null, null)
        enableVibration(false)
      },
    )
    val close = Notification.Action.Builder(
      Icon.createWithResource(context, R.drawable.stop),
      "关闭",
      actionIntent(FloatingLyricsActionReceiver.ACTION_CLOSE),
    ).build()
    val notification = Notification.Builder(context, CHANNEL_ID)
      .setSmallIcon(R.drawable.floating_lyric_lock)
      .setContentTitle("悬浮歌词已锁定")
      .setContentText("点击此处解锁悬浮歌词")
      .setContentIntent(actionIntent(FloatingLyricsActionReceiver.ACTION_UNLOCK))
      .addAction(close)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .build()
    manager.notify(NOTIFICATION_ID, notification)
  }

  fun cancel() {
    manager.cancel(NOTIFICATION_ID)
  }

  private fun actionIntent(action: String): PendingIntent = PendingIntent.getBroadcast(
    context,
    0,
    Intent(context, FloatingLyricsActionReceiver::class.java).setAction(action),
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
  )
}
