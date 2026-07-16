import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "video", "canvas", "status", "actions", "error", "retry", "result",
    "aiSection", "manualSection", "day", "month", "year"
  ]
  static values = { verified: Boolean }

  connect() {
    this.stream = null
    this.modelsLoaded = false
    this.loading = false
    this.loadModels()
  }

  disconnect() {
    this.stopCamera()
  }

  // ---- Model loading ----

  async loadModels() {
    if (this.loading) return
    this.loading = true
    this.showStatus("Loading age estimation model...")
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")

    try {
      await this.waitForFaceAPI()
      await Promise.all([
        faceapi.nets.tinyFaceDetector.loadFromUri("/models"),
        faceapi.nets.ageGenderNet.loadFromUri("/models"),
        faceapi.nets.faceLandmark68Net.loadFromUri("/models")
      ])
      this.modelsLoaded = true
      this.showStatus("Camera ready — tap to verify your age")
    } catch (e) {
      console.error("face-api load error:", e)
      this.showStatus("AI model unavailable on this device.")
      if (this.hasErrorTarget) this.errorTarget.classList.remove("hidden")
    } finally {
      this.loading = false
    }
  }

  async waitForFaceAPI() {
    while (typeof faceapi === "undefined") {
      await new Promise(resolve => setTimeout(resolve, 200))
    }
  }

  // ---- Camera ----

  async startCamera() {
    if (!this.modelsLoaded) {
      this.showStatus("Model still loading, please wait...")
      return
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: 640, height: 480 }
      })
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()
      this.showStatus("Look at the camera and tap 'Verify age'")
    } catch (e) {
      this.showStatus("Camera access denied.")
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(t => t.stop())
      this.stream = null
    }
  }

  // ---- AI verification ----

  async verify() {
    if (!this.stream) {
      await this.startCamera()
      return
    }

    this.showStatus("Analyzing...")

    const detection = await faceapi
      .detectSingleFace(this.videoTarget, new faceapi.TinyFaceDetectorOptions())
      .withAgeAndGender()

    if (!detection) {
      this.showStatus("No face detected. Make sure your face is visible and well-lit.")
      return
    }

    const estimatedAge = Math.round(detection.age)
    const isAdult = estimatedAge >= 18

    this.stopCamera()

    if (isAdult) {
      await this.submitVerification({ method: "ai", estimated_age: estimatedAge })
    } else {
      this.verifiedValue = false
      this.showStatus(`Estimated age: ${estimatedAge} — you must be 18 or older to use GagStack.`)
      if (this.hasActionsTarget) this.actionsTarget.classList.add("hidden")
      if (this.hasResultTarget) this.resultTarget.classList.remove("hidden")
    }
  }

  // ---- Manual verification ----

  showManual() {
    if (this.hasAiSectionTarget) this.aiSectionTarget.classList.add("hidden")
    if (this.hasManualSectionTarget) this.manualSectionTarget.classList.remove("hidden")
  }

  showAI() {
    if (this.hasManualSectionTarget) this.manualSectionTarget.classList.add("hidden")
    if (this.hasAiSectionTarget) this.aiSectionTarget.classList.remove("hidden")
  }

  async verifyManual() {
    const day = parseInt(this.dayTarget.value)
    const month = parseInt(this.monthTarget.value)
    const year = parseInt(this.yearTarget.value)

    const dob = new Date(year, month - 1, day)
    const today = new Date()
    let age = today.getFullYear() - dob.getFullYear()
    const monthDiff = today.getMonth() - dob.getMonth()
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dob.getDate())) {
      age--
    }

    if (age < 18) {
      this.showStatus("You must be 18 or older to use GagStack.")
      return
    }

    await this.submitVerification({ method: "manual", dob: `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}` })
  }

  // ---- Shared ----

  async submitVerification(payload) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    await fetch("/age_verification", {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrf,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    })

    this.verifiedValue = true
    this.showStatus("Age verified!")
    if (this.hasActionsTarget) this.actionsTarget.classList.add("hidden")
    if (this.hasRetryTarget) this.retryTarget.classList.remove("hidden")
    this.dispatch("verified")
  }

  showStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.classList.remove("hidden")
    }
  }
}
