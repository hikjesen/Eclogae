export const AES_MODE = {
  ECB_128_NoPadding: 'AES',
  CBC_128_PKCS7Padding: 'AES/CBC/PKCS7Padding',
}

export const RSA_PADDING = {
  OAEPWithSHA1AndMGF1Padding: 'RSA/ECB/OAEPWithSHA1AndMGF1Padding',
  NoPadding: 'RSA/ECB/NoPadding',
}

export const aesEncryptSync = (data, key, iv, mode) => globalThis.__lx_sdk_aes_encrypt__(data, key, iv, mode)
export const aesDecryptSync = (data, key, iv, mode) => globalThis.__lx_sdk_aes_decrypt__(data, key, iv, mode)

export const rsaEncryptSync = (data, key, padding) => globalThis.__lx_sdk_rsa_encrypt__(
  data,
  key.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g, ''),
  padding,
)
export const hashSHA1 = async text => globalThis.__lx_sdk_sha1__(text)
