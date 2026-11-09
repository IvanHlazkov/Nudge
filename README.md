<p align="center"><img src="docs/logo.png" alt="Nudge" width="420"></p>

<p align="center"><b>All your reminders in one place, right on your Mac desktop.</b></p>

<p align="center">
  <a href="https://github.com/IvanHlazkov/Nudge/releases/latest"><b>⬇️ Download Nudge for Mac</b></a>
</p>

---

Nudge is a small glass panel that pops up with ⌥Space. Type a reminder, press Enter, done.

- **Type naturally:** "Upload homework tomorrow at 10 pm", "gym at 18:30" or "call back in 20 minutes". The date lights up as you type.
- **General and Planned:** reminders without a time go to General (one simple list), ones with a time go to Planned (day by day).
- **Edit anything:** double-click a reminder (or use the pencil) to change its text, date and time.
- **Notifications** with Snooze and Mark done buttons, plus a 9:00 morning summary.
- **⌥Space** opens and closes Nudge from any app. Click anywhere outside it and it gets out of the way.
- **Menu bar bell** shows what's next up.
- **Send to Apple Reminders** (optional, one way) so your reminders show up on your iPhone too.
- **Opens at login** automatically.

Requires macOS 14 Sonoma or later.

## Install

1. Download **Nudge-mac.zip** from the [latest release](https://github.com/IvanHlazkov/Nudge/releases/latest) and unzip it.
2. Drag **Nudge.app** into your **Applications** folder.
3. Open it. The first time, macOS says *"Nudge" Not Opened* because Nudge isn't notarized by Apple yet. This is expected. **Don't click Move to Trash.** Click **Done**, then:
   1. Open **System Settings › Privacy & Security** (**Ajustes del Sistema › Privacidad y seguridad**).
   2. Scroll down to **Security**. You'll see *"Nudge" was blocked to protect your Mac*. Click **Open Anyway** (**Abrir igualmente**).
   3. Enter your password and click **Open Anyway** again.

   You only need to do this once.

   **Quicker option:** open Terminal, paste this and press Enter, then open Nudge normally:
   ```
   xattr -dr com.apple.quarantine /Applications/Nudge.app
   ```

## Uninstall

1. Click the **power button** in Nudge (or **Quit Nudge** in the menu bar bell or in Settings).
2. Drag **Nudge.app** from **Applications** to the **Trash**.

## Build it yourself

1. Open `Nudge.xcodeproj` in Xcode 16 or newer.
2. Click the Nudge target › **Signing & Capabilities** and pick your Team (a free Apple ID works).
3. Press **⌘R**.

## Support Nudge

Nudge is free. If you like it, you can support its development with the **Sponsor** button at the top of this page.

---

Made by Glaz Labs.
