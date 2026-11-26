package com.msob7y.namida.floatinglyrics

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.SystemClock
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.CharacterStyle
import android.text.style.RelativeSizeSpan
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.animation.DecelerateInterpolator
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.msob7y.namida.R
import kotlin.math.roundToInt

internal class FloatingLyricsOverlayView(
  context: Context,
  initialStyle: FloatingLyricsStyle,
  private var isPlaying: Boolean,
  screenOn: Boolean,
  private val onAction: (String) -> Unit,
  private val onDrag: (Int, Int) -> Unit,
  private val onDragFinished: () -> Unit,
  private val onToolbarChanged: () -> Unit,
) : LinearLayout(context) {
  var style = initialStyle
    private set

  private val lyrics = LyricTextView(context)
  private val toolbar = LinearLayout(context).apply {
    gravity = Gravity.CENTER
    background = roundedBackground(0xEE18181B.toInt(), 24)
    visibility = GONE
  }
  private val overlayBackground = roundedBackground(0xAA18181B.toInt(), 14)
  private val playButton: ImageButton
  private val hideToolbar = Runnable { setToolbarVisible(false) }
  private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()
  private var isDragging = false
  private var dragX = 0f
  private var dragY = 0f
  private var primaryText = ""
  private var secondaryText: String? = null
  private val lyricAlpha: Float get() = (if (style.locked) 1f else style.opacity) * (if (isPlaying) 1f else 0.6f)
  private val isToolbarVisible: Boolean get() = toolbar.visibility == VISIBLE

  init {
    orientation = VERTICAL
    addView(lyrics, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    addView(toolbar, LayoutParams(0, dp(48)).apply {
      gravity = Gravity.CENTER_HORIZONTAL
      bottomMargin = dp(4)
    })
    playButton = addToolbarButton("播放", "togglePlayPause")
    addToolbarButton("锁定", "lock").setImageResource(R.drawable.floating_lyric_lock)
    addToolbarButton("设置", "openSettings").setImageDrawable(SettingsIcon(dp(24)))
    addToolbarButton("关闭", "close").setImageResource(R.drawable.stop)
    updatePlayButton()
    lyrics.setScreenOn(screenOn)
    applyStyle(initialStyle)
    lyrics.alpha = lyricAlpha
  }

  fun applyStyle(updatedStyle: FloatingLyricsStyle) {
    val oldAlpha = lyricAlpha
    val modeChanged = style.singleLine != updatedStyle.singleLine
    style = updatedStyle
    lyrics.applyStyle(style)
    if (modeChanged) renderLine()
    if (oldAlpha != lyricAlpha || !style.toggleAnimation) resetLineAnimation()
    isClickable = !style.locked
    if (style.locked) {
      isDragging = false
      setToolbarVisible(false, notifyLayout = false)
    }
    updateBackground()
  }

  fun updateLine(primaryText: String, secondaryText: String?): Boolean {
    val primaryChanged = this.primaryText != primaryText
    if (!primaryChanged && this.secondaryText == secondaryText) return false
    this.primaryText = primaryText
    this.secondaryText = secondaryText
    if (!primaryChanged && style.singleLine) return false
    renderLine()
    if (primaryChanged && style.toggleAnimation && isAttachedToWindow) {
      lyrics.animate().cancel()
      lyrics.alpha = lyricAlpha * 0.7f
      lyrics.translationY = dp(3).toFloat()
      lyrics.animate().alpha(lyricAlpha).translationY(0f)
        .setInterpolator(DecelerateInterpolator()).setDuration(220L).start()
    }
    return true
  }

  fun setPlaying(playing: Boolean) {
    if (isPlaying == playing) return
    isPlaying = playing
    updatePlayButton()
    resetLineAnimation()
  }

  fun setScreenOn(screenOn: Boolean) {
    lyrics.setScreenOn(screenOn)
  }

  private fun renderLine() {
    val secondary = secondaryText
    lyrics.text = if (!style.singleLine && !secondary.isNullOrEmpty()) {
      SpannableStringBuilder(primaryText).append('\n').apply {
        val start = length
        append(secondary)
        setSpan(RelativeSizeSpan(0.8f), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        setSpan(SecondaryAlphaSpan, start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    } else {
      primaryText
    }
    lyrics.resetMarquee()
  }

  private fun resetLineAnimation() {
    lyrics.animate().cancel()
    lyrics.alpha = lyricAlpha
    lyrics.translationY = 0f
  }

  private fun addToolbarButton(label: String, action: String): ImageButton = ImageButton(context).apply {
    contentDescription = label
    layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, 1f)
    background = RippleDrawable(ColorStateList.valueOf(0x33FFFFFF), null, roundedBackground(Color.WHITE, 24))
    imageTintList = ColorStateList.valueOf(0xFFDDDDDD.toInt())
    setPadding(dp(2), 0, dp(2), 0)
    scaleType = ImageView.ScaleType.CENTER_INSIDE
    setOnClickListener {
      if (action == "togglePlayPause") scheduleToolbarHide()
      onAction(action)
    }
    toolbar.addView(this)
  }

  private fun updatePlayButton() {
    playButton.setImageResource(if (isPlaying) R.drawable.pause else R.drawable.play)
    playButton.contentDescription = if (isPlaying) "暂停" else "播放"
  }

  private fun setToolbarVisible(visible: Boolean, notifyLayout: Boolean = true) {
    if (isToolbarVisible == visible) return
    toolbar.visibility = if (visible) VISIBLE else GONE
    if (visible) scheduleToolbarHide() else removeCallbacks(hideToolbar)
    updateBackground()
    if (notifyLayout) onToolbarChanged()
  }

  private fun scheduleToolbarHide() {
    removeCallbacks(hideToolbar)
    postDelayed(hideToolbar, 3500L)
  }

  private fun updateBackground() {
    background = if (!style.locked && (isToolbarVisible || isDragging)) overlayBackground else null
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val toolbarParams = toolbar.layoutParams as LayoutParams
    toolbarParams.width = (MeasureSpec.getSize(widthMeasureSpec) - dp(8)).coerceIn(0, dp(192))
    toolbarParams.height = dp(48)
    toolbarParams.bottomMargin = dp(4)
    super.onMeasure(widthMeasureSpec, heightMeasureSpec)
  }

  override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
    if (style.locked) return false
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        dragX = event.rawX
        dragY = event.rawY
      }
      MotionEvent.ACTION_MOVE -> {
        if (pastTouchSlop(event)) {
          moveDrag(event)
          return true
        }
      }
    }
    return false
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    if (style.locked) return false
    when (event.actionMasked) {
      MotionEvent.ACTION_MOVE -> if (isDragging || pastTouchSlop(event)) moveDrag(event)
      MotionEvent.ACTION_UP -> {
        if (isDragging || pastTouchSlop(event)) {
          moveDrag(event)
          endDrag()
          onDragFinished()
        } else {
          performClick()
        }
      }
      MotionEvent.ACTION_CANCEL -> endDrag()
    }
    return true
  }

  override fun performClick(): Boolean {
    super.performClick()
    if (style.locked) return false
    setToolbarVisible(!isToolbarVisible)
    return true
  }

  private fun pastTouchSlop(event: MotionEvent): Boolean {
    val dx = event.rawX - dragX
    val dy = event.rawY - dragY
    return dx * dx + dy * dy > touchSlop * touchSlop
  }

  private fun moveDrag(event: MotionEvent) {
    if (!isDragging) {
      isDragging = true
      setToolbarVisible(false)
      updateBackground()
    }
    val dx = (event.rawX - dragX).roundToInt()
    val dy = (event.rawY - dragY).roundToInt()
    onDrag(dx, dy)
    dragX += dx
    dragY += dy
  }

  private fun endDrag() {
    isDragging = false
    updateBackground()
  }

  override fun onDetachedFromWindow() {
    removeCallbacks(hideToolbar)
    resetLineAnimation()
    super.onDetachedFromWindow()
  }

  private fun roundedBackground(color: Int, radius: Int) = GradientDrawable().apply {
    setColor(color)
    cornerRadius = dp(radius).toFloat()
  }

  private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

  private object SecondaryAlphaSpan : CharacterStyle() {
    override fun updateDrawState(paint: TextPaint) {
      paint.alpha = (paint.alpha * 0.78f).roundToInt()
    }
  }
}

