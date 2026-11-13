# Burak Akgünoğlu Uzak Bağlantı - Windows derleme betiği
# RustDesk 1.5.3 resmi derleme adımlarını (.github/workflows/flutter-build.yml,
# x86_64-pc-windows-msvc işi) yerel bir Windows 10/11 x64 bilgisayarda uygular.
#
# Kullanım: DERLE.bat dosyasına çift tıklayın. Kendi sunucunuzu gömmek için:
#   powershell -ExecutionPolicy Bypass -File derle.ps1 -Sunucu "uzak.ornek.com" -Anahtar "GENEL_ANAHTAR="
#
# Betik yarıda kesilirse yeniden çalıştırın; biten adımlar atlanır.

param(
    [string]$Sunucu = "",
    [string]$Anahtar = "",
    [string]$CalismaKlasoru = "C:\bab-build"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Resmi derlemeyle aynı sürümler
$RustSurumu      = "1.75"
$FlutterSurumu   = "3.24.5"
$LlvmSurumu      = "15.0.6"
$VcpkgCommit     = "9e593bb18ea69cc5095e012465dcd675a822ed0d"
$VcpkgTriplet    = "x64-windows-static"
$KopruSurumu     = "1.80.1"
$CargoExpand     = "1.0.95"
$KurulumAdi      = "Burak_Akgunoglu_Uzak_Baglanti_Setup.exe"
$ExeAdi          = "BurakAkgunogluUzakBaglanti.exe"

$Kaynak  = Join-Path $PSScriptRoot "rustdesk"
$Src     = Join-Path $CalismaKlasoru "src"
$Flutter = Join-Path $CalismaKlasoru "flutter"
$Vcpkg   = Join-Path $CalismaKlasoru "vcpkg"
$Cikti   = Join-Path $PSScriptRoot "cikti"

function Adim($metin) { Write-Host ""; Write-Host "=== $metin ===" -ForegroundColor Cyan }

# Yerel komutu çalıştırır, hata kodunda durur.
# (Basit işlev: -b, --depth gibi argümanlar olduğu gibi komuta aktarılır.)
function Calistir {
    $komut = $args[0]
    $kalan = @($args | Select-Object -Skip 1)
    & $komut @kalan
    if ($LASTEXITCODE -ne 0) { throw "Komut başarısız oldu ($LASTEXITCODE): $komut $kalan" }
}

function YolYenile {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User") + ";" +
                "$env:USERPROFILE\.cargo\bin;C:\Program Files\LLVM\bin;C:\Program Files\Git\cmd;$Flutter\bin"
}

function Var($komut) { return [bool](Get-Command $komut -ErrorAction SilentlyContinue) }

function WingetKur($id, $ek) {
    $a = @("install", "--id", $id, "-e", "--silent", "--accept-package-agreements", "--accept-source-agreements") + $ek
    & winget @a
    # winget, paket zaten kuruluysa da sıfırdan farklı kod döndürür; sonucu aşağıda komutla doğruluyoruz.
    YolYenile
}

function Py {
    if (Var "py") { & py -3 @args } else { & python @args }
    if ($LASTEXITCODE -ne 0) { throw "Python komutu başarısız oldu: $args" }
}

Start-Transcript -Path (Join-Path $PSScriptRoot "derleme-gunlugu.txt") -Force | Out-Null
trap {
    Write-Host ""
    Write-Host "HATA: $_" -ForegroundColor Red
    Write-Host "Ayrıntılar: derleme-gunlugu.txt. Sorunu giderip DERLE.bat'ı yeniden çalıştırın; biten adımlar atlanır."
    Stop-Transcript | Out-Null
    break
}

# ---------------------------------------------------------------- 0. Ön kontroller
Adim "0/8 Ön kontroller"
if (-not [Environment]::Is64BitOperatingSystem) { throw "64 bit Windows 10/11 gerekir." }
$yonetici = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $yonetici) { throw "Betik yönetici olarak çalıştırılmalı. DERLE.bat dosyasını kullanın." }
if (-not (Test-Path (Join-Path $Kaynak "Cargo.toml"))) { throw "Kaynak klasörü bulunamadı: $Kaynak" }
if (-not (Var "winget")) { throw "winget bulunamadı. Microsoft Store'dan 'Uygulama Yükleyicisi'ni (App Installer) kurup yeniden deneyin." }
$surucu = (Split-Path $CalismaKlasoru -Qualifier).TrimEnd(":")
$bosGB = [math]::Round((Get-PSDrive $surucu).Free / 1GB)
if ($bosGB -lt 40) { throw "$surucu sürücüsünde en az 40 GB boş alan gerekir (şu an $bosGB GB)." }
New-Item -ItemType Directory -Force -Path $CalismaKlasoru, $Cikti | Out-Null
Write-Host "Çalışma klasörü: $CalismaKlasoru  (boş alan: $bosGB GB)"

