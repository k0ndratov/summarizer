import { Controller } from "@hotwired/stimulus"

// Toggles data-theme on <html> and persists the choice. Without a stored
// choice the CSS follows prefers-color-scheme; the head script in the layout
// applies the stored choice before first paint.
export default class extends Controller {
  static targets = ["label"]

  connect() { this.render() }

  toggle() {
    const next = this.current() === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = next
    localStorage.setItem("theme", next)
    this.render()
  }

  current() {
    return document.documentElement.dataset.theme ||
      (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
  }

  render() {
    this.labelTarget.textContent = this.current() === "dark" ? "☀ Light" : "☾ Dark"
  }
}
