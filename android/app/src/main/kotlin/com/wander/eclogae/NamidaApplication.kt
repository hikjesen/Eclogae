package com.wander.eclogae

import android.app.Application
import com.wander.eclogae.floatinglyrics.FloatingLyricsBridge
import com.ryanheise.audioservice.AudioServicePlugin

class NamidaApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    ProcessExitReporter.installJavaCrashRecorder(this)
    FloatingLyricsBridge.get(this)
    AudioServicePlugin.setFlutterEngineConfigurator { flutterEngine -> NamidaAppChannels.get(this).configureEngine(flutterEngine) }
  }
}
