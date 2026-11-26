package com.msob7y.namida.floatinglyrics

import android.app.Application
import android.content.BroadcastReceiver
import android.content.ComponentCallbacks
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Point
import android.hardware.display.DisplayManager
import android.hardware.input.InputManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.View.MeasureSpec
import android.view.WindowInsets
import android.view.WindowManager
import android.view.WindowManager.LayoutParams
import androidx.core.content.ContextCompat
import com.msob7y.namida.NamidaMainActivity
import kotlin.math.roundToInt

internal data class FloatingLyricsPosition(val xPercent: Double, val yPercent: Double)

internal data class FloatingLyricsStyle(
  val locked: Boolean,
  val fallbackUnlockNotification: Boolean,
  val singleLine: Boolean,
  val maxLines: Int,
  val toggleAnimation: Boolean,
  val fontSizeSp: Float,
  val opacity: Float,
  val widthPercent: Float,
  val textGravity: Int,
  val textColorArgb: Int,
  val textOutline: Boolean,
)

internal class FloatingLyricsManager(
  private val application: Application,
  private val onAction: (String) -> Unit,
  private val onPositionChanged: (FloatingLyricsPosition) -> Unit,
) : ComponentCallbacks, DisplayManager.DisplayListener {
  private companion object {
    const val TAG = "FloatingLyricsManager"
    const val WINDOW_FLAGS = LayoutParams.FLAG_NOT_FOCUSABLE or LayoutParams.FLAG_NOT_TOUCH_MODAL or
      LayoutParams.FLAG_LAYOUT_IN_SCREEN or LayoutParams.FLAG_LAYOUT_NO_LIMITS
  }

  @Suppress("DEPRECATION")
  private val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    LayoutParams.TYPE_APPLICATION_OVERLAY
  } else {
    LayoutParams.TYPE_SYSTEM_ALERT
  }
  private val displayManager = application.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
  private val windowContext by lazy {
    val displayContext = application.createDisplayContext(displayManager.getDisplay(Display.DEFAULT_DISPLAY))
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) displayContext.createWindowContext(windowType, null) else displayContext
  }
  private val windowManager by lazy { windowContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager }
  private val powerManager = application.getSystemService(Context.POWER_SERVICE) as PowerManager
  private val notification = FloatingLyricsLockNotification(application)
  private val params = LayoutParams(0, LayoutParams.WRAP_CONTENT, windowType, WINDOW_FLAGS, PixelFormat.TRANSLUCENT).apply {
    gravity = Gravity.TOP or Gravity.START
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      setFitInsetsTypes(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
      setFitInsetsIgnoringVisibility(true)
    }
  }

  private var overlay: FloatingLyricsOverlayView? = null
  private var screen = Point()
  private var lastPosition = FloatingLyricsPosition(7.0, 12.0)
  private var maxX = 0
  private var maxY = 0
  private val screenReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      overlay?.setScreenOn(intent.action == Intent.ACTION_SCREEN_ON)
    }
  }

  fun show(
    style: FloatingLyricsStyle,
    position: FloatingLyricsPosition,
    primaryText: String,
    secondaryText: String?,
    isPlaying: Boolean,
  ): Boolean {
    lastPosition = position
    val current = overlay
    if (current != null) {
      current.applyStyle(style)
      current.setPlaying(isPlaying)
      current.updateLine(primaryText, secondaryText)
      layoutOverlay(current, position)
      syncNotification(style)
      return true
    }

    val view = FloatingLyricsOverlayView(
      windowContext,
      style,
      isPlaying,
      powerManager.isInteractive,
      onAction = ::handleAction,
      onDrag = ::dragBy,
      onDragFinished = ::finishDrag,
      onToolbarChanged = { overlay?.let { layoutOverlay(it) } },
    )
    view.updateLine(primaryText, secondaryText)
    screen = screenSize()
    layoutOverlay(view, position)
    try {
      windowManager.addView(view, params)
    } catch (error: WindowManager.BadTokenException) {
      Log.w(TAG, "Android rejected the floating lyrics window", error)
      return false
    } catch (error: SecurityException) {
      Log.w(TAG, "Floating lyrics window permission was denied", error)
      return false
    }
    overlay = view
    application.registerComponentCallbacks(this)
    displayManager.registerDisplayListener(this, null)
    ContextCompat.registerReceiver(
      application,
      screenReceiver,
      IntentFilter(Intent.ACTION_SCREEN_OFF).apply { addAction(Intent.ACTION_SCREEN_ON) },
      ContextCompat.RECEIVER_NOT_EXPORTED,
    )
    syncNotification(style)
    return true
  }

  fun hide() {
    notification.cancel()
    val view = overlay ?: return
    overlay = null
    application.unregisterComponentCallbacks(this)
    displayManager.unregisterDisplayListener(this)
    application.unregisterReceiver(screenReceiver)
    windowManager.removeViewImmediate(view)
  }

  fun updateStyle(style: FloatingLyricsStyle, position: FloatingLyricsPosition?) {
    val view = overlay ?: return
    if (position != null) lastPosition = position
    val wasNotifying = view.style.locked && view.style.fallbackUnlockNotification
    view.applyStyle(style)
    layoutOverlay(view, position)
    if (wasNotifying != (style.locked && style.fallbackUnlockNotification)) syncNotification(style)
  }

  fun updateLine(primaryText: String, secondaryText: String?) {
    val view = overlay ?: return
    if (view.updateLine(primaryText, secondaryText)) layoutOverlay(view)
  }

  fun setPlaying(isPlaying: Boolean) {
    overlay?.setPlaying(isPlaying)
  }

  fun setLocked(locked: Boolean, fallbackUnlockNotification: Boolean) {
    val view = overlay ?: return
    val style = view.style.copy(locked = locked, fallbackUnlockNotification = fallbackUnlockNotification)
    view.applyStyle(style)
    layoutOverlay(view)
    syncNotification(style)
  }

  fun handleNotificationAction(action: String) {
    val view = overlay
    if (view == null) {
      notification.cancel()
    } else if (view.style.locked && view.style.fallbackUnlockNotification) {
      handleAction(action)
    }
  }

  private fun handleAction(action: String) {
    val view = overlay ?: return
    when (action) {
      "lock" -> setLocked(true, view.style.fallbackUnlockNotification)
      "unlock" -> setLocked(false, view.style.fallbackUnlockNotification)
      "close" -> hide()
      "openSettings" -> application.startActivity(
        Intent(application, NamidaMainActivity::class.java)
          .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
      )
    }
    onAction(action)
  }

  private fun syncNotification(style: FloatingLyricsStyle) {
    if (style.locked && style.fallbackUnlockNotification) notification.show() else notification.cancel()
  }

  private fun layoutOverlay(view: FloatingLyricsOverlayView, position: FloatingLyricsPosition? = null) {
    val style = view.style
    val width = (screen.x * style.widthPercent / 100f).toInt()
    view.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(screen.y, MeasureSpec.AT_MOST),
    )
    maxX = (screen.x - width).coerceAtLeast(0)
    maxY = (screen.y - view.measuredHeight).coerceAtLeast(0)
    val x = (position?.let { (screen.x * it.xPercent / 100.0).roundToInt() } ?: params.x).coerceIn(0, maxX)
    val y = (position?.let { (screen.y * it.yPercent / 100.0).roundToInt() } ?: params.y).coerceIn(0, maxY)
    val flags = if (style.locked) WINDOW_FLAGS or LayoutParams.FLAG_NOT_TOUCHABLE else WINDOW_FLAGS
    val alpha = if (style.locked) minOf(style.opacity, maxTouchOpacity()) else 1f
    if (params.width == width && params.x == x && params.y == y && params.flags == flags && params.alpha == alpha) return

    params.width = width
    params.x = x
    params.y = y
    params.flags = flags
    params.alpha = alpha
    if (overlay === view) windowManager.updateViewLayout(view, params)
  }

  @Suppress("DEPRECATION")
  private fun screenSize(): Point {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
      return Point().also { windowManager.defaultDisplay.getSize(it) }
    }
    val metrics = windowManager.maximumWindowMetrics
    val insets = metrics.windowInsets.getInsetsIgnoringVisibility(params.fitInsetsTypes)
    return Point(metrics.bounds.width() - insets.left - insets.right, metrics.bounds.height() - insets.top - insets.bottom)
  }

  private fun maxTouchOpacity(): Float = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    val inputManager = application.getSystemService(Context.INPUT_SERVICE) as InputManager
    minOf(0.8f, inputManager.maximumObscuringOpacityForTouch)
  } else {
    1f
  }

  private fun dragBy(dx: Int, dy: Int) {
    val view = overlay ?: return
    val x = (params.x + dx).coerceIn(0, maxX)
    val y = (params.y + dy).coerceIn(0, maxY)
    if (params.x == x && params.y == y) return
    params.x = x
    params.y = y
    windowManager.updateViewLayout(view, params)
  }

  private fun finishDrag() {
    lastPosition = FloatingLyricsPosition(params.x * 100.0 / screen.x, params.y * 100.0 / screen.y)
    onPositionChanged(lastPosition)
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    val view = overlay ?: return
    screen = screenSize()
    view.applyStyle(view.style)
    layoutOverlay(view, lastPosition)
  }

  override fun onDisplayChanged(displayId: Int) {
    val view = overlay ?: return
    if (displayId != Display.DEFAULT_DISPLAY) return
    val size = screenSize()
    if (screen == size) return
    screen = size
    layoutOverlay(view, lastPosition)
  }

  override fun onDisplayAdded(displayId: Int) = Unit
  override fun onDisplayRemoved(displayId: Int) = Unit
  override fun onLowMemory() = Unit
}
