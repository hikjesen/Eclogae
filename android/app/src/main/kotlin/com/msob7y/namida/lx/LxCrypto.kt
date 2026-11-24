package com.msob7y.namida.lx

import android.util.Base64
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

internal object LxCrypto {
  fun base64Encode(data: ByteArray): String = Base64.encodeToString(data, Base64.NO_WRAP)

  fun base64Decode(data: String): ByteArray = Base64.decode(data, Base64.DEFAULT)

  fun md5(data: String): String = digest("MD5", data)

  fun sha1(data: String): String = digest("SHA-1", data)

  private fun digest(algorithm: String, data: String): String =
    MessageDigest.getInstance(algorithm).digest(data.toByteArray(Charsets.UTF_8))
      .joinToString("") { "%02x".format(it) }

  fun aesEncrypt(data: String, key: String, iv: String, mode: String): String =
    base64Encode(aes(Cipher.ENCRYPT_MODE, data, key, iv, mode))

  fun aesDecrypt(data: String, key: String, iv: String, mode: String): String =
    aes(Cipher.DECRYPT_MODE, data, key, iv, mode).toString(Charsets.UTF_8)

  private fun aes(operation: Int, data: String, key: String, iv: String, mode: String): ByteArray {
    val cipher = Cipher.getInstance(mode)
    val secretKey = SecretKeySpec(base64Decode(key), "AES")
    if (iv.isEmpty()) {
      cipher.init(operation, secretKey)
    } else {
      cipher.init(operation, secretKey, IvParameterSpec(base64Decode(iv).copyOf(16)))
    }
    return cipher.doFinal(base64Decode(data))
  }

  fun rsaEncrypt(data: String, publicKey: String, padding: String): String {
    val keySpec = X509EncodedKeySpec(base64Decode(publicKey.trim()))
    val key = KeyFactory.getInstance("RSA").generatePublic(keySpec)
    val cipher = Cipher.getInstance(padding)
    cipher.init(Cipher.ENCRYPT_MODE, key)
    return base64Encode(cipher.doFinal(base64Decode(data)))
  }
}
