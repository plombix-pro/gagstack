import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]
  static values = { active: String }

  show(event) {
    this.activeValue = event.currentTarget.dataset.tab
  }

  activeValueChanged() {
    this.panelTargets.forEach(p => {
      p.classList.toggle("hidden", p.dataset.tab !== this.activeValue)
    })
  }
}