# ---------------------------------------------------------------- 1. Araçlar
Adim "1/8 Derleme araçları (Git, Python, Visual Studio Build Tools, LLVM, Rust)"
YolYenile
if (-not (Var "git"))    { WingetKur "Git.Git" @() }
if (-not (Var "py") -and -not (Var "python")) { WingetKur "Python.Python.3.12" @() }
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vcVar = $false
if (Test-Path $vswhere) {
    $vcVar = [bool](& $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
}
if (-not $vcVar) {
    Write-Host "Visual Studio Build Tools kuruluyor (birkaç GB, 10-30 dakika sürebilir)..."
    WingetKur "Microsoft.VisualStudio.2022.BuildTools" @("--override",
        "--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --add Microsoft.VisualStudio.Component.VC.ATL")
}
if (-not (Test-Path "C:\Program Files\LLVM\bin\libclang.dll")) { WingetKur "LLVM.LLVM" @("--version", $LlvmSurumu) }
if (-not (Var "rustup")) { WingetKur "Rustlang.Rustup" @() }
foreach ($k in @("git", "rustup", "cargo")) { if (-not (Var $k)) { throw "$k kurulamadı. Bilgisayarı yeniden başlatıp DERLE.bat'ı tekrar çalıştırın." } }
if (-not (Test-Path "C:\Program Files\LLVM\bin\libclang.dll")) { throw "LLVM $LlvmSurumu kurulamadı." }
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
Calistir git config --global core.longpaths true
Calistir rustup toolchain install $RustSurumu --profile minimal -c rustfmt

# ---------------------------------------------------------------- 2. Kaynak kopyası
Adim "2/8 Kaynak kod çalışma klasörüne kopyalanıyor"
# Boşluk ve Türkçe karakter içermeyen kısa bir yolda derlenir.
& robocopy $Kaynak $Src /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Kaynak kopyalanamadı (robocopy $LASTEXITCODE)." }
Set-Location $Src
Calistir rustup override set $RustSurumu

if ($Sunucu -ne "") {
    if ($Anahtar -eq "") { throw "-Sunucu verildiğinde -Anahtar (id_ed25519.pub içeriği) da verilmelidir." }
    $cfg = Join-Path $Src "libs\hbb_common\src\config.rs"
    $t = [IO.File]::ReadAllText($cfg)
    $t = [regex]::Replace($t, 'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];', "pub const RENDEZVOUS_SERVERS: &[&str] = &[`"$Sunucu`"];")
    $t = [regex]::Replace($t, 'pub const RS_PUB_KEY: &str = "[^"]*";', "pub const RS_PUB_KEY: &str = `"$Anahtar`";")
    [IO.File]::WriteAllText($cfg, $t, (New-Object Text.UTF8Encoding $false))
    Write-Host "Sunucu gömüldü: $Sunucu"
} else {
    Write-Host "Sunucu belirtilmedi: uygulama RustDesk'in genel sunucularını kullanacak."
}

# ---------------------------------------------------------------- 3. Flutter
Adim "3/8 Flutter $FlutterSurumu"
if (-not (Test-Path "$Flutter\bin\flutter.bat")) {
    Calistir git clone --depth 1 -b $FlutterSurumu https://github.com/flutter/flutter.git $Flutter
}
YolYenile
Calistir flutter config --no-analytics
Calistir flutter precache --windows
$motorIsaret = Join-Path $Flutter "rustdesk-engine.ok"
if (-not (Test-Path $motorIsaret)) {
    # https://github.com/flutter/flutter/issues/155685 - RustDesk'in düzeltilmiş motoru
    $zip = Join-Path $CalismaKlasoru "windows-x64-release.zip"
    Invoke-WebRequest -Uri https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip -OutFile $zip
    $ac = Join-Path $CalismaKlasoru "windows-x64-release"
    if (Test-Path $ac) { Remove-Item $ac -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $ac
    Copy-Item "$ac\*" "$Flutter\bin\cache\artifacts\engine\windows-x64-release\" -Recurse -Force
    Set-Content $motorIsaret "ok"
}
$yama = Join-Path $Src ".github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff"
& cmd /c "git -C `"$Flutter`" apply --check `"$yama`" >nul 2>&1"
if ($LASTEXITCODE -eq 0) { Calistir git -C $Flutter apply $yama; Write-Host "Flutter yaması uygulandı." }
else { Write-Host "Flutter yaması zaten uygulanmış." }

# ---------------------------------------------------------------- 4. vcpkg
Adim "4/8 vcpkg kitaplıkları (ilk seferde 30-90 dakika sürer)"
if (-not (Test-Path "$Vcpkg\.git")) { Calistir git clone https://github.com/microsoft/vcpkg.git $Vcpkg }
Calistir git -C $Vcpkg fetch origin $VcpkgCommit
Calistir git -C $Vcpkg checkout $VcpkgCommit
if (-not (Test-Path "$Vcpkg\vcpkg.exe")) { Calistir "$Vcpkg\bootstrap-vcpkg.bat" -disableMetrics }
$env:VCPKG_ROOT = $Vcpkg
$env:VCPKG_DEFAULT_HOST_TRIPLET = $VcpkgTriplet
Calistir "$Vcpkg\vcpkg.exe" install --triplet $VcpkgTriplet "--x-install-root=$Vcpkg\installed"

# ---------------------------------------------------------------- 5. Köprü dosyaları
Adim "5/8 Flutter-Rust köprü dosyaları"
if (-not (Test-Path "$Src\src\bridge_generated.rs")) {
    if (-not (Var "cargo-expand")) { Calistir cargo install cargo-expand --version $CargoExpand --locked }
    if (-not (Var "flutter_rust_bridge_codegen")) {
        Calistir cargo install flutter_rust_bridge_codegen --version $KopruSurumu --features uuid --locked
    }
    Push-Location "$Src\flutter"; Calistir flutter pub get; Pop-Location
    Calistir flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h --llvm-path "C:\Program Files\LLVM"
    Copy-Item ./flutter/macos/Runner/bridge_generated.h ./flutter/ios/Runner/bridge_generated.h -Force
} else { Write-Host "Köprü dosyaları mevcut, atlanıyor." }

# ---------------------------------------------------------------- 6. Uygulama derlemesi
Adim "6/8 Uygulama derleniyor (ilk seferde 30-60 dakika sürer)"
$manifest = Join-Path $Src "res\manifest.xml"
if (Test-Path "$manifest.orig") { Copy-Item "$manifest.orig" $manifest -Force }
Py build.py --portable --flutter --skip-portable-pack --hwcodec --vram
$paket = Join-Path $Src "rustdesk"
if (Test-Path $paket) { Remove-Item $paket -Recurse -Force }
Move-Item "$Src\flutter\build\windows\x64\runner\Release" $paket
if (-not (Test-Path "$paket\rustdesk.exe")) { throw "Derleme çıktısı bulunamadı: $paket\rustdesk.exe" }
# Kurulum, exe'yi "<uygulama adı>.exe" adıyla arar.
Rename-Item "$paket\rustdesk.exe" $ExeAdi

# İsteğe bağlı sürücüler (sanal ekran, uzak yazıcı). İndirilemezse derleme sürer.
try {
    Invoke-WebRequest -Uri https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip -OutFile usbmmidd_v2.zip
    if (Test-Path usbmmidd_v2) { Remove-Item usbmmidd_v2 -Recurse -Force }
    Expand-Archive usbmmidd_v2.zip -DestinationPath .
    Remove-Item usbmmidd_v2\Win32 -Recurse -Force
    Remove-Item "usbmmidd_v2\deviceinstaller64.exe", "usbmmidd_v2\deviceinstaller.exe", "usbmmidd_v2\usbmmidd.bat" -Force
    Move-Item .\usbmmidd_v2 $paket -Force
} catch { Write-Host "Sanal ekran sürücüsü eklenemedi (isteğe bağlı): $_" -ForegroundColor Yellow }
try {
    Invoke-WebRequest -Uri https://github.com/rustdesk/hbb_common/releases/download/driver/rustdesk_printer_driver_v4-1.4.zip -OutFile rustdesk_printer_driver_v4-1.4.zip
    Invoke-WebRequest -Uri https://github.com/rustdesk/hbb_common/releases/download/driver/printer_driver_adapter.zip -OutFile printer_driver_adapter.zip
    Invoke-WebRequest -Uri https://github.com/rustdesk/hbb_common/releases/download/driver/sha256sums -OutFile sha256sums
    $s1 = (Select-String -Path .\sha256sums -Pattern '^([a-fA-F0-9]{64}) \*rustdesk_printer_driver_v4-1.4\.zip$').Matches.Groups[1].Value
    $s2 = (Select-String -Path .\sha256sums -Pattern '^([a-fA-F0-9]{64}) \*printer_driver_adapter\.zip$').Matches.Groups[1].Value
    $h1 = (Get-FileHash rustdesk_printer_driver_v4-1.4.zip -Algorithm SHA256).Hash
    $h2 = (Get-FileHash printer_driver_adapter.zip -Algorithm SHA256).Hash
    if ($s1 -eq $h1 -and $s2 -eq $h2) {
        if (Test-Path rustdesk_printer_driver_v4-1.4) { Remove-Item rustdesk_printer_driver_v4-1.4 -Recurse -Force }
        Expand-Archive rustdesk_printer_driver_v4-1.4.zip -DestinationPath .
        New-Item -ItemType Directory -Force "$paket\drivers" | Out-Null
        Move-Item .\rustdesk_printer_driver_v4-1.4 "$paket\drivers\RustDeskPrinterDriver" -Force
        Expand-Archive printer_driver_adapter.zip -DestinationPath . -Force
        Move-Item .\printer_driver_adapter.dll $paket -Force
    } else { Write-Host "Yazıcı sürücüsü sağlama toplamı uyuşmadı, eklenmedi." -ForegroundColor Yellow }
} catch { Write-Host "Yazıcı sürücüsü eklenemedi (isteğe bağlı): $_" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 7. Kurulum dosyası
Adim "7/8 Kurulum dosyası paketleniyor"
$res = Get-ChildItem -Path $Src -Recurse -Filter Runner.res -ErrorAction SilentlyContinue | Select-Object -First 1
if ($res) { Copy-Item $res.FullName "$Src\libs\portable\Runner.res" -Force }
if (-not (Test-Path "$manifest.orig")) { Copy-Item $manifest "$manifest.orig" }
$satirlar = [IO.File]::ReadAllLines($manifest) | Where-Object { $_ -notmatch 'dpiAware' }
[IO.File]::WriteAllLines($manifest, $satirlar, (New-Object Text.UTF8Encoding $false))
Push-Location "$Src\libs\portable"
Py -m pip install -r requirements.txt
Py generate.py -f ../../rustdesk/ -o . -e "../../rustdesk/$ExeAdi"
Pop-Location
$packer = Join-Path $Src "target\release\rustdesk-portable-packer.exe"
if (-not (Test-Path $packer)) { throw "Kurulum paketi üretilemedi: $packer" }
$hedef = Join-Path $Cikti $KurulumAdi
Copy-Item $packer $hedef -Force

# ---------------------------------------------------------------- 8. Sonuç
Adim "8/8 Tamamlandı"
$ozet = (Get-FileHash $hedef -Algorithm SHA256).Hash
$boyut = [math]::Round((Get-Item $hedef).Length / 1MB, 1)
Write-Host "Kurulum dosyası: $hedef" -ForegroundColor Green
Write-Host "Boyut: $boyut MB   SHA256: $ozet"
Write-Host "Dosya dijital olarak imzalı değildir; Windows SmartScreen ilk çalıştırmada uyarı gösterebilir."
Stop-Transcript | Out-Null
