import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "progress", "preview"]

  trigger() {
    this.inputTarget.click()
  }

  async process(event) {
    const file = event.target.files[0]
    if (!file) return

    const isGif = file.type === "image/gif"
    const isVideo = file.type.startsWith("video/")
    const mediaType = isVideo ? "video" : (isGif ? "gif" : "image")

    this.showProgress("Processing...")

    let pHash = ""

    try {
      let blob

      if (isGif) {
        const result = await this.transcodeGif(file)
        blob = result.blob
        pHash = result.pHash
      } else if (!isVideo) {
        const result = await this.compressImage(file)
        blob = result.blob
        pHash = result.pHash
      } else {
        blob = file
      }

      // Forensic watermark is applied server-side (Active Job) to avoid client-side quality loss.
      const ext = isGif ? "gif" : (isVideo ? (file.name.split('.').pop() || "mp4") : "webp")
      const processedFile = new File([blob], `media.${ext}`, { type: blob.type || file.type || "image/webp" })
      const dt = new DataTransfer()
      dt.items.add(processedFile)
      this.inputTarget.files = dt.files
    } catch (error) {
      console.error("Media processing failed, using original file:", error)
    }

    this.element.querySelector('input[name="post[media_type]"]').value = mediaType
    this.element.querySelector('input[name="post[perceptual_hash]"]').value = pHash || ""
    this.element.querySelector('input[name="post[media_signed_id]"]').value = ""

    try {
      const url = URL.createObjectURL(this.inputTarget.files[0])
      this.previewTarget.innerHTML = `<img src="${url}" class="max-h-64 mx-auto rounded">`
      this.previewTarget.classList.remove("hidden")
    } catch (error) {}

    this.showProgress("Ready! Click Post to submit.")
  }

  async compressImage(file) {
    const img = await createImageBitmap(file)
    const canvas = document.createElement("canvas")
    const maxDim = 1920
    let { width, height } = img
    if (width > maxDim || height > maxDim) {
      const ratio = Math.min(maxDim / width, maxDim / height)
      width = Math.round(width * ratio)
      height = Math.round(height * ratio)
    }
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, width, height)

    const blob = await this.canvasToBlob(canvas, "image/webp", 0.95)
    const pHash = await this.computePerceptualHash(canvas)

    return { blob, pHash }
  }

  async transcodeGif(file) {
    // In production: use ffmpeg.wasm
    // For now, pass through as-is (browser supports GIF natively)
    const arrayBuffer = await file.arrayBuffer()
    const blob = new Blob([arrayBuffer], { type: file.type })

    // Simple pHash from first frame canvas
    const img = await createImageBitmap(file)
    const canvas = document.createElement("canvas")
    canvas.width = 32
    canvas.height = 32
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, 32, 32)
    img.close()
    const pHash = await this.computePerceptualHash(canvas)

    return { blob, pHash }
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

  async computePerceptualHash(canvas) {
    const size = 32
    const small = document.createElement("canvas")
    small.width = size
    small.height = size
    const sCtx = small.getContext("2d")
    sCtx.drawImage(canvas, 0, 0, size, size)
    const data = sCtx.getImageData(0, 0, size, size).data

    const pixels = []
    for (let i = 0; i < data.length; i += 4) {
      pixels.push(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2])
    }

    const dct = this.dct2d(new Float64Array(pixels), size, size)
    const coeffs = []
    for (let y = 0; y < 8; y++) {
      for (let x = 0; x < 8; x++) {
        if (x === 0 && y === 0) continue
        coeffs.push(dct[y * size + x])
      }
    }
    const sorted = [...coeffs].sort((a, b) => a - b)
    const median = sorted[Math.floor(sorted.length / 2)]
    return coeffs.map(c => c > median ? "1" : "0").join("")
  }

  async canvasToBlob(canvas, type, quality) {
    return new Promise(resolve => canvas.toBlob(resolve, type, quality))
  }

  showProgress(message) {
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = message
    }
  }
}
