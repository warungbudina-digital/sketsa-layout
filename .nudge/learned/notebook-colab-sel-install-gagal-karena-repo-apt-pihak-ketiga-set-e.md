# Notebook Colab: sel install gagal karena repo apt pihak-ketiga + set -e

## What went wrong
Sel "1 · Install" di `colab_blender_gpu_hybrid.ipynb` batal total (`CalledProcessError ... exit status 100`) saat dijalankan di Google Colab. Penyebab: runtime Colab membawa repo apt pihak-ketiga (`r2u.stat.illinois.edu`, `developer.download.nvidia.com/.../cuda`) yang INTERMITTEN gagal sync (mirror sync in progress / Sources misspelt). `apt-get update` lalu exit non-zero, dan karena sel `%%bash` pakai `set -e`, seluruh sel mati SEBELUM Blender sempat di-download — padahal repo Ubuntu utama (tempat libxrender1 dkk) sehat. Ini quirk lingkungan Colab, bukan bug stack.

## Fix
Update HANYA dari sources.list utama (abaikan `sources.list.d/*` yang berisi repo rusak) + jadikan apt non-fatal, biar download Blender tetap lanjut:
```
apt-get update -o Dir::Etc::sourceparts=/dev/null -o APT::Get::List-Cleanup=0 2>/dev/null \
  || apt-get update 2>/dev/null || true
apt-get install -y --no-install-recommends libxrender1 libxi6 libxxf86vm1 \
  libxfixes3 libxkbcommon0 libgl1 libsm6 2>/dev/null || echo "WARN: lanjut."
```
Sudah diterapkan permanen di notebook (commit 7ef03f5). `set -e` tetap melindungi bagian download/extract Blender.

## Verification
Setelah patch, sel install lolos: muncul baris versi `Blender 4.2.x` dan `cli-anything-blender OK`, meski apt pihak-ketiga masih error (kini di-ignore).
