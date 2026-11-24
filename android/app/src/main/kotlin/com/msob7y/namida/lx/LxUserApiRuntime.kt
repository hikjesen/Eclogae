package com.msob7y.namida.lx

import com.whl.quickjs.wrapper.JSObject
import java.net.URLDecoder
import java.util.UUID
import org.json.JSONObject

internal class LxUserApiRuntime(emit: (LxRuntime, Map<String, Any?>) -> Unit) :
  LxRuntime("LxUserApiThread", "user_api", emit) {

  data class Script(
    val preload: String,
    val id: String,
    val name: String,
    val description: String,
    val version: String,
    val author: String,
    val homepage: String,
    val source: String,
  )

  private val key = UUID.randomUUID().toString()
  private var initEmitted = false

  fun load(script: Script, previous: Thread?) {
    start(previous, configure = { js ->
      bindGlobals(js.getGlobalObject())
      (js.evaluate(script.preload) as? JSObject)?.release()
      js.callGlobal(
        "lx_setup", key, script.id, script.name, script.description,
        script.version, script.author, script.homepage, script.source,
      )
      (js.evaluate(script.source) as? JSObject)?.release()
    }) { failure ->
      if (failure != null) {
        val message = failure.message ?: failure.javaClass.simpleName
        error("Load user API script: $message")
        if (!initEmitted) {
          initEmitted = true
          invokeGlobal("__lx_native__", key, "__run_error__")
          val data = JSONObject()
            .put("info", JSONObject.NULL)
            .put("status", false)
            .put("errorMessage", message)
          emitAction("init", data.toString())
        }
      }
    }
  }

  fun send(action: String, data: String?): Boolean =
    if (data == null) postGlobal("__lx_native__", key, action)
    else postGlobal("__lx_native__", key, action, data)

  private fun bindGlobals(global: JSObject) = with(global) {
    bind("__lx_native_call__") { args ->
      if (args.getOrNull(0) == key) {
        val action = args[1] as String
        val data = args.getOrNull(2) as String?
        if (action != "init" || !initEmitted) {
          if (action == "init") initEmitted = true
          emitAction(action, data)
        }
      }
      null
    }
    bind("__lx_native_call__utils_str2b64", errorValue = "") { args ->
      LxCrypto.base64Encode((args[0] as String).toByteArray(Charsets.UTF_8))
    }
    bind("__lx_native_call__utils_b642buf", errorValue = "") { args ->
      LxCrypto.base64Decode(args[0] as String).joinToString(",", "[", "]")
    }
    bind("__lx_native_call__utils_str2md5", errorValue = "") { args ->
      LxCrypto.md5(URLDecoder.decode(args[0] as String, Charsets.UTF_8.name()))
    }
    bind("__lx_native_call__utils_aes_encrypt", errorValue = "") { args ->
      LxCrypto.aesEncrypt(args[0] as String, args[1] as String, args[2] as String, args[3] as String)
    }
    bind("__lx_native_call__utils_rsa_encrypt", errorValue = "") { args ->
      LxCrypto.rsaEncrypt(args[0] as String, args[1] as String, args[2] as String)
    }
    bind("__lx_native_call__set_timeout") { args ->
      val id = args[0] as Number
      timeoutHandler.postDelayed(
        { invokeGlobal("__lx_native__", key, "__set_timeout__", id) },
        (args[1] as Number).toLong(),
      )
      null
    }
  }
}
