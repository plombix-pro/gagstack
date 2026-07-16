import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["upvote", "downvote", "upvotes", "downvotes"]
  static values = { postId: Number, commentId: Number }

  up() {
    this.submit("up", true)
  }

  down() {
    this.submit("down", false)
  }

  submit(direction, isUp) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const button = isUp ? this.upvoteTarget : this.downvoteTarget
    const otherButton = isUp ? this.downvoteTarget : this.upvoteTarget
    const countTarget = isUp ? this.upvotesTarget : this.downvotesTarget
    const otherCountTarget = isUp ? this.downvotesTarget : this.upvotesTarget

    button.classList.remove("text-gray-500", "hover:text-amber-400", "hover:text-red-400")
    otherButton.classList.remove("text-amber-500", "text-red-500")
    otherButton.classList.add("text-gray-500", isUp ? "hover:text-red-400" : "hover:text-amber-400")

    const isActive = button.classList.contains("text-amber-500") || button.classList.contains("text-red-500")
    const otherIsActive = otherButton.classList.contains("text-amber-500") || otherButton.classList.contains("text-red-500")

    let currentCount = parseInt(countTarget.textContent) || 0
    let otherCount = parseInt(otherCountTarget.textContent) || 0

    if (isActive) {
      button.classList.remove("text-amber-500", "text-red-500")
      button.classList.add("text-gray-500", isUp ? "hover:text-amber-400" : "hover:text-red-400")
      countTarget.textContent = Math.max(0, currentCount - 1)
      if (otherIsActive) {
        otherButton.classList.remove("text-red-500", "text-amber-500")
        otherButton.classList.add("text-gray-500", isUp ? "hover:text-red-400" : "hover:text-amber-400")
        otherCountTarget.textContent = Math.max(0, otherCount - 1)
      }
    } else {
      button.classList.add(isUp ? "text-amber-500" : "text-red-500")
      countTarget.textContent = currentCount + 1
      if (otherIsActive) {
        otherButton.classList.remove("text-red-500", "text-amber-500")
        otherButton.classList.add("text-gray-500", isUp ? "hover:text-red-400" : "hover:text-amber-400")
        otherCountTarget.textContent = Math.max(0, otherCount - 1)
      }
    }

    fetch(`/posts/${this.postIdValue}/comments/${this.commentIdValue}/vote`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrf,
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ direction: direction })
    })
  }
}
