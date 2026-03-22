# Dëgjo — Mëso Anglisht

An iOS audio learning app built for people with visual impairments. 285 English lessons, controlled entirely through gestures — no screen required.

🌐 **[ledian63s.github.io/degjo](https://ledian63s.github.io/degjo)**

---

## Features

- **285 audio lessons** — beginner to intermediate English, streamed on demand
- **Gesture-only control** — the entire app is operated with 6 touch gestures
- **Audio confirmation** — every action is announced in Albanian
- **Resume playback** — picks up exactly where you left off
- **Theme control** — follows system appearance or set manually (light / dark / system)
- **Onboarding tutorial** — interactive walkthrough of all gestures on first launch

## Gestures

| Gesture | Action |
|---|---|
| 1 finger · tap | Play / Pause |
| 1 finger · double-tap | Repeat from beginning |
| 2 fingers · swipe up | +30 seconds |
| 2 fingers · swipe down | −30 seconds |
| 2 fingers · swipe left/right | Previous / Next lesson |
| 3 fingers · tap | Jump to lesson (voice input) |

## Tech Stack

- Flutter (iOS)
- [just_audio](https://pub.dev/packages/just_audio) + [just_audio_background](https://pub.dev/packages/just_audio_background) — audio playback with lock-screen controls
- [youtube_explode_dart](https://pub.dev/packages/youtube_explode_dart) — audio extraction
- [flutter_tts](https://pub.dev/packages/flutter_tts) — Albanian voice feedback
- [provider](https://pub.dev/packages/provider) — state management
- [shared_preferences](https://pub.dev/packages/shared_preferences) — local persistence
- Cloudflare R2 — audio hosting

## Story

This app was built by a son for his father. Because learning should have no limits — not age, not sight.

---

*Dëgjo. Mëso. Kupto.*
