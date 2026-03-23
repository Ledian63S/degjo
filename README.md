<div align="center">
  <img src="docs/app_logo.png" width="64" alt="Dëgjo logo" />
  <h1>Dëgjo — Mëso Anglisht</h1>
  <p>An iOS audio learning app built for people with visual impairments.<br>285 English lessons, controlled entirely through gestures — no screen required.</p>
  <a href="https://ledian63s.github.io/degjo"><strong>🌐 ledian63s.github.io/degjo</strong></a>
  <br /><br />
  <img src="https://img.shields.io/badge/Platform-iOS-black?style=flat-square&logo=apple" alt="iOS" />
  <img src="https://img.shields.io/badge/Flutter-3.x-54C5F8?style=flat-square&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Language-Albanian-E8191C?style=flat-square" alt="Albanian" />
</div>

---

## ✨ Features

| | |
|---|---|
| 🎧 **285 audio lessons** | Beginner to intermediate English, streamed on demand |
| 👆 **Gesture-only control** | The entire app is operated with 6 touch gestures |
| 🔊 **Audio confirmation** | Every action is announced in Albanian |
| ⏪ **Resume playback** | Picks up exactly where you left off |
| 🌙 **Theme control** | Follows system appearance or set manually (light / dark / system) |
| 📖 **Onboarding tutorial** | Interactive walkthrough of all gestures on first launch |

## 🤌 Gestures

| Gesture | Action |
|---|---|
| 1 finger · tap | ▶ Play / Pause |
| 1 finger · double-tap | 🔄 Repeat from beginning |
| 2 fingers · swipe up | ⏩ +30 seconds |
| 2 fingers · swipe down | ⏪ −30 seconds |
| 2 fingers · swipe left/right | ⏮ ⏭ Previous / Next lesson |
| 3 fingers · tap | 🎯 Jump to lesson (voice input) |

## 🛠 Tech Stack

- **Flutter** (iOS)
- [just_audio](https://pub.dev/packages/just_audio) + [just_audio_background](https://pub.dev/packages/just_audio_background) — audio playback with lock-screen controls
- [flutter_tts](https://pub.dev/packages/flutter_tts) — Albanian voice feedback
- [provider](https://pub.dev/packages/provider) — state management
- [shared_preferences](https://pub.dev/packages/shared_preferences) — local persistence
- **Cloudflare R2** — audio hosting

## ❤️ Story

This app was built by a son for his father. Because learning should have no limits — not age, not sight.

---

<div align="center"><em>Dëgjo. Mëso. Kupto.</em></div>