private class LyricTextView(context: Context) : TextView(context) {
  private var singleLineMode = false
  private var horizontalGravity = Gravity.LEFT
  private var textOutline = false
  private var strokeWidth = 0f
  private var marqueeStartedAt = 0L
  private var marqueePausedAt: Long? = null
  private val marqueeFrame = Runnable { invalidate() }

  fun applyStyle(style: FloatingLyricsStyle) {
    val marqueeStyleChanged = singleLineMode != style.singleLine || horizontalGravity != style.textGravity
    if (singleLineMode != style.singleLine) {
      singleLineMode = style.singleLine
      setSingleLine(singleLineMode)
    }
    val oldTextSize = textSize
    horizontalGravity = style.textGravity
    gravity = Gravity.TOP or (if (singleLineMode) Gravity.LEFT else horizontalGravity)
    maxLines = if (singleLineMode) 1 else style.maxLines
    ellipsize = if (singleLineMode) null else TextUtils.TruncateAt.END
    textSize = style.fontSizeSp
    setTextColor(style.textColorArgb)
    textOutline = style.textOutline
    val density = resources.displayMetrics.density
    strokeWidth = 2f * density
    setShadowLayer(2f * density, 0f, density, 0xBB000000.toInt())
    val horizontalPadding = (10f * density).roundToInt()
    val verticalPadding = (5f * density).roundToInt()
    setPadding(horizontalPadding, verticalPadding, horizontalPadding, verticalPadding)
    if (marqueeStyleChanged || oldTextSize != textSize) resetMarquee()
  }

