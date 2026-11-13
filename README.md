# Burak Akgünoğlu Uzak Bağlantı

Windows 10/11 için Türkçe arayüzlü uzak masaüstü uygulaması. Açık kaynaklı
[RustDesk](https://github.com/rustdesk/rustdesk) **1.5.3** sürümünün markalanmış bir türevidir
(AGPL-3.0). Uzak bağlantı protokolü, şifreleme, NAT geçişi ve relay altyapısı sıfırdan yazılmadı;
RustDesk'in yıllardır kullanılan kodu aynen korundu.

## İndirme

Kurulum dosyası bu deponun **Releases** sayfasında yayımlanır:
`Burak_Akgunoglu_Uzak_Baglanti_Setup.exe` dosyasını indirip çift tıklayın. Dosya, depoya yapılan her
değişiklikte GitHub Actions tarafından otomatik derlenir (`.github/workflows/derle.yml`).

Yerel derleme dosyaları (`DERLE.bat`, `derle.ps1`) `yerel-derleme\` klasöründedir; aşağıdaki
"Derleme" bölümü o yolu anlatır. Özgün RustDesk tanıtım dosyası: `README-RustDesk.md`.

## Durum (13 Kasım 2026)

| Konu | Durum |
|---|---|
| Markalanmış kaynak kod | Hazır (bu paket) |
| Windows derleme betiği (`DERLE.bat`) | Hazır, **henüz hiçbir Windows bilgisayarda çalıştırılmadı** |
| `Burak_Akgunoglu_Uzak_Baglanti_Setup.exe` | **Yok.** Betik bir Windows bilgisayarda çalıştırılınca `cikti\` klasöründe oluşur |
| Kurulum / kaldırma testi | Yapılmadı |
| İki bilgisayar arası bağlantı testi | Yapılmadı |
| Sunucu | Varsayılan: RustDesk'in genel sunucuları (üçüncü taraf). Kendi sunucu dosyaları `sunucu\` klasöründe hazır, kurulmadı |

Bu paket Linux üzerinde hazırlandı. Değişen Rust dosyaları yalnızca sözdizimi açısından denetlendi;
tam derleme Windows gerektirdiği için yapılamadı. İlk derlemede hata çıkarsa `derleme-gunlugu.txt`
dosyası sorunu gösterir.

## Paket içeriği

```
README.md                 Bu dosya
DERLE.bat                 Çift tıklayın: derlemeyi yönetici olarak başlatır
derle.ps1                 Derleme betiği (araçları kurar, derler, Setup.exe üretir)
DEGISIKLIKLER.patch       RustDesk 1.5.3 üzerine yapılan metin değişiklikleri
rustdesk\                 Markalanmış kaynak kod (LICENCE dosyası dahil)
sunucu\                   Kendi kimlik/relay sunucunuz için docker-compose.yml ve kur.sh
```

## Derleme

Gereken: Windows 10 veya 11 (64 bit), yönetici hesabı, en az 40 GB boş disk, 16 GB RAM önerilir,
internet bağlantısı. İlk derleme 1,5-3 saat sürer (çoğu bekleme süresidir).

1. `Kaynak_Kod.zip` dosyasını kısa bir yola açın, örneğin `C:\bab`.
2. `DERLE.bat` dosyasına çift tıklayın, yönetici onayını verin.
3. Betik bitince kurulum dosyası burada olur: `cikti\Burak_Akgunoglu_Uzak_Baglanti_Setup.exe`

Betik yarıda kesilirse `DERLE.bat`'ı yeniden çalıştırın; biten adımlar atlanır.

### Betiğin kurduğu bağımlılıklar

RustDesk'in resmi derlemesiyle (`.github/workflows/flutter-build.yml`) aynı sürümler:

| Araç | Sürüm | Kaynak |
|---|---|---|
| Git, Python 3.12 | güncel | winget |
| Visual Studio 2022 Build Tools (C++ iş yükü) | güncel | winget |
| LLVM / Clang | 15.0.6 | winget |
| Rust | 1.75 | rustup |
| Flutter | 3.24.5 + RustDesk motor düzeltmesi | GitHub |
| vcpkg (aom, libvpx, libyuv, opus, ffmpeg, mfx-dispatch, libjpeg-turbo) | `9e593bb` | GitHub |
| flutter_rust_bridge_codegen | 1.80.1 | cargo |

Çalışma klasörü `C:\bab-build` olur (yaklaşık 25-30 GB). Derleme bittikten sonra silebilirsiniz.

### Kendi sunucunuzu gömerek derleme

```
powershell -ExecutionPolicy Bypass -File derle.ps1 -Sunucu "uzak.alanadiniz.com" -Anahtar "id_ed25519.pub içeriği"
```

Bu yapılmazsa sunucu adresi kurulumdan sonra uygulamanın Ayarlar > Ağ bölümünden de girilebilir.

## Sunucu altyapısı

İki bilgisayarın farklı ağlardan buluşabilmesi için bir kimlik sunucusu (hbbs) ve doğrudan bağlantı
kurulamadığında devreye giren bir relay sunucusu (hbbr) gerekir.

- **Şu anki seçim:** RustDesk'in ücretsiz genel sunucuları. Bu bir üçüncü taraf bağımlılığıdır;
  hız ve süreklilik garantisi yoktur ve markalanmış istemcilerin bu sunucularda çalışmaya devam
  edeceği garanti edilmez. Oturum içeriği uçtan uca şifrelidir, sunucu ekranı göremez.
- **Kalıcı çözüm:** Sabit IP'li küçük bir Linux VPS (1 vCPU / 1 GB RAM yeterli). `sunucu\` klasörünü
  sunucuya kopyalayıp `sudo bash kur.sh` çalıştırın. Açılması gereken portlar: TCP 21115-21117,
  UDP 21116. Betiğin yazdırdığı genel anahtarı yukarıdaki `-Anahtar` değerine verin.
  Paylaşımlı cPanel hosting bu sunucuları çalıştıramaz.

## Özellikler

RustDesk 1.5.3'ten gelen ve bu türevde değiştirilmeyen özellikler: cihaz kimliği, tek kullanımlık
ve kalıcı şifre, bağlantı isteğinde onay penceresi, uçtan uca şifreli iletişim, başarısız giriş
denemesi sınırı, canlı ekran, fare/klavye denetimi, tam ekran, çoklu monitör, otomatik kalite,
dosya aktarımı (sürükle-bırak, ilerleme, kaldığı yerden sürdürme), pano aktarımı, sohbet, bağlantı
geçmişi, favoriler, güvenilir cihazlar, sistem tepsisi, Windows ile başlama (servis), kaldırma.

Bilinen sınırlar:

- Bağlantı kayıtları uygulamanın günlük dosyalarına yazılır. Merkezi denetim günlüğü (audit log)
  RustDesk'in ücretli sunucu sürümüne aittir, bu pakette yoktur.
- Masaüstü ve Başlat menüsü kısayolu ile kurulum klasörü `BurakAkgunogluUzakBaglanti` adını taşır
  (aşağıya bakın). Pencere başlıkları, tepsi ve arayüz metinleri "Burak Akgünoğlu Uzak Bağlantı"dır.
- Kurulum dosyası dijital olarak imzalı değildir; Windows SmartScreen ilk çalıştırmada uyarı
  gösterebilir. Bunun kalıcı çözümü bir kod imzalama sertifikasıdır.
- Gizlilik modu için gereken `WindowInjection.dll` derlenmez; o özellik kullanılamaz.

## RustDesk 1.5.3 üzerine yapılan değişiklikler

Tam liste `DEGISIKLIKLER.patch` dosyasındadır. Özet (değişiklik tarihi: 13.11.2026):

- **İç ad** `RustDesk` → `BurakAkgunogluUzakBaglanti` (`libs/hbb_common/src/config.rs`). Bu ad Windows
  servis adı, kayıt defteri anahtarı ve kurulum klasörü olarak tırnaksız kullanıldığı için boşluksuz
  ve ASCII tutuldu.
- **Görünen ad** "Burak Akgünoğlu Uzak Bağlantı" (`src/common.rs` içinde `DISPLAY_NAME`): pencere
  başlıkları, tepsi ipucu, çeviri metinleri, Program Ekle/Kaldır kaydı, exe özellikleri.
- **Varsayılan dil Türkçe** (`src/lang.rs`); Ayarlar'dan başka dil seçilebilir.
- **Kurulum dosyası adı:** adı `setup.exe` ile biten dosya da kurulum modunda açılır
  (`src/common.rs`, `libs/portable/src/main.rs`).
- **Tema:** vurgu rengi mavi, koyu tema lacivert (`flutter/lib/common.dart`).
- **Simge:** `res/` ve `flutter/` altındaki uygulama ve tepsi simgeleri.

## Lisans

RustDesk, GNU Affero General Public License v3.0 ile lisanslıdır; bu türev de aynı lisansa tabidir.
Lisans metni `rustdesk\LICENCE` dosyasındadır, özgün telif bildirimleri korunmuştur.

Uygulamayı başkalarına (örneğin müşterilerinize) dağıttığınızda bu kaynak kodu da talep edene
vermeniz gerekir; `Kaynak_Kod.zip` dosyasını saklayın. "RustDesk" adı ve logosu Purslane Tech Pte.
Ltd.'ye aittir ve bu türevde marka olarak kullanılmaz. Bu bir hukuki görüş değildir.
