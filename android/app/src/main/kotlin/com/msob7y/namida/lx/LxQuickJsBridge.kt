package com.msob7y.namida.lx

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import com.whl.quickjs.android.QuickJSLoader
import com.whl.quickjs.wrapper.JSCallFunction
import com.whl.quickjs.wrapper.JSObject
import com.whl.quickjs.wrapper.QuickJSContext
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal object LxQuickJsBridge : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private var messenger: BinaryMessenger? = null
  private var methodChannel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private var eventSink: EventChannel.EventSink? = null
  private var userApi: LxUserApiRuntime? = null
  private var musicSdk: LxMusicSdkRuntime? = null
  private var userApiShutdown: Thread? = null
  private var musicSdkShutdown: Thread? = null

  fun get(@Suppress("UNUSED_PARAMETER") context: Context): LxQuickJsBridge = this

  fun attach(engine: FlutterEngine) {
    val newMessenger = engine.dartExecutor.binaryMessenger
    if (messenger === newMessenger) return
    methodChannel?.setMethodCallHandler(null)
    eventChannel?.setStreamHandler(null)
    eventSink = null
    messenger = newMessenger

    methodChannel = MethodChannel(newMessenger, "namida/lx_bridge").apply {
      setMethodCallHandler(::handleCall)
    }
    eventChannel = EventChannel(newMessenger, "namida/lx_events").apply {
      setStreamHandler(this@LxQuickJsBridge)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  private fun emit(runtime: LxRuntime, event: Map<String, Any?>) {
    mainHandler.post {
      if (runtime === userApi || runtime === musicSdk) eventSink?.success(event)
    }
  }

  private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
    val arguments = call.arguments as? Map<*, *>
    fun string(name: String): String = arguments?.get(name) as? String
      ?: throw IllegalArgumentException("$name must be a string")

    try {
      when (call.method) {
        "loadUserApi" -> {
          val script = LxUserApiRuntime.Script(
            preload = string("preloadScript"),
            id = string("id"),
            name = string("name"),
            description = string("description"),
            version = string("version"),
            author = string("author"),
            homepage = string("homepage"),
            source = string("script"),
          )
          val previous = userApi?.destroy() ?: userApiShutdown
          val runtime = LxUserApiRuntime(::emit)
          userApiShutdown = null
          userApi = runtime
          runtime.load(script, previous)
          result.success(true)
        }
        "sendUserApiAction" -> {
          val action = string("action")
          val data = arguments?.get("data")
          require(data == null || data is String) { "data must be a string or null" }
          result.success(userApi?.send(action, data as String?) ?: false)
        }
        "destroyUserApi" -> {
          val runtime = userApi
          userApi = null
          if (runtime == null) result.success(null)
          else userApiShutdown = runtime.destroy { mainHandler.post { result.success(null) } }
        }
        "initMusicSdk" -> initMusicSdk(string("bundleScript"), result)
        "sendMusicSdkAction" -> {
          val action = string("action")
          val data = string("data")
          result.success(musicSdk?.send(action, data) ?: false)
        }
        "destroyMusicSdk" -> {
          val runtime = musicSdk
          musicSdk = null
          if (runtime == null) result.success(null)
          else musicSdkShutdown = runtime.destroy { mainHandler.post { result.success(null) } }
        }
        else -> result.notImplemented()
      }
    } catch (e: IllegalArgumentException) {
      result.error("INVALID_ARGUMENTS", e.message, null)
    }
  }

  private fun initMusicSdk(bundle: String, result: MethodChannel.Result) {
    val previous = musicSdk?.destroy() ?: musicSdkShutdown
    val runtime = LxMusicSdkRuntime(::emit)
    musicSdkShutdown = null
    musicSdk = runtime
    runtime.load(bundle, previous) { failure ->
      mainHandler.post {
        if (failure == null) {
          result.success(true)
        } else {
          if (musicSdk === runtime) {
            musicSdk = null
            musicSdkShutdown = runtime.destroy()
          }
          result.error("MUSIC_SDK_INIT", failure.message, null)
        }
      }
    }
  }
}

internal abstract class LxRuntime(
  threadName: String,
  private val engine: String,
  private val emit: (LxRuntime, Map<String, Any?>) -> Unit,
) : QuickJSContext.Console {
  companion object {
    private var libraryLoaded = false

    @Synchronized
    private fun loadLibrary() {
      if (!libraryLoaded) {
        QuickJSLoader.init()
        libraryLoaded = true
      }
    }
  }

  private val thread = HandlerThread(threadName).apply { start() }
  private val handler = Handler(thread.looper)
  protected val timeoutHandler = Handler(thread.looper)
  private var context: QuickJSContext? = null

  protected fun start(
    previous: Thread?,
    configure: (QuickJSContext) -> Unit,
    complete: (Throwable?) -> Unit,
  ) {
    handler.post {
      val failure = try {
        // Rapid reloads queue behind teardown without blocking Flutter's main thread.
        previous?.join()
        loadLibrary()
        val js = QuickJSContext.create()
        context = js
        js.setConsole(this)
        configure(js)
        null
      } catch (e: Exception) {
        e
      } catch (e: LinkageError) {
        e
      }
      complete(failure)
    }
  }

  fun destroy(complete: () -> Unit = {}): Thread {
    handler.post {
      try {
        clearContext()
      } finally {
        thread.quitSafely()
        complete()
      }
    }
    return thread
  }

  protected fun clearContext() {
    timeoutHandler.removeCallbacksAndMessages(null)
    val js = context
    context = null
    try {
      js?.destroy()
    } catch (e: Exception) {
      Log.e("LxQuickJsBridge", "Destroy $engine context", e)
    }
  }

  protected fun postGlobal(name: String, vararg args: Any?): Boolean =
    handler.post { invokeGlobal(name, *args) }

  protected fun invokeGlobal(name: String, vararg args: Any?) {
    val js = context ?: return
    try {
      js.callGlobal(name, *args)
    } catch (e: Exception) {
      error("Call $name: ${e.message ?: e.javaClass.simpleName}")
    }
  }

  protected fun QuickJSContext.callGlobal(name: String, vararg args: Any?) {
    val function = requireNotNull(getGlobalObject().getJSFunction(name)) { "Missing JS function $name" }
    try {
      function.callVoid(*args)
    } finally {
      function.release()
    }
  }

  protected fun JSObject.bind(
    name: String,
    errorValue: String? = null,
    callback: (Array<out Any?>) -> Any?,
  ) {
    setProperty(name, JSCallFunction { args ->
      try {
        callback(args)
      } catch (e: Exception) {
        error("Call $name: ${e.message ?: e.javaClass.simpleName}")
        errorValue
      }
    })
  }

  protected fun emitAction(action: String, data: String?) {
    emit(this, mapOf("engine" to engine, "action" to action, "data" to data))
  }

  private fun emitLog(level: String, message: String) {
    emit(this, mapOf("engine" to engine, "action" to "log", "level" to level, "message" to message))
  }

  override fun log(info: String?) = emitLog("log", info ?: "null")
  override fun info(info: String?) = emitLog("info", info ?: "null")
  override fun warn(info: String?) = emitLog("warn", info ?: "null")
  override fun error(info: String?) = emitLog("error", info ?: "null")
}
