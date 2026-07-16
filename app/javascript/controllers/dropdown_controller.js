import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundClose = this.close.bind(this)
    document.addEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  close(e) {
    if (!this.element.contains(e.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
