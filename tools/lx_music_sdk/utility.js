import he from 'he'

export { formatPlayTime, sizeFormate } from 'lx/common.ts'
export const decodeName = text => text ? he.decode(text) : ''
