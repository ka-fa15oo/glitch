# Glitch – Reddit paketi

Görseller (hepsi bu klasörde):
- `glitch-demo.gif` – yürüme, nefes, bakış, mutlu, el sallama, kılıç kaldırma/vurma, glitch, üzgün (21 kare)
- `glitch-sheet.png` – 8 poz tek görselde (r/PixelArt ve eleştiri postları için)
- `glitch-still.png` – tek poz (thumbnail)

> Dikkat: Reddit'e erişemedim, kuralları canlı doğrulayamadım. Atmadan önce her subreddit'in **Rules** sekmesini oku.
> Uygulama henüz herkese açık dağıtılmıyor (repo/web sitesi/App Store yok); bu yüzden "app tanıtımı" değil **geri bildirim** postu olarak yazdım.
> Karakter artık robot değil, "karanlık gotik şövalye" — postlarda öyle anlatılıyor.

Atma sırası önerisi (günler arayla): 1) r/PixelArt → 2) r/SwiftUI → 3) r/IndieDev → 4) r/macapps (kuralları kontrol et, muhtemelen megathread).

---

## 1) r/PixelArt — görsel eleştiri (glitch-sheet.png)

**Başlık:** Feedback wanted: dark gothic knight desktop pet, 64x96 sprite – is the silhouette readable?

**Metin:**
> I'm making a small desktop pet for macOS: a faceless dark knight with glowing red eyes, tattered crimson cape, pale-gold accents on near-black iron. Sprite is 64x96, drawn as separate parts (head, eyes, torso, cloak, arms, legs) so I can animate them independently.
>
> Things I'm unsure about:
> 1. Does the silhouette read clearly at small size?
> 2. Palette: is the crimson + gold + blue-grey iron too busy?
> 3. The sword feels long next to the body – too much?
>
> Honest critique welcome, thanks!

---

## 2) r/SwiftUI — teknik (glitch-demo.gif)

**Başlık:** Pixel-art desktop pet in pure SwiftUI (transparent borderless window, per-part sprite animation) – how would you structure the animation state?

**Metin:**
> Built a macOS desktop pet in SwiftUI + Swift Concurrency. Borderless transparent floating window, sprites drawn as separate PNG parts, driven by a `Brain` that outputs a `Pose` struct each tick (eyes, head tilt, hand positions, sword rotation, step phase).
>
> Questions:
> - Is a single `Pose` struct + timer the right approach, or should I move to `TimelineView`/`Canvas`?
> - Best way to keep CPU near zero while idle?
> - Reliable way to hide the window when another app goes fullscreen (I'm polling right now)?
>
> Happy to share code snippets. [GIF]

---

## 3) r/IndieDev — davranış fikirleri (glitch-demo.gif)

**Başlık:** Designing a desktop pet that's alive but never annoying – what idle behaviors would you add?

**Metin:**
> My pet is a serious, silent knight – no cutesy stuff. Current behaviors: breathing, blinking, eyes drifting, head tilts when the cursor gets close, draggable (reacts angry/surprised/happy), draws a sword after ~2 min idle, waves when the Mac wakes and looks sad when it sleeps.
>
> What would make something like this feel like a real companion without becoming distracting? Reactions to typing? Time of day? Battery low? Anything you'd actually want, or hate, on your desktop?

---

## 4) r/macapps — SADECE kurallar izin verirse

Kural özeti (mirror sitelerden, doğrulanmadı): doğrudan app tanıtımı için güven şartları var; olmayanlar aylık "App Pile" megathread'ine yazıyor, şablon **Problem / Comparison / Pricing**. Uygulama henüz dağıtılmadığı için şimdilik **atma**, önce 1-3'ten gelen geri bildirimle geliştir; dağıtıma açınca megathread şablonu:

> **Problem:** Desktop pets are either too cute or too distracting; I wanted a calm, dark, atmospheric companion.
> **Comparison:** vs. Shimeji / Bongo Cat-style pets – hand-drawn pixel knight, reacts to cursor, sleep/wake, fullscreen-aware.
> **Pricing:** Free. [link]

---

## Yorumlara hazır cevaplar

- "Where can I download it?" → "Not public yet, still polishing. Will post when it's ready."
- "Is it open source?" → (karar senin)
- "Does it use much CPU?" → "Idle is near zero, I'm profiling it now."
