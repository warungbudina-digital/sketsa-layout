# Blender Agent — Kombinasi 1 (CLI-Anything × docker-blender)

Claude (otak) → `cli-anything-blender` (tangan, harness CLI) → Blender headless +
GUI Selkies (tubuh). Harness di-**co-locate** di dalam container Blender
linuxserver supaya `shutil.which("blender")` selalu menemukan binary.

- **Image**: `blender-agent:latest` (lihat `Dockerfile`) — base
  `lscr.io/linuxserver/blender:latest` + venv `/opt/cli-anything` berisi
  `cli-anything-blender 1.0.0`. Berisi **Blender 5.1.2**.
- **UI**: Selkies web di `https://<host>:3040/` (`CUSTOM_HTTPS_PORT=3040`).
- **State**: volume `./config` → `/config` (scene JSON, preview, output render).

## Build & jalan

```bash
docker compose up -d --build
docker compose ps                 # cek port 3040 ter-map
docker compose logs -f blender    # tunggu Selkies siap
```

## Orkestrasi (pakai wrapper `blender-agent.sh`)

Wrapper menangani otomatis `-u abc`, pola REPL+save, dan patch EEVEE.

```bash
./blender-agent.sh new /config/scene.json

./blender-agent.sh build /config/scene.json <<'EOF'
object add cube
camera add
light add sun
render settings --engine CYCLES --samples 32 -rx 320 -ry 240 --output-path /config/out.png
EOF

./blender-agent.sh render /config/scene.json /config/out.png
```

`./blender-agent.sh cli <args>` = passthrough ke `cli-anything-blender` (selalu
sebagai user `abc`), mis. `./blender-agent.sh cli --json --project /config/scene.json object list`.

## Constraint VPS

- **Tanpa GPU** → render CPU. Iterasi cepat pakai `WORKBENCH`; final pakai
  `CYCLES` sample rendah. (EEVEE perlu patch enum, lihat di bawah.)
- **Disk ketat (~23GB free)** → arahkan output ke `/config` dan rutin bersihkan;
  image ini sendiri ~beberapa GB.
- **Swap 0** → hindari scene raksasa agar tak OOM.

## Gotcha (terverifikasi saat uji — juga ada di `.nudge/learned/`)

1. **`scene new` TANPA `--project`.** `--project` memaksa membuka file yang belum
   ada → `FileNotFoundError`. Pakai `scene new -o <path>`.
2. **Mutasi one-shot tidak persist.** `object add`, `light add`, `render settings`,
   dst. hanya ubah memori — tak ada auto-save. Harus dalam **satu proses REPL**
   diakhiri `scene save` (inilah yang dilakukan `build`).
3. **`render execute` tidak merender** — hanya generate `_render_script.py` +
   mengembalikan string `command`. Render nyata = `blender --background --python
   _render_script.py` (dilakukan oleh `render`).
4. **`BLENDER_EEVEE_NEXT` gagal di Blender 5.x** — harus `BLENDER_EEVEE`. Wrapper
   `render` mem-patch otomatis dengan `sed`. Error `EGL_BAD_MATCH` di VPS tanpa
   GPU adalah warning, bukan fatal.
5. **`docker exec` default root** → artifact di `/config` jadi milik root. Selalu
   `-u abc` (sudah ditangani wrapper). Bila terlanjur ada file root-owned (user
   `abc` jadi `Permission denied` saat tulis history/script), jalankan sekali:
   `./blender-agent.sh fix-perms`.
