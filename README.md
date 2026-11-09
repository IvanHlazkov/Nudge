<p align="center"><img src="docs/logo.png" alt="Nudge" width="420"></p>

<p align="center"><b>All your reminders in one place, right on your Mac desktop.</b></p>

<p align="center">
  <a href="https://github.com/IvanHlazkov/Nudge/releases/latest"><b>⬇️ Download Nudge for Mac</b></a>
</p>

---

Nudge is a small glass panel that pops up with ⌥Space. Type a reminder, press Enter, done.

- **Type naturally:** "Upload homework tomorrow at 10 pm", "gym at 18:30" or "call back in 20 minutes". The date lights up as you type.
- **Repeating reminders:** "water the plants every day at 8", "team call every monday at 10", "pay rent monthly". Tick one off and the next one appears.
- **Two-way sync with Apple Reminders** (optional): your reminders show up on your iPhone, Apple Watch and Siri, and anything you change or tick off there comes back to Nudge.
- **Quick notes:** press Tab in the box to jot down a note instead of a reminder. Notes sit next to General, and you can pin, copy, edit them or turn one into a reminder.
- **General and Planned:** reminders without a time go to General (one simple list), ones with a time go to Planned (day by day).
- **Edit anything:** double-click a reminder (or use the pencil) to change its text, date, time and repeat.
- **Notifications** with Mark done and Snooze (10 min, 1 hour or tomorrow) buttons, plus a 9:00 morning summary.
- **⌥Space** opens and closes Nudge from any app. Click anywhere outside it and it gets out of the way.
- **Menu bar** shows today's next reminder, right next to the bell.
- **Tells you about updates** so you never miss a new version.
- **Opens at login** automatically.

Requires macOS 14 Sonoma or later.

## Install

1. Download **Nudge-mac.zip** from the [latest release](https://github.com/IvanHlazkov/Nudge/releases/latest) and unzip it.
2. Drag **Nudge.app** into your **Applications** folder.
3. Open it. The first time, macOS says *"Nudge" Not Opened* because Nudge isn't notarized by Apple yet. This is expected. **Don't click Move to Trash.** Click **Done**, then:
   1. Open **System Settings › Privacy & Security**.
   2. Scroll down to **Security**. You'll see *"Nudge" was blocked to protect your Mac*. Click **Open Anyway**.
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

## Contributing

Bug reports and ideas are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). Found a security problem? See [SECURITY.md](SECURITY.md).

## License

© 2026 Ivan Hlazkov (Glaz Labs). All rights reserved. Nudge is free to download and use, but the code isn't open source. See [LICENSE](LICENSE).

---

Made by Glaz Labs.
