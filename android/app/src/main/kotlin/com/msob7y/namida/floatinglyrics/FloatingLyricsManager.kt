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
import android.view.WindowManager
import android.view.WindowManager.LayoutParams
import androidx.core.content.ContextCompat
import com.msob7y.namida.NamidaMainActivity
import kotlin.math.roundToInt

internal data class FloatingLyricsPosition(val xPercent: Double, val yPercent: Double)

internal data class FloatingLyricsStyle(
  val locked: Boolean,
  val fallbackUnlockNotification: Boolean,
  val suppressed: Boolean,
  val singleLine: Boolean,
  val maxLines: Int,
  val toggleAnimation: Boolean,
  val fontSizeSp: Float,
  val opacity: Float,
  val widthPercent: Float,
  val textGravity: Int,
  val textColorArgb: Int,
  val textOutline: Boolean,
  val outlineColorArgb: Int,
) {
  val needsUnlockNotification: Boolean get() = !suppressed && locked && fallbackUnlockNotification
}

internal class FloatingLyricsManager(
  private val application: Application,
  private val onAction: (String) -> Unit,
  private val onPositionChanged: (FloatingLyricsPosition) -> Unit,
  private val onScreenStateChanged: (Boolean) -> Unit,
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
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      layoutInDisplayCutoutMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
      } else {
        LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
      }
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      fitInsetsTypes = 0
    }
  }

  private var overlay: FloatingLyricsOverlayView? = null
  private var screen = Point()
  private var screenOn = powerManager.isInteractive
  private var lastPosition = FloatingLyricsPosition(7.0, 12.0)
  private var maxX = 0
  private var maxY = 0
  private val screenReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      screenOn = when (intent.action) {
        Intent.ACTION_SCREEN_ON -> true
        Intent.ACTION_SCREEN_OFF -> false
        else -> return
      }
      overlay?.let { view ->
        if (view.setScreenOn(screenOn)) fitUpdatedLine(view)
      }
      onScreenStateChanged(screenOn)
    }
  }

  init {
    ContextCompat.registerReceiver(
      application,
      screenReceiver,
      IntentFilter(Intent.ACTION_SCREEN_OFF).apply { addAction(Intent.ACTION_SCREEN_ON) },
      ContextCompat.RECEIVER_NOT_EXPORTED,
    )
  }

  fun isScreenInteractive(): Boolean = powerManager.isInteractive

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
      screenOn,
      onAction = ::handleAction,
      onDragStarted = { overlay?.let { layoutOverlay(it) } },
      onDrag = ::dragBy,
      onDragFinished = ::finishDrag,
      onToolbarChanged = { overlay?.let { layoutOverlay(it) } },
    )
    view.updateLine(primaryText, secondaryText)
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
    syncNotification(style)
    return true
  }

  fun hide() {
    notification.cancel()
    val view = overlay ?: return
    overlay = null
    application.unregisterComponentCallbacks(this)
    displayManager.unregisterDisplayListener(this)
    windowManager.removeViewImmediate(view)
  }

  fun updateStyle(style: FloatingLyricsStyle, position: FloatingLyricsPosition?) {
    val view = overlay ?: return
    applyStyle(view, style, position)
  }

  private fun applyStyle(view: FloatingLyricsOverlayView, style: FloatingLyricsStyle, position: FloatingLyricsPosition? = null) {
    if (position != null) lastPosition = position
    val previousStyle = view.style
    view.applyStyle(style)
    val restoring = previousStyle.suppressed && !style.suppressed
    layoutOverlay(view, if (restoring) lastPosition else position)
    if (previousStyle.needsUnlockNotification != style.needsUnlockNotification) syncNotification(style)
  }

  fun updateLine(primaryText: String, secondaryText: String?) {
    val view = overlay ?: return
    if (view.updateLine(primaryText, secondaryText)) fitUpdatedLine(view)
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

  fun setSuppressed(suppressed: Boolean, fallbackUnlockNotification: Boolean) {
    val view = overlay ?: return
    val style = view.style.copy(suppressed = suppressed, fallbackUnlockNotification = fallbackUnlockNotification)
    applyStyle(view, style)
  }

  fun handleNotificationAction(action: String) {
    val view = overlay
    if (view == null) {
      notification.cancel()
    } else if (view.style.needsUnlockNotification) {
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
    if (style.needsUnlockNotification) notification.show() else notification.cancel()
  }

  private fun layoutOverlay(view: FloatingLyricsOverlayView, position: FloatingLyricsPosition? = null) {
    screen = screenSize()
    val style = view.style
    val width = if (style.suppressed) 1 else (screen.x * style.widthPercent / 100f).toInt()
    val height = if (style.suppressed) 1 else LayoutParams.WRAP_CONTENT
    val flags = if (style.locked || style.suppressed) WINDOW_FLAGS or LayoutParams.FLAG_NOT_TOUCHABLE else WINDOW_FLAGS
    val alpha = when {
      style.suppressed -> 0f
      style.locked -> minOf(style.opacity, maxTouchOpacity())
      else -> 1f
    }
    var x = params.x
    var y = params.y
    if (!style.suppressed) {
      maxX = (screen.x - width).coerceAtLeast(0)
      maxY = measureMaxY(view, width)
      x = (position?.let { (screen.x * it.xPercent / 100.0).roundToInt() } ?: x).coerceIn(0, maxX)
      y = (position?.let { (screen.y * it.yPercent / 100.0).roundToInt() } ?: y).coerceIn(0, maxY)
    }
    if (params.width == width && params.height == height && params.x == x && params.y == y &&
      params.flags == flags && params.alpha == alpha
    ) return

    params.width = width
    params.height = height
    params.x = x
    params.y = y
    params.flags = flags
    params.alpha = alpha
    if (overlay === view) windowManager.updateViewLayout(view, params)
  }

  private fun fitUpdatedLine(view: FloatingLyricsOverlayView) {
    val previousMaxY = maxY
    maxY = measureMaxY(view, params.width)
    if (params.y > maxY || (maxY != previousMaxY && params.y == previousMaxY)) layoutOverlay(view)
  }

  private fun measureMaxY(view: FloatingLyricsOverlayView, width: Int): Int {
    view.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(screen.y, MeasureSpec.AT_MOST),
    )
    return (screen.y - view.measuredHeight).coerceAtLeast(0)
  }

  @Suppress("DEPRECATION")
  private fun screenSize(): Point {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
      return Point().also { windowManager.defaultDisplay.getRealSize(it) }
    }
    val bounds = windowManager.maximumWindowMetrics.bounds
    return Point(bounds.width(), bounds.height())
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
    if (screen.x <= 0 || screen.y <= 0) return
    lastPosition = FloatingLyricsPosition(params.x * 100.0 / screen.x, params.y * 100.0 / screen.y)
    onPositionChanged(lastPosition)
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    val view = overlay ?: return
    view.applyStyle(view.style)
    layoutOverlay(view, lastPosition)
  }

  override fun onDisplayChanged(displayId: Int) {
    val view = overlay ?: return
    if (displayId != Display.DEFAULT_DISPLAY) return
    if (screen == screenSize()) return
    layoutOverlay(view, lastPosition)
  }

  override fun onDisplayAdded(displayId: Int) = Unit
  override fun onDisplayRemoved(displayId: Int) = Unit
  override fun onLowMemory() = Unit
}
