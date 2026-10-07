# Security Policy

At **rhythm's hyprland**, we take the security, privacy, and integrity of your desktop environment very seriously.

Because this project configures desktop compositors, session lockers (`hyprlock`), display managers (`sddm`), Polkit authentication agents, and systemd services with privileged hardware access (such as battery thresholds and backlight controls), responsible security practices are essential to protecting your system.

---

## 🛡️ Supported Versions

We actively maintain and provide security updates for the latest code on the default branch:

| Branch / Version | Supported | Notes |
|:---|:---:|:---|
| `main` | ✅ Yes | Actively maintained with the latest fixes and security patches |
| Older releases / forks | ❌ No | Please update to current `main` via `system-ota update` |

---

## 🔍 Areas of Special Security Focus

When reviewing or modifying this setup, we pay special attention to:

1. **Privilege Escalation & Sudoers:** Ensuring any scripts that require root permissions do so strictly through explicit `sudo` invocations with proper input sanitization, avoiding arbitrary command injection.
2. **Session Locking Integrity:** Ensuring that `hyprlock`, sleep hooks, and lid-switch triggers lock the screen securely before suspension without race conditions or display leaks.
3. **Sensitive User Data & Dotfiles:** Preventing secrets, authentication tokens, API keys, and private credentials from ever being written into publicly tracked configuration files or exposed in temporary log files.
4. **Binary & Asset Downloads:** Ensuring external repositories, themes, and dependencies are fetched securely over HTTPS from verified official sources.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or potential risk in this project, **please do not disclose it publicly in an open GitHub issue or public forum**.

### How to Contact Us Privately

1. **GitHub Security Advisories (Recommended):**  
   Navigate to the repository's **Security** tab and click **"Report a vulnerability"**.
   
2. **Direct Email:**  
   If you prefer email, reach out directly to:  
   📧 `rhythmcreative@users.noreply.github.com`

Please include in your report:
- A brief description of the vulnerability and its potential impact.
- Step-by-step instructions or proof-of-concept to reproduce the behavior.
- Any suggested mitigations or patches, if you have one ready.

---

## 🤝 What You Can Expect From Us

- **Prompt acknowledgment:** We will reply within 48 hours to confirm receipt of your report.
- **Human communication:** You will talk directly with the project maintainer. No automated brush-offs or bureaucratic walls.
- **Collaborative patching:** We will work together with you to verify the issue and test a fix.
- **Credit & gratitude:** Once a fix is deployed, we will happily credit you in the release notes and commit history (unless you prefer to remain anonymous).

---

Thank you for helping keep the **rhythm's hyprland** community secure and reliable! 🔒
