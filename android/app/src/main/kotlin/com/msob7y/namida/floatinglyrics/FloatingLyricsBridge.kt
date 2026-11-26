package com.msob7y.namida.floatinglyrics

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class FloatingLyricsBridge private constructor(private val application: Application) :
  Application.ActivityLifecycleCallbacks {
  companion object {
    private const val CHANNEL_NAME = "namida/floating_lyrics"
    private var instance: FloatingLyricsBridge? = null

    fun get(context: Context): FloatingLyricsBridge = instance
      ?: FloatingLyricsBridge(context.applicationContext as Application).also { instance = it }
  }

  private val startedActivities = mutableSetOf<Activity>()
  private val startedActivityCount get() = startedActivities.size
  private var channel: MethodChannel? = null
  private var engine: FlutterEngine? = null
  private val engineListener = object : FlutterEngine.EngineLifecycleListener {
    override fun onPreEngineRestart() = Unit

    override fun onEngineWillDestroy() {
      channel?.setMethodCallHandler(null)
      channel = null
      engine = null
    }
  }

  internal val manager by lazy { FloatingLyricsManager(application, ::emitAction, ::emitPosition) }

  init {
    application.registerActivityLifecycleCallbacks(this)
  }

  fun attach(flutterEngine: FlutterEngine) {
    // Engine configuration, default channel handlers, and UI callbacks run on the main thread.
    engine?.removeEngineLifecycleListener(engineListener)
    channel?.setMethodCallHandler(null)
    engine = flutterEngine
    flutterEngine.addEngineLifecycleListener(engineListener)
    channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).apply {
      setMethodCallHandler(::handleCall)
    }
  }

  private fun hasPermission(): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(application)

  private fun requestPermission(): Boolean = try {
    application.startActivity(
      Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${application.packageName}"))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
    true
  } catch (error: ActivityNotFoundException) {
    Log.w("FloatingLyricsBridge", "Overlay permission settings are unavailable", error)
    false
  }

  private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "hasPermission" -> result.success(hasPermission())
      "requestPermission" -> result.success(requestPermission())
      "getAppForegroundState" -> result.success(startedActivityCount > 0)
      "show" -> {
        if (!hasPermission()) {
          result.success(false)
          return
        }
        val args = Arguments(call)
        result.success(manager.show(
          args.style(), args.position(), args.primaryText(), args.secondaryText(), args.boolean("isPlaying"),
        ))
      }
      "hide" -> {
        manager.hide()
        result.success(null)
      }
      "updateStyle" -> {
        val args = Arguments(call)
        val position = if (args.boolean("applyPosition")) args.position() else null
        manager.updateStyle(args.style(), position)
        result.success(null)
      }
      "updateLine" -> {
        val args = Arguments(call)
        manager.updateLine(args.primaryText(), args.secondaryText())
        result.success(null)
      }
      "setPlaying" -> {
        manager.setPlaying(Arguments(call).boolean("isPlaying"))
        result.success(null)
      }
      "setLocked" -> {
        val args = Arguments(call)
        manager.setLocked(args.boolean("locked"), args.boolean("fallbackUnlockNotification"))
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun emitAction(action: String) {
    channel?.invokeMethod("onAction", action)
  }

  private fun emitPosition(position: FloatingLyricsPosition) {
    channel?.invokeMethod("onPositionChanged", mapOf("xPercent" to position.xPercent, "yPercent" to position.yPercent))
  }

  override fun onActivityStarted(activity: Activity) {
    if (startedActivities.add(activity) && startedActivityCount == 1) channel?.invokeMethod("onForegroundChanged", true)
  }

  override fun onActivityStopped(activity: Activity) {
    if (startedActivities.remove(activity) && startedActivityCount == 0) channel?.invokeMethod("onForegroundChanged", false)
  }

  override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
  override fun onActivityResumed(activity: Activity) = Unit
  override fun onActivityPaused(activity: Activity) = Unit
  override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
  override fun onActivityDestroyed(activity: Activity) = Unit

  private class Arguments(call: MethodCall) {
    private val values = requireNotNull(call.arguments as? Map<*, *>) { "${call.method} requires an argument map" }

    fun boolean(key: String): Boolean = required(key)
    fun primaryText(): String = required("primaryText")
    fun secondaryText(): String? = values["secondaryText"]?.let { required<String>("secondaryText") }

    fun position() = FloatingLyricsPosition(decimal("xPercent", 0.0, 100.0), decimal("yPercent", 0.0, 100.0))

    fun style() = FloatingLyricsStyle(
      locked = boolean("locked"),
      fallbackUnlockNotification = boolean("fallbackUnlockNotification"),
      singleLine = boolean("singleLine"),
      maxLines = required<Int>("maxLines").coerceIn(2, 6),
      toggleAnimation = boolean("toggleAnimation"),
      fontSizeSp = decimal("fontSizeSp", 12.0, 34.0).toFloat(),
      opacity = decimal("opacity", 0.2, 1.0).toFloat(),
      widthPercent = decimal("widthPercent", 40.0, 100.0).toFloat(),
      textGravity = when (required<String>("textAlign")) {
        "left" -> Gravity.LEFT
        "center" -> Gravity.CENTER_HORIZONTAL
        "right" -> Gravity.RIGHT
        else -> throw IllegalArgumentException("textAlign must be left, center, or right")
      },
      textColorArgb = requireNotNull((values["textColorArgb"] as? Number)?.toInt()) { "Invalid textColorArgb" },
      textOutline = boolean("textOutline"),
    )

    private fun decimal(key: String, min: Double, max: Double): Double {
      val value = required<Number>(key).toDouble()
      require(value.isFinite()) { "$key must be finite" }
      return value.coerceIn(min, max)
    }

    private inline fun <reified T> required(key: String): T =
      requireNotNull(values[key] as? T) { "Invalid or missing $key" }
  }
}
