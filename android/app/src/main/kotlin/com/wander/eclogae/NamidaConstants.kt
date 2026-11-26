package com.wander.eclogae

object NamidaConstants {
  const val ACTION_CUSTOM_START = "com.wander.eclogae.CUSTOM_START"
  const val BABE_WAKE_UP = "com.wander.eclogae.BABE_WAKE_UP"

  // set when a media command is sent by us (home widget/quick settings tile),
  // used to differentiate our commands from external ones (bluetooth, system resumption, etc)
  // which shouldn't start playback on a cold start.
  @Volatile @JvmField var selfSentMediaCommand = false
}
