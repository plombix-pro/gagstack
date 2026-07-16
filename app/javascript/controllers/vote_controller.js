import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["upvotes", "downvotes"]
  static values = { postId: Number }

  up(event) {
    this.submit("up", event.currentTarget)
  }

  down(event) {
    this.submit("down", event.currentTarget)
  }

  async submit(direction, button) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(`/posts/${this.postIdValue}/vote`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrf,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ direction: direction })
      })
      if (response.ok) {
        const data = await response.json()
        if (this.hasUpvotesTarget) this.upvotesTarget.textContent = data.upvotes_count
        if (this.hasDownvotesTarget) this.downvotesTarget.textContent = data.downvotes_count
        this.applyActiveClass(data.user_vote)
      }
    } catch (error) {
      console.error("Vote failed:", error)
    }
  }

  applyActiveClass(userVote) {
    const buttons = this.element.querySelectorAll("button")
    buttons.forEach(b => {
      const action = b.getAttribute("data-action")
      if (action === "vote#up") {
        b.classList.toggle("text-amber-500", userVote === true)
        b.classList.remove("text-gray-500", "text-gray-400")
        if (userVote !== true) b.classList.add("text-gray-400")
      }
      if (action === "vote#down") {
        b.classList.toggle("text-red-500", userVote === false)
        b.classList.remove("text-gray-500", "text-gray-400")
        if (userVote !== false) b.classList.add("text-gray-400")
      }
    })
  }
}
