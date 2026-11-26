package com.wander.eclogae.floatinglyrics

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class FloatingLyricsActionReceiver : BroadcastReceiver() {
  companion object {
    internal const val ACTION_UNLOCK = "com.wander.eclogae.floatinglyrics.UNLOCK"
    internal const val ACTION_CLOSE = "com.wander.eclogae.floatinglyrics.CLOSE"
  }

  override fun onReceive(context: Context, intent: Intent) {
    val action = when (intent.action) {
      ACTION_UNLOCK -> "unlock"
      ACTION_CLOSE -> "close"
      else -> return
    }
    FloatingLyricsBridge.get(context).manager.handleNotificationAction(action)
  }
}