  fun setScreenOn(screenOn: Boolean) {
    val pausedAt = marqueePausedAt
    if (screenOn && pausedAt != null) {
      marqueeStartedAt += SystemClock.uptimeMillis() - pausedAt
      marqueePausedAt = null
      invalidate()
    } else if (!screenOn && pausedAt == null) {
      marqueePausedAt = SystemClock.uptimeMillis()
      removeCallbacks(marqueeFrame)
    }
  }

  fun resetMarquee() {
    marqueeStartedAt = marqueePausedAt ?: SystemClock.uptimeMillis()
    removeCallbacks(marqueeFrame)
    invalidate()
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    resetMarquee()
  }

  override fun onDetachedFromWindow() {
    removeCallbacks(marqueeFrame)
    super.onDetachedFromWindow()
  }

  override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
    super.onSizeChanged(width, height, oldWidth, oldHeight)
    if (width != oldWidth) resetMarquee()
  }

  override fun onDraw(canvas: Canvas) {
    val textLayout = layout ?: return
    canvas.save()
    canvas.translate((scrollX + compoundPaddingLeft).toFloat(), (scrollY + extendedPaddingTop).toFloat())
    if (singleLineMode) {
      drawMarquee(canvas, textLayout)
    } else {
      drawText(canvas, textLayout, 0f)
    }
    canvas.restore()
  }

  private fun drawMarquee(canvas: Canvas, textLayout: Layout) {
    val viewport = width - compoundPaddingLeft - compoundPaddingRight
    val textWidth = textLayout.getLineWidth(0)
    val lineLeft = textLayout.getLineLeft(0)
    val freeSpace = viewport - textWidth
    if (freeSpace >= 0f) {
      val offset = when (horizontalGravity) {
        Gravity.RIGHT -> freeSpace
        Gravity.CENTER_HORIZONTAL -> freeSpace / 2f
        else -> 0f
      }
      drawText(canvas, textLayout, offset - lineLeft)
      return
    }

    canvas.clipRect(0f, -extendedPaddingTop.toFloat(), viewport.toFloat(), (height - extendedPaddingTop).toFloat())
    val density = resources.displayMetrics.density
    val cycle = textWidth + 24f * density
    val elapsed = (marqueePausedAt ?: SystemClock.uptimeMillis()) - marqueeStartedAt
    val offset = ((elapsed - MARQUEE_DELAY_MS).coerceAtLeast(0L) * 0.032f * density) % cycle
    val rtl = textLayout.getParagraphDirection(0) == Layout.DIR_RIGHT_TO_LEFT
    val origin = if (rtl) freeSpace + offset else -offset
    drawText(canvas, textLayout, origin - lineLeft)
    if (offset + viewport > cycle) {
      drawText(canvas, textLayout, origin - lineLeft + if (rtl) -cycle else cycle)
    }
    if (marqueePausedAt == null && isAttachedToWindow) {
      removeCallbacks(marqueeFrame)
      if (elapsed < MARQUEE_DELAY_MS) {
        postDelayed(marqueeFrame, MARQUEE_DELAY_MS - elapsed)
      } else {
        postOnAnimation(marqueeFrame)
      }
    }
  }

  private fun drawText(canvas: Canvas, textLayout: Layout, offset: Float) {
    canvas.save()
    canvas.translate(offset, 0f)
    val textPaint = textLayout.paint
    if (textOutline) {
      textPaint.color = Color.argb(Color.alpha(currentTextColor), 18, 18, 18)
      textPaint.style = Paint.Style.STROKE
      textPaint.strokeWidth = strokeWidth
      textPaint.strokeJoin = Paint.Join.ROUND
      textLayout.draw(canvas)
      textPaint.style = Paint.Style.FILL
    }
    textPaint.color = currentTextColor
    textLayout.draw(canvas)
    canvas.restore()
  }

  private companion object {
    const val MARQUEE_DELAY_MS = 1200L
  }
}

private class SettingsIcon(private val size: Int) : Drawable() {
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    color = 0xFFDDDDDD.toInt()
    style = Paint.Style.STROKE
    strokeCap = Paint.Cap.ROUND
    strokeWidth = 2.5f
  }

  override fun draw(canvas: Canvas) {
    canvas.save()
    canvas.translate(bounds.exactCenterX(), bounds.exactCenterY())
    canvas.scale(bounds.width() / 24f, bounds.height() / 24f)
    canvas.drawCircle(0f, 0f, 6f, paint)
    repeat(8) {
      canvas.drawLine(0f, -6f, 0f, -9.2f, paint)
      canvas.rotate(45f)
    }
    canvas.restore()
  }

  override fun getIntrinsicWidth(): Int = size
  override fun getIntrinsicHeight(): Int = size
  override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

  override fun setAlpha(alpha: Int) {
    paint.alpha = alpha
    invalidateSelf()
  }

  override fun setColorFilter(colorFilter: ColorFilter?) {
    paint.colorFilter = colorFilter
    invalidateSelf()
  }
}
