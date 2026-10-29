import { DishesNative, isNative, publicRoot } from '../native'

export const issuedStickerUrl = token => `${publicRoot}?tag=${encodeURIComponent(token)}`
export async function writeIssuedSticker(token, { lock = false, confirmed = false, verifyOnly = false, signal } = {}) {
  if (!isNative) throw new Error('Use the Android app’s Tag workshop to write and verify batches. This browser can create batches and export their URLs.')
  if (lock && !confirmed) throw new Error('Confirm that permanent locking cannot be undone.')
  if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
  const cancel = () => DishesNative.cancelWrite().catch(() => {})
  signal?.addEventListener('abort', cancel, { once: true })
  try {
    const receipt=await DishesNative.writeTag({ url: issuedStickerUrl(token), blankOnly: true, verifyOnly, lock, lockConfirmed: confirmed })
    if(!receipt||typeof receipt.verified!=='boolean')throw new Error('This Android build cannot verify batch writes. Install your next rebuilt app before provisioning tags.')
    return receipt
  }
  finally { signal?.removeEventListener('abort', cancel) }
}
