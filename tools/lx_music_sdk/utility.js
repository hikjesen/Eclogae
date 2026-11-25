import he from 'he'

export { formatPlayTime, sizeFormate, dateFormat } from 'lx/common.ts'
export const decodeName = text => text ? he.decode(text) : ''

export function formatPlayCount(num) {
  if (num > 100000000) return `${Math.trunc(num / 10000000) / 10}亿`
  if (num > 10000) return `${Math.trunc(num / 1000) / 10}万`
  return String(num)
}
