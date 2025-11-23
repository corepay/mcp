/**
 * Authentication Hook for LiveView Login
 *
 * This hook handles login success events and manages session cookies
 * for the JWT-based authentication system.
 */

const AuthHook = {
  mounted() {
    this.handleEvent("login-success", (data) => {
      this.handleLoginSuccess(data);
    });

    this.handleEvent("oauth-redirect", (data) => {
      this.handleOAuthRedirect(data);
    });

    // Handle auto-remove announcements
    window.addEventListener("auto-remove-announcement", (event) => {
      const { index } = event.detail;
      setTimeout(() => {
        const element = document.getElementById(`announcement-${index}`);
        if (element) {
          element.remove();
        }
      }, 3000);
    });
  },

  handleLoginSuccess(data) {
    const { session_data, redirect_to } = data;

    // Set session cookies
    this.setSessionCookies(session_data);

    // Show success message
    this.showNotification("Welcome back! Redirecting...", "success");

    // Redirect after a short delay to allow cookies to be set
    setTimeout(() => {
      window.location.href = redirect_to || "/dashboard";
    }, 500);
  },

  setSessionCookies(sessionData) {
    const {
      access_token,
      refresh_token,
      encrypted_access_token,
      encrypted_refresh_token,
      session_id,
      expires_at
    } = sessionData;

    // Set access token cookie (shorter lifetime)
    if (access_token) {
      document.cookie = this.formatCookie(
        "_mcp_access_token",
        encrypted_access_token || access_token,
        {
          expires: new Date(expires_at || Date.now() + 24 * 60 * 60 * 1000), // 24 hours
          secure: true,
          sameSite: 'Strict',
          httpOnly: false // Allow JavaScript access for LiveView
        }
      );
    }

    // Set refresh token cookie (longer lifetime)
    if (refresh_token) {
      document.cookie = this.formatCookie(
        "_mcp_refresh_token",
        encrypted_refresh_token || refresh_token,
        {
          expires: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
          secure: true,
          sameSite: 'Strict',
          httpOnly: false
        }
      );
    }

    // Set session ID cookie
    if (session_id) {
      document.cookie = this.formatCookie(
        "_mcp_session_id",
        session_id,
        {
          expires: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
          secure: true,
          sameSite: 'Strict',
          httpOnly: false
        }
      );
    }
  },

  formatCookie(name, value, options = {}) {
    let cookieString = `${name}=${encodeURIComponent(value)}`;

    if (options.expires) {
      cookieString += `; expires=${options.expires.toUTCString()}`;
    }

    if (options.path) {
      cookieString += `; path=${options.path}`;
    }

    if (options.domain) {
      cookieString += `; domain=${options.domain}`;
    }

    if (options.secure) {
      cookieString += '; secure';
    }

    if (options.sameSite) {
      cookieString += `; samesite=${options.sameSite}`;
    }

    if (options.httpOnly) {
      cookieString += '; httponly';
    }

    return cookieString;
  },

  handleOAuthRedirect(data) {
    const { url, provider } = data;

    // Show loading notification
    this.showNotification(`Connecting to ${provider}...`, 'info');

    // Redirect to OAuth provider
    setTimeout(() => {
      window.location.href = url;
    }, 500);
  },

  showNotification(message, type = 'info') {
    // Create a simple notification or integrate with your notification system
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 z-50 alert alert-${type} shadow-lg`;
    notification.innerHTML = `
      <div class="flex items-center">
        <span>${message}</span>
      </div>
    `;

    document.body.appendChild(notification);

    // Auto-remove after 3 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification);
      }
    }, 3000);
  }
};

export default AuthHook;