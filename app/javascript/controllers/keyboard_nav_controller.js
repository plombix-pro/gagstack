import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    prev: String,
    next: String
  }

  connect() {
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleKeydown)
  }

  _handleKeydown = (event) => {
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA" || event.target.isContentEditable) {
      return
    }

    if (event.key === "ArrowLeft" && this.prevValue) {
      Turbo.visit(this.prevValue)
    } else if (event.key === "ArrowRight" && this.nextValue) {
      Turbo.visit(this.nextValue)
    }
  }
}
