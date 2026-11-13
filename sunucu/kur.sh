#!/usr/bin/env bash
# Burak Akgünoğlu Uzak Bağlantı - sunucu kurulumu (Ubuntu 22.04 / 24.04, root olarak).
# Kullanım:  sudo bash kur.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "root olarak çalıştırın: sudo bash kur.sh"; exit 1; fi
cd "$(dirname "$0")"

# 1) Docker
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

# 2) Güvenlik duvarı (ufw etkinse). 21114 ve 21118-21119 yalnızca web istemcisi/Pro içindir, açılmaz.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 21115:21117/tcp
  ufw allow 21116/udp
fi

# 3) Sunucuları başlat
mkdir -p data
docker compose up -d

# 4) Genel anahtar ilk açılışta üretilir
for _ in $(seq 1 30); do [ -f data/id_ed25519.pub ] && break; sleep 1; done
echo
echo "Kurulum tamam."
echo "Sunucu adresi : bu sunucunun IP adresi veya alan adı"
echo "Genel anahtar : $(cat data/id_ed25519.pub 2>/dev/null || echo 'data/id_ed25519.pub henüz oluşmadı, birkaç saniye sonra bakın')"
echo
echo "Sağlayıcınızın panelinde de şu portları açın: TCP 21115-21117, UDP 21116"
echo "data/id_ed25519 (özel anahtar) dosyasını kimseyle paylaşmayın ve yedekleyin."
