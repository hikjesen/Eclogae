package com.wander.eclogae.lx

import com.whl.quickjs.wrapper.JSObject

internal class LxMusicSdkRuntime(emit: (LxRuntime, Map<String, Any?>) -> Unit) :
  LxRuntime("LxMusicSdkThread", "music_sdk", emit) {

  fun load(bundle: String, previous: Thread?, complete: (Throwable?) -> Unit) {
    start(previous, configure = { js ->
      bindGlobals(js.getGlobalObject())
      (js.evaluate(bundle) as? JSObject)?.release()
    }) { failure ->
      if (failure != null) clearContext()
      complete(failure)
    }
  }

  fun send(action: String, data: String): Boolean = postGlobal("__lx_sdk_dispatch__", action, data)

  private fun bindGlobals(global: JSObject) = with(global) {
    bind("__lx_sdk_call__") { args ->
      emitAction(args[0] as String, args.getOrNull(1) as String?)
      null
    }
    bind("__lx_sdk_set_timeout__") { args ->
      val id = args[0]
      timeoutHandler.postDelayed(
        { invokeGlobal("__lx_sdk_on_timeout__", id) },
        (args[1] as Number).toLong(),
      )
      null
    }
    bind("__lx_sdk_md5__") { args -> LxCrypto.md5(args[0] as String) }
    bind("__lx_sdk_sha1__") { args -> LxCrypto.sha1(args[0] as String) }
    bind("__lx_sdk_aes_encrypt__") { args ->
      LxCrypto.aesEncrypt(args[0] as String, args[1] as String, args[2] as String, args[3] as String)
    }
    bind("__lx_sdk_aes_decrypt__") { args ->
      LxCrypto.aesDecrypt(args[0] as String, args[1] as String, args[2] as String, args[3] as String)
    }
    bind("__lx_sdk_rsa_encrypt__") { args ->
      LxCrypto.rsaEncrypt(args[0] as String, args[1] as String, args[2] as String)
    }
  }
}
