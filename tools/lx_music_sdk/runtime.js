import { Buffer } from 'buffer'
import { btoa, atob } from './base64.js'
import { setTimeout, clearTimeout, onTimeout } from './timer.js'

Object.assign(globalThis, { Buffer, btoa, atob, setTimeout, clearTimeout, __lx_sdk_on_timeout__: onTimeout })
