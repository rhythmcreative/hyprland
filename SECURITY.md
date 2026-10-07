# Security Policy

This repository configures desktop environments, display managers (`sddm`), screen lockers (`hyprlock`), and helper services that execute privileged commands via `sudo` (such as hardware threshold controls and package management). Because of this, security and sensible permission handling are important.

---

## Supported versions

Security updates and fixes are applied directly to the default branch:

| Branch | Status |
|:---|:---|
| `main` | Actively supported |
| Older forks or local branches | Please update to current `main` using `system-ota update` |

---

## What we pay attention to

- **Privilege escalation:** Any script that requests `sudo` privileges must restrict itself strictly to necessary operations, validate input, and avoid arbitrary command execution.
- **Lockscreen integrity:** Ensuring that `hyprlock` and associated systemd sleep hooks lock the session reliably before system suspend without race conditions or desktop exposure.
- **User secrets and credentials:** Keeping authentication tokens, sensitive environment variables, and personal keys completely out of committed configurations and install logs.

---

## Reporting a security issue

If you discover a security vulnerability or potential exploit, please do not file a public issue or discuss it in public chat rooms.

Instead, report it privately using either of these channels:
1. **GitHub Security Advisory:** Go to the repository's **Security** tab and click **Report a vulnerability**.
2. **Direct email:** Send the details directly to `rhythmcreative@users.noreply.github.com`.

Please include:
- A brief explanation of the problem and where it occurs.
- Steps or a minimal test case showing how to reproduce it.
- Suggested mitigations or patches, if you have one.

I'll review your report, acknowledge receipt, and coordinate a fix before any public update is pushed.
