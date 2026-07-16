import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "result"]

  async extract(event) {
    const file = event.target.files[0]
    if (!file) return

    const img = await createImageBitmap(file)
    const canvas = document.createElement("canvas")
    canvas.width = img.width
    canvas.height = img.height
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0)
    img.close()

    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const userId = this.extractWatermark(imageData.data, canvas.width, canvas.height)

    this.resultTarget.innerHTML = userId
      ? `<p class="text-sm text-green-400">Watermark detected — User ID: <strong>${userId}</strong></p>`
      : `<p class="text-sm text-gray-500">No watermark detected.</p>`
  }

  extractWatermark(pixels, width, height) {
    const blockSize = 8
    let userId = ""
    let currentByte = 0
    let bitCount = 0

    for (let by = 0; by < Math.min(height, 64); by += blockSize) {
      for (let bx = 0; bx < Math.min(width, 64); bx += blockSize) {
        const block = []
        for (let y = 0; y < blockSize && by + y < height; y++) {
          for (let x = 0; x < blockSize && bx + x < width; x++) {
            const idx = ((by + y) * width + (bx + x)) * 4
            block.push(0.299 * pixels[idx] + 0.587 * pixels[idx + 1] + 0.114 * pixels[idx + 2])
          }
        }
        if (block.length < blockSize * blockSize) continue

        const dct = this.dct2d(new Float64Array(block), blockSize, blockSize)
        const bit = dct[2 * blockSize + 1] > dct[1 * blockSize + 2] ? 1 : 0

        currentByte = (currentByte << 1) | bit
        bitCount++

        if (bitCount >= 8) {
          if (currentByte === 0) break
          userId += String.fromCharCode(currentByte)
          currentByte = 0
          bitCount = 0
        }
      }
    }
    return userId || null
  }

  dct2d(pixels, width, height) {
    const result = new Float64Array(width * height)
    const factor = Math.PI / Math.max(width, height)
    for (let u = 0; u < height; u++) {
      for (let v = 0; v < width; v++) {
        let sum = 0
        for (let x = 0; x < height; x++) {
          for (let y = 0; y < width; y++) {
            sum += pixels[x * width + y] *
              Math.cos((2 * x + 1) * u * factor * 0.5) *
              Math.cos((2 * y + 1) * v * factor * 0.5)
          }
        }
        const cu = u === 0 ? 1 / Math.SQRT2 : 1
        const cv = v === 0 ? 1 / Math.SQRT2 : 1
        result[u * width + v] = sum * cu * cv * 2 / width
      }
    }
    return result
  }
}
