# Glitch: Claude Code Nöbetçisi (tasarım)

Tarih: 2026-10-17 · Durum: kullanıcı "deneyelim ve görelim" dedi; kurucu kararları aşağıda işaretli

## Amaç ve neden

Kullanıcı aynı anda birden fazla Claude Code oturumu çalıştırıyor (PET'te beş oturum, ayrıca Obsidian ve SpeakUp projeleri). Hangi oturumun kendisini beklediğini kaçırıyor. Glitch, Mac'teki tüm Claude Code oturumlarını izleyecek ve bunu **karakterin kendi hareketleriyle** gösterecek. Bunun için yeni bir panel ya da pencere açılmayacak.

İkinci amaç, Glitch'e "hem güzel hem işlevsel" bir kimlik kazandırmak. Projenin GitHub'da ve Reddit'te (r/ClaudeAI, r/macapps) paylaşılması planlanıyor. Tek cümlelik tanıtım: *"Tüm Claude Code oturumlarını izleyen piksel şövalye."*

## Hedefler

1. Glitch, Mac'teki **tüm** Claude Code oturumlarının olaylarını alır. Proje ve klasör fark etmez.
2. Dört durum ayrı ayrı gösterilir: **izin bekliyor**, **cevap bekliyor**, **iş bitti**, **hata**.
3. Bekleyen veya bitmiş her oturum, kullanıcı ilgilenene kadar omuzda bir kıvılcımla görünür kalır.
4. Fareyle karakterin üstüne gelince oturum listesi açılır. Tıklayınca en acil oturum açılır.
5. Menüden hangi projelerin dikkate alınacağı seçilir. Varsayılan ayar hepsini izlemektir.

## Hedef olmayanlar (bu sürümde yok)

- Haiku ile konuşma ve soru sorma (sonraki sürüm).
- Odak modu ve pomodoro.
- Sistem bekçisi: CPU, pil ve ısıya göre tepki (ayrı bir tasarım).
- Satılık sürüm, çok karakterli yapı, dağıtım (App oturumunun konusu).
- Claude Code dışındaki araçları izlemek.

## Yapılmaması gerekenler (çalışsa bile başarısızlık sayılır)

- **Dikkat dağıtmak.** Glitch sürekli hareket etmeyecek, dürtmeyecek, titreşmeyecek. Muhafız sessiz bekler, sadece gerçek bir olay olduğunda tepki verir. Kullanıcı sevimli ve dikkat dağıtan şeylerden hoşlanmıyor.
- **Aynı hareketi birden fazla yerde kullanmak.** Nöbetçinin hareketleri, mevcut hareketlerin hiçbirine benzememeli. Mevcut hareketler: selam (uyanış ve kapanış), diz çökme (veda), duruş çeşitleri (tek el, iki el, kılıç yere dayalı), guard'lar (Ochs, Pflug, Vom Tag), kahraman inişi, kan fırtınası.
- **Kullanıcının ayar dosyasını bozmak.** `~/.claude/settings.json` içindeki mevcut hook'lar ve ayarlar asla silinmez ya da üzerine yazılmaz.
- **Ağ erişimi.** Olay bilgisi Mac'in dışına çıkmaz.

## Karakter davranışı (kullanıcı onayladı)

Her durumun kendine ait, yeni bir hareketi var. Hepsi mevcut tek 3/4 iskeletle (rig) yapılır. Yeni bir görünüm (önden, yandan, arkadan) eklenmez.

| Öncelik | Durum | Hareket | Kıvılcım |
|---|---|---|---|
| 1 | **İzin bekliyor:** Claude bir araç veya komut için onay istiyor | **Geçidi tutan nöbetçi:** Kılıç göğüs hizasında yatay, bariyer gibi tutulur. Kılıç kalkarken gözler bir kez parlar ve kısa, tok bir metal sesi çıkar. Cevap gelene kadar bu duruşta kalır. | Kızıl |
| 2 | **Cevap bekliyor:** Claude kullanıcıya *açıkça soru sordu* (ör. seçenekli soru aracı). Sıradan bir tur bitişi bu değildir, o "iş bitti" sayılır. | Başını ekrana, yani kullanıcıya çevirir, eli kılıcın kabzasındadır. Sakin bir duruştur. | Kızıl |
| 3 | **Hata:** Sadece oturumu durduran ciddi hatalar (API hatası, oturum çökmesi). Sıradan araç hataları sayılmaz. | **Kılıcı düşürüp yakalama:** Kılıç elinden kayar ve hemen geri yakalanır. Kısa, tek seferlik bir harekettir. Boştaki rastgele glitch titremesinden farklı olmalıdır, çünkü o titreme olduğu gibi kalıyor. | Yok (listede kızıl ✕) |
| 4 | **İş bitti:** Claude turunu bitirip durdu ve açık bir soru sormadı | **Kılıcı silkeleme + yere sürtme:** Önce bileğini sert bir hareketle sallayarak kılıcındaki kanı silkeler (~0,8 sn, "vuş" sesi, kan şeridi efekti). Sonra kılıcı yere sürter (~1 sn, metalin taşa sürtünme sesi) ve altın kıvılcımlar saçılır. Kıvılcımların çoğu söner, sonuncusu yükselip omza yerleşir. Toplam yaklaşık 2 sn. | Altın |

- **Renk dili:** Kızıl kıvılcım, kullanıcıyı bekleyen oturumdur. Altın kıvılcım, işi bitmiş ve bakılması gereken oturumdur. İkisi de karakterin mevcut paletinden alınır.
- **Birden fazla oturum:** Glitch en yüksek öncelikli durumun duruşunda durur. Omzunda her oturum için bir kıvılcım olur. Sayı rakamla değil, kıvılcım sayısıyla gösterilir.
- **Kıvılcımın sönmesi:** Kullanıcı o oturumla ilgilenince (cevap verince, izin verince ya da yeni bir mesaj yazınca) o oturumun kıvılcımı söner. Altın kıvılcım, oturuma yeni bir istek gelince, oturum kapanınca ya da **kullanıcı oturumu Glitch'e tıklayarak açınca** söner. Böylece aynı bitmiş oturum tekrar tekrar açılmaz. Zaman aşımı yok. *(Kurucunun kararı, kontrol sırasında eklendi.)*
- **Boştaki davranış:** Kızıl kıvılcımlı bir duruş sürerken boştaki rastgele hareketler (bakınma, guard, duruş değiştirme, tikler, dolaşma) durur. Sadece altın kıvılcım varken ya da hiçbir şey beklemiyorken boştaki davranış olduğu gibi devam eder. *(Kurucunun kararı, kontrol sırasında eklendi.)*
- **Hatırlatma:** Bir izin isteği 5 dakikadan uzun süre cevapsız kalırsa kılıç bir kez hafifçe sarsılır ve ses tekrar çalar. Sonra yine sessiz bekler. Bu hatırlatma tekrarlanmaz.
- **Karakter dolaşırken:** Bekleyen bir oturum varken Glitch dolaşmayı bırakıp yerinde durur.

## Fare etkileşimi (kullanıcı onayladı)

- **Üstüne gelince:** Sade, koyu bir liste açılır (mono yazı, kızıl ince çerçeve). Her satırda proje adı, oturum adı, durum ve süre yer alır, örneğin `⚔ ICON · Main — izin bekliyor · 2 dk`. Görsel taslak: `.superpowers/brainstorm/39332-1792154077/content/waiting-sessions.html`.
- **Tıklayınca:** Kıvılcım varken tıklama en acil oturumu açar. Sıralama: izin, cevap, iş bitti. Aynı öncelikte en eski olan önce gelir. Kıvılcım yoksa tıklama Glitch'in mevcut davranışını korur.
- Sürükleme ve çift tıklayınca çıkan "✕ Kapat" butonu değişmeden kalır.

## Kapsam ve filtre (kullanıcı onayladı)

- Hook'lar **genel** ayara, yani `~/.claude/settings.json` dosyasına kurulur. Böylece tüm projelerdeki oturumlar izlenir.
- Her olayda oturum kimliği ve çalışma klasörü (`cwd`) gelir. Glitch klasörü bir proje adıyla eşleştirir. Eşleştirme kullanıcı tarafından düzenlenebilir; varsayılan, klasörün adıdır. Desktop sidebar'ındaki grup adları (ICON, AVENOX BEYİN) hook'larda görünmez, o yüzden eşleştirme klasör üzerinden yapılır.
- Menü çubuğu ya da Glitch menüsünde bir proje listesi olur. Kullanıcının seçmediği projeler Glitch'i hiç etkilemez.

## Kısıtlar

- Mevcut proje yapısı korunur: SwiftUI, macOS, XcodeGen (`project.yml`). `.pbxproj` elle düzenlenmez.
- Karakter görselleri `Tools/make_sprites.py` ile parça parça üretilir. Hareketler `Brain.swift` içindeki iskelete eklenir.
- Kod iki oturumda paralel yazılıyor (Main ve Animations). Bir dosyaya dokunmadan önce `git status` ile kontrol edilir, her adımdan sonra sadece kendi dosyaları commit edilir (`[Main]` / `[Animations]` ön ekiyle).
- Her yeni hareket için önce snapshot gösterilir ve kullanıcının onayı alınır, sonra devam edilir.
- Hook'lar kurulmadan önce kullanıcıya ne ekleneceği gösterilir ve onayı alınır. Mevcut ayarlarla birleştirilir, hiçbir şey silinmez. Kaldırma seçeneği de olmalıdır.
- İmzalama, provisioning ve bundle ID'ye sormadan dokunulmaz.

## İlk iş: doğrulanacak varsayımlar

Aşağıdakiler test edilmedi. Uygulamaya başlamadan önce doğrulanmalı. Biri yanlış çıkarsa kullanıcıya haber verilir.

1. Claude **masaüstü uygulamasındaki** Code oturumları da genel hook'ları tetikliyor mu? Kullanıcının oturumlarının çoğu orada.
2. Hangi hook olayları "izin bekliyor" ile "cevap bekliyor" durumlarını ayırt edebiliyor? Bunun için kurulu Claude Code sürümünün (2.1.299) gerçek hook olayları ve girdi alanları incelenmeli.
3. Bir oturumu "açmak" için ne mümkün? Masaüstü oturumlarının `claude://claude.ai/epitaxy/local_…` biçiminde bağlantıları var, ama hook'tan gelen oturum kimliği bu `local_…` kimliğiyle aynı olmayabilir. Eşleştirme bulunamazsa geri dönüş şudur: ilgili uygulamayı (Claude ya da terminal) öne getirmek.
4. Oturumun adını, örneğin "Main", hook verisinden ya da transcript'ten almak mümkün mü? Mümkün değilse listede klasör adı ve kısa oturum kimliği gösterilir.

## Kurucuya bırakılanlar

- Hook ile Glitch arasındaki iletişim yöntemi (dosya, Unix soketi, yerel port vb.). Tek koşul: yerel kalacak ve Glitch kapalıyken Claude Code'u yavaşlatmayacak ya da bozmayacak.
- Oturum durumunu tutan veri yapısı, zaman aşımları, Glitch yeniden başlarken durumun nasıl toparlanacağı.
- Kıvılcımın tam piksel tasarımı, boyutu ve yeri. Taslaktaki hâli başlangıç noktasıdır, snapshot ile onaylanır.
- Seslerin nasıl üretileceği. Mevcut `SoundBank` sesleri koddan üretiyor, aynı yol izlenebilir.
- Menü ve filtre arayüzünün ayrıntıları (sade ve karakterin karanlık stiline uygun olmak koşuluyla).

## Bulgular (Task 0)

2026-10-17, Claude Code 2.1.299. Geçici bir kayıt hook'u kullanıcının onayıyla `~/.claude/settings.json`'a eklendi, terminalde `claude -p` ile test oturumları çalıştırıldı, sonra dosya yedekten geri yüklendi (birebir aynı) ve kayıtlar silindi. Örnek veriler kişisel içerikten temizlenip `GlitchTests/Fixtures/` altına kondu.

1. **Masaüstü oturumları genel hook'ları tetikliyor.** Zaten açık olan masaüstü oturumları bile ayar değişikliğini hemen okudu, yeni oturum açmak gerekmedi. Masaüstü oturumlarının `UserPromptSubmit` olayında ayrıca `session_title` alanı var.
2. **Olay → durum eşlemesi** (`SentinelEvent.parse`):
   - İzin bekliyor: `PermissionRequest` (`tool_name` var, `tool_use_id` yok). `Notification` + `notification_type: permission_prompt` de izin sayılır (-p modunda gelmedi).
   - Cevap bekliyor: `PreToolUse` + `tool_name: AskUserQuestion`. -p modunda doğrulanamadı; Task 8'de masaüstü oturumunda canlı doğrulandı (2026-10-17: karakter bekliyor pozuna geçti). `Notification` + `elicitation_dialog` de soru sayılır.
   - Kullanıcı ilgilendi: `UserPromptSubmit`, `PermissionDenied`; ve bekleyen aracın kendi `PostToolUse`'u (paralel araçlar yüzünden: önce `tool_use_id`, yoksa araç adı eşleşmeli).
   - İş bitti: `Stop`. `Notification` + `idle_prompt` yok sayılır (aynı bitiş iki kez sayılmasın).
   - Hata: `StopFailure` (örnek: `error: model_not_found`). Sıradan araç hataları ayrı bir olaydır (`PostToolUseFailure`) ve yok sayılır.
   - Oturum kapandı: `SessionEnd`. `SessionStart` yok sayılır.
3. **Oturumu açmak:** Claude uygulaması her masaüstü oturumu için `~/Library/Application Support/Claude/claude-code-sessions/*/*/local_<id>.json` dosyası tutuyor; içinde hook'taki oturum kimliği (`cliSessionId`), bağlantıdaki kimlik (`sessionId: local_…`) ve başlık (`title`) var. Glitch bunu **sadece okur** ve `claude://claude.ai/epitaxy/local_<id>` açar (Claude.app `claude` şemasını kayıtlı). Belgelenmemiş iç bir dosya olduğu için okuma hata toleranslıdır: dosya yoksa, alan adı değiştiyse ya da JSON bozuksa masaüstü oturumu için Claude.app, terminal oturumu için çalışan terminal öne getirilir.
4. **Oturum adı:** Önce olaydaki `session_title`, sonra yukarıdaki dosyadaki `title`, ikisi de yoksa kimliğin ilk 6 karakteri.
