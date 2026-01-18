// Atlas Field Tracker Hook
// Tracks field focus and user idle time for proactive Atlas help

export const AtlasFieldTracker = {
  mounted() {
    this.trackFields()
  },

  updated() {
    // Re-track fields when DOM updates (e.g., step changes)
    this.trackFields()
  },

  trackFields() {
    const form = this.el.querySelector('form')
    if (!form) return

    // Track field focus
    form.querySelectorAll('input, textarea, select').forEach(field => {
      // Remove existing listeners to prevent duplicates
      field.removeEventListener('focus', this.handleFocus)
      field.removeEventListener('blur', this.handleBlur)

      // Create bound handlers
      field._atlasFocusHandler = (e) => {
        this.pushEvent('field_focus', { field: e.target.name })
      }
      field._atlasBlurHandler = (e) => {
        this.pushEvent('field_blur', { field: e.target.name })
      }

      field.addEventListener('focus', field._atlasFocusHandler)
      field.addEventListener('blur', field._atlasBlurHandler)
    })

    // Track idle time
    if (this.idleTimer) {
      clearTimeout(this.idleTimer)
    }

    const resetIdle = () => {
      if (this.idleTimer) {
        clearTimeout(this.idleTimer)
      }
      this.idleTimer = setTimeout(() => {
        this.pushEvent('user_idle', { seconds: 30 })
      }, 30000)
    }

    form.addEventListener('input', resetIdle)
    form.addEventListener('mousemove', resetIdle)
    form.addEventListener('keydown', resetIdle)
    resetIdle()
  },

  destroyed() {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer)
    }
  }
}

// ScrollToBottom Hook for chat windows
export const ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
