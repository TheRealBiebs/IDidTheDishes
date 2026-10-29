import { Capacitor, registerPlugin } from '@capacitor/core'

export const isNative = Capacitor.isNativePlatform()
export const DishesNative = registerPlugin('DishesNative')
export const publicRoot = 'https://therealbiebs.github.io/IDidTheDishes/'
export const authRedirectUrl = () => isNative ? 'io.github.therealbiebs.ididthedishes://auth/callback' : new URL(import.meta.env.BASE_URL, location.href).href
export const nativeStorage = {
  async getItem(key) { return (await DishesNative.getSecure({ key })).value ?? null },
  async setItem(key, value) { await DishesNative.setSecure({ key, value }) },
  async removeItem(key) { await DishesNative.removeSecure({ key }) },
}
export function stickerToken(value) {
  try {
    const url = new URL(value)
    const root = new URL(isNative ? publicRoot : new URL(import.meta.env.BASE_URL, location.href))
    const token = url.searchParams.get('tag')
    return url.origin === root.origin && url.pathname === root.pathname && /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(token || '') ? token : null
  } catch { return null }
}
