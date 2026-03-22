# Cloudflare R2 Audio Migration

Move lesson audio off YouTube scraping onto self-hosted Cloudflare R2.
This makes the app reliable, fast, and independent of YouTube API changes.

---

## Why

- `youtube_explode_dart` is unofficial and can break anytime YouTube updates
- Signed stream URLs expire after ~6 hours
- YouTube can rate-limit or block the app
- No internet = no audio with current setup

---

## Steps

### 1. Create Cloudflare Account
- Go to [cloudflare.com](https://cloudflare.com) → Sign up (free)
- Navigate to **R2 Object Storage** → **Create bucket**
- Name it `degjo-audio`
- Enable **Public Access** on the bucket
- Note your public URL: `https://pub-xxxx.r2.dev/`

---

### 2. Download Audio from YouTube (run once on Mac)

Install `yt-dlp`:
```bash
brew install yt-dlp
```

Download all lessons as MP3 (audio only):
```bash
yt-dlp \
  --extract-audio \
  --audio-format mp3 \
  --audio-quality 5 \
  --output "%(playlist_index)s.%(ext)s" \
  "https://www.youtube.com/playlist?list=PLWN-brI7dUEl5tRRglCks_2LZLCdvOWTZ"
```

This creates `1.mp3`, `2.mp3`, ..., `N.mp3` in the current folder.

---

### 3. Upload to R2

Install Cloudflare CLI:
```bash
npm install -g wrangler
wrangler login
```

Upload all files:
```bash
for f in *.mp3; do
  wrangler r2 object put degjo-audio/$f --file $f
done
```

Or use the **Cloudflare Dashboard** → R2 → degjo-audio → Upload (drag and drop).

---

### 4. Create Playlist JSON

Create a file called `playlist.json` and upload it to R2:

```json
[
  {
    "index": 1,
    "title": "Lesson title here",
    "url": "https://pub-xxxx.r2.dev/1.mp3"
  },
  {
    "index": 2,
    "title": "Lesson title here",
    "url": "https://pub-xxxx.r2.dev/2.mp3"
  }
]
```

Upload it:
```bash
wrangler r2 object put degjo-audio/playlist.json --file playlist.json
```

The app fetches this file on startup instead of scraping YouTube.
To add/remove lessons: just update `playlist.json` — no app update needed.

---

### 5. Update the App

- Remove `youtube_explode_dart` dependency from `pubspec.yaml`
- Replace `YouTubeService` with a simple HTTP fetch of `playlist.json`
- Stream MP3 URLs directly with `just_audio` (works natively, no workarounds)
- Remove the complex stream info fetching and URL signing logic

**Claude can do this step** — just say "implement the R2 migration" when ready.

---

## Cost Estimate

| Resource | Free Tier | Expected Usage |
|----------|-----------|----------------|
| Storage | 10 GB free | ~1 GB (200 × 5MB) |
| Requests | 10M/month free | Well within limits |
| Egress | Free (no egress fees) | — |

**Total cost: $0/month**

---

## Also Needed

- [ ] Record Albanian number audio files (`mesimi.mp3`, `1.mp3` … `200.mp3`)
      → Store in `assets/audio/` inside the app (not R2 — they are tiny)
- [ ] Design and add a proper app icon
- [ ] Test with real blind users
- [ ] Submit to App Store

---

## Notes

- Keep `youtube_explode_dart` in the code until R2 is fully set up and tested
- The playlist URL currently in use: `PLWN-brI7dUEl5tRRglCks_2LZLCdvOWTZ`
- Public R2 URL format: `https://pub-xxxx.r2.dev/filename.mp3`
  (replace `xxxx` with your actual bucket ID from Cloudflare dashboard)
