# Glitch App v1: çok karakterli masaüstü pet

Onay: kullanıcı 2026-10-17'de tasarımı onayladı ("artık bu app'i başlatalım … her şey programda olsun").

## Hedef
Glitch'i satılabilir bir uygulamaya çevirmek: karakter seçimi, Customize menüsü, Ses menüsü. Sade, ciddi, az dikkat dağıtan.

## Kararlar
- Karakterler: hazır karakterler + (v2) parça birleştirerek kişiselleştirme. Temalar farklı, stil ortak: ciddi/sade, sevimli değil.
- v1 = ayarlar altyapısı + Customize + Ses + Glitch. Karakter #2 ve #3 **tasarım onayı bekliyor**: kullanıcıya sorulmadan çizilmez. Seçim ekranında "tasarım bekliyor" diye kilitli görünürler.
- Tek görünüm (3/4), tüm hareket tek rig'den: Glitch'teki karar korunur.
- Karakter verisi şimdilik kodda. JSON paket formatı ikinci karakter gerçekten çizildiğinde eklenir (o zaman motorun neyi parametre alacağı belli olur).

## Ayarlar (UserDefaults, `Prefs`)
| Anahtar | Değerler | Etkisi |
|---|---|---|
| character | "glitch" | seçili karakter |
| scale | 1 / 2 / 3 | karakter boyutu, anında |
| hue | 0 / 35 / 140 / 200 derece | renk teması (kızıl, kehribar, zümrüt, buz), anında |
| liveliness | 0 sakin / 1 normal / 2 hareketli | kendiliğinden hareket sıklığı |
| gravity | bool | yer çekimi |
| hideInFullscreen | bool | tam ekranda gizlen |
| volume | 0...1 | ana ses |
| muted | bool | sessiz |
| sound.<grup> | bool | olay grubu sesi: arrival, reactions, movement, glitch, sword |

## Arayüz
- Menü çubuğu: mevcut öğeler + "Customize…", "Ses…".
- Tek pencere, iki sekme (Customize, Ses). Customize'da canlı önizleme.

## Kapsam dışı (v2)
Parça birleştirme editörü, kullanıcı karakter paketleri, mağaza/lisans, imzalama ve dağıtım kararı.
