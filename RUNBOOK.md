# RUNBOOK — Blender Agent (Kombinasi 1 + Hybrid GPU)

Panduan operasional. Untuk arsitektur & alasan desain, lihat [`NOTES.md`](NOTES.md).
Insiden terverifikasi terekam di [`.nudge/learned/`](.nudge/learned/).

Repo: `github.com/warungbudina-digital/sketsa-layout` (branch `main`).

---

## A. Deploy host (VPS dedicated, tanpa GPU)

Prasyarat: Ubuntu 22.04/24.04, akses root/sudo, Docker + compose plugin.

```bash
# 1. (sekali) swap sebagai bantalan anti-OOM — VPS render JANGAN swap 0
sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 2. clone + build + jalan
git clone https://github.com/warungbudina-digital/sketsa-layout.git
cd sketsa-layout
docker compose up -d --build

# 3. verifikasi
docker compose ps                         # port 3040 ter-map
docker compose logs -f blender            # tunggu Selkies siap
```

UI desktop: **`https://<ip-vps>:3040/`** (sertifikat self-signed → wajar).

Smoke test cepat (harus menghasilkan PNG):
```bash
./blender-agent.sh new   /config/scene.json
./blender-agent.sh build /config/scene.json <<'EOF'
object add monkey
camera add
light add sun
render settings --engine CYCLES --samples 32 -rx 256 -ry 192 --output-path /config/out.png
EOF
./blender-agent.sh render /config/scene.json /config/out.png
ls -la config/out.png      # owner = user host, bukan root
```

---

## B. Operasi harian (Claude/otak via `blender-agent.sh`)

| Aksi | Perintah |
|---|---|
| Scene baru | `./blender-agent.sh new /config/<nama>.json` |
| Bangun + simpan (REPL) | `./blender-agent.sh build /config/<nama>.json <<'EOF' … EOF` |
| Render headless CPU | `./blender-agent.sh render /config/<nama>.json /config/<out>.png` |
| Perintah harness apa pun | `./blender-agent.sh cli --json --project /config/<nama>.json object list` |
| Perbaiki owner file | `./blender-agent.sh fix-perms` |

Aturan emas (lihat NOTES §gotcha): `new` **tanpa** `--project`; mutasi **harus** lewat
`build` (REPL+`scene save`); `render` sudah otomatis generate script + patch EEVEE + jalankan Blender.

Engine tanpa GPU: **WORKBENCH** untuk preview kilat, **CYCLES** sample rendah untuk final.

---

## C. Offload render ke GPU via Colab (jalur hybrid)

Untuk render berat, pindahkan langkah render ke GPU gratis Colab. Host tetap di VPS.

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/warungbudina-digital/sketsa-layout/blob/main/colab_blender_gpu_hybrid.ipynb)

1. **Di VPS** — generate script lalu kirim ke Drive (sekali setup `rclone config` untuk remote `gdrive`):
   ```bash
   ./blender-agent.sh cli --json --project /config/scene.json render execute /config/out.png --overwrite
   rclone copy config/_render_script.py gdrive:blender-hybrid/in/
   # sertakan aset (.blend/tekstur) bila scene memakainya
   ```
2. **Di Colab** — buka notebook lewat badge di atas (atau ganti `github.com`→`githubtocolab.com`
   pada URL file). Set **Runtime ▸ GPU (T4)**, lalu Run sel 0→5 (**Mode A**).
   - Cek baris `[prelude] backend=OPTIX gpu_devices=1` = GPU aktif.
   - Sel 6 (**Mode B**) = smoke test mandiri tanpa VPS.
3. **Ambil hasil** — output tersimpan di `gdrive:blender-hybrid/out/`. Di VPS:
   ```bash
   rclone copy gdrive:blender-hybrid/out/ config/renders/
   ```

> ToS: Colab untuk render burst/interaktif, BUKAN server 24/7 atau job otomatis tanpa henti.

---

## D. Troubleshooting (insiden terverifikasi)

| Gejala | Penyebab | Solusi |
|---|---|---|
| `object list` selalu `[]` | mutasi one-shot tak persist | pakai `build` (REPL + `scene save`), bukan exec terpisah |
| `FileNotFoundError: scene.json` saat `scene new` | `--project` memaksa buka file belum ada | `new` **tanpa** `--project` (`-o` saja) |
| `render execute` selesai tapi tak ada PNG | ia hanya generate `_render_script.py` | jalankan script via `render` (sudah otomatis di wrapper) |
| `enum "BLENDER_EEVEE_NEXT" not found` | Blender 5.x rename enum | `render` mem-patch otomatis; manual: `sed -i 's/BLENDER_EEVEE_NEXT/BLENDER_EEVEE/g'` |
| `Permission denied: .../history` / `_render_script.py` | file `/config` ter-root-kan | `./blender-agent.sh fix-perms` |
| `EGL_BAD_MATCH (0x3009)` saat render | warning GL di VPS tanpa GPU | **abaikan** — non-fatal, output tetap tersimpan |
| Render lambat / VPS throttle | VPS shared/burstable | pindah ke instance **Dedicated/CPU-Optimized** (lihat NOTES) |

---

## E. Maintenance

```bash
# bersihkan output render (disk VPS ketat)
rm -f config/*.png config/_render_script.py config/renders/*

# update image Blender + harness
docker compose build --no-cache && docker compose up -d

# pantau resource
docker stats blender --no-stream
df -h / && free -h
```
