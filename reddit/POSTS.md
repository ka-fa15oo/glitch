# Glitch – Reddit paketi (nöbetçi odaklı)

**Durum: hiçbir şey paylaşılmadı. Repo özel, uygulama henüz herkese açık değil.** Tüm postlar taslak; atmadan önce kullanıcının onayı ve her subreddit'in canlı kuralları şart (Reddit'e erişemedim, kurallar doğrulanmadı).

## Görseller
- Şimdilik kullanılabilir duran görüntüler: `../docs/images/` (idle, permission, question, finished-error-sparks, customize).
- **Eski:** `glitch-demo.gif`, `glitch-sheet.png`, `glitch-still.png` eski görünümden, postlarda KULLANMA.
- **Gerekli:** gerçek ekran kaydı (kullanıcı çekecek, QuickTime ya da Cmd+Shift+5): 2-3 Claude oturumu açık, biri izin isterken Glitch nöbete geçer (kızıl kıvılcım), iş bitince altın kıvılcım. 10-20 sn yeterli. Kayıt gelince GIF'e çevirip kısaltacağım (ffmpeg kurulu değil, kurulum kullanıcıdan onay ister).

## Tek cümle
"Glitch is a pixel ghost-knight that lives on your Mac desktop and keeps watch over all your Claude Code sessions: he tells you who is waiting for you with his sword instead of a popup."

Atılacak yer sırası (günler arayla): 1) r/PixelArt, 2) r/ClaudeAI, 3) r/macapps (yalnızca kurallar izin verirse).

---

## 1) r/PixelArt – görsel eleştiri

**Görsel:** `idle.png` + `permission.png` + `question.png` (3'lü), veya yeni GIF.

**Başlık:** Feedback wanted: pixel ghost-knight sentinel, does the silhouette and the "state poses" read clearly?

**Metin:**
> I'm making a small desktop companion for macOS: a faceless dark knight with glowing red eyes, tattered crimson cloth and pale-gold accents on near-black iron. He has a few "state poses": standing guard, sword held upright, turning toward you, flicking the sword when done.
>
> What I'd love critique on:
> 1. Does the silhouette read at small desktop size?
> 2. Is crimson + gold + blue-grey iron too busy?
> 3. Do the poses communicate their meaning without any text?
>
> Honest feedback welcome.

---

## 2) r/ClaudeAI – ürün + geri bildirim

**Görsel:** yeni ekran kaydı GIF'i (permission → nöbet, finished → altın kıvılcım). Hazır değilse **atma**.

**Başlık:** I made a pixel knight that keeps watch over all my Claude Code sessions (permission waits, questions, finished turns)

**Metin:**
> When I run 2-3 Claude Code sessions at once I keep missing the one that's waiting for me. So I built Glitch, a small native macOS desktop pet that watches every Claude Code session (desktop app and terminal, any project):
>
> - session needs **permission** → he keeps vigil, sword upright, crimson spark
> - session **asked a question** → he turns to look at you, crimson spark
> - session **finished** → he flicks his sword, gold spark
> - session **crashed** → the sword slips and he catches it
>
> Hover shows the session list, click opens the most urgent one.
>
> How it works: a tiny hook script in `~/.claude/settings.json` (PermissionRequest, Stop, StopFailure) drops event files into a local folder; Glitch reads them. No network, no account, installs only after showing what it adds, existing hooks kept, backup written, "Remove" takes out only his entries.
>
> It's not public yet. I'd like opinions first:
> - Is a calm "sentinel" better than notifications for you, or would you want sounds/notifications too?
> - What other Claude Code events would you want him to react to?
> - Would you trust a hook like this? What would you want to inspect first?
>

---

## 3) r/macapps – SADECE kurallar izin verirse

Kural özeti (mirror sitelerden, doğrulanmadı): doğrudan app tanıtımı güven şartlarına bağlı, olmayanlar aylık "App Pile" megathread'ine yazıyor; şablon **Problem / Comparison / Pricing**. Repo özel ve uygulama dağıtılmıyor, bu yüzden şimdilik **atma**. Yayına açılınca megathread taslağı:

> **Problem:** With several Claude Code sessions open I keep missing the one waiting for permission or an answer, and popups/notifications are noisy.
> **Comparison:** Instead of notification banners or menu-bar badges, a calm pixel knight on the desktop shows state with poses and sparks (crimson = waiting for you, gold = done). Nothing leaves your Mac.
> **Pricing:** Free. [link, repo public olunca]

---

## Yorumlara hazır cevaplar
- "Where can I download it?" → "Not public yet, polishing the first release. Will post when it's out."
- "Does it send data anywhere?" → "No network, no account. The hook only writes small event files into ~/Library/Application Support/Glitch/events/."
- "Will it slow Claude Code down?" → "The hook script exits immediately, even when Glitch isn't running."
- "Windows/Linux?" → "macOS 15+ only, native SwiftUI."

## Açık noktalar (karar kullanıcıda)
- Repo ne zaman public olacak? (postların çoğu buna bağlı)
- Yeni ekran kaydı gelene kadar hiçbir şey atılmayacak.
