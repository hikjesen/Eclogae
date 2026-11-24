import { Buffer } from 'buffer'

export const btoa = text => Buffer.from(text, 'latin1').toString('base64')
export const atob = text => Buffer.from(text, 'base64').toString('latin1')
