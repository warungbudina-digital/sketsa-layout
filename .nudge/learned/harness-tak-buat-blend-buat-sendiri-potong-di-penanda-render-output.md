# Harness tak buat .blend -> buat sendiri (potong di penanda "Render Output")

## What went wrong
File hasil `render` adalah `.png` (gambar 2D); harness `cli-anything-blender` TIDAK pernah menyimpan `.blend` (state-nya JSON + script `bpy`). Akibatnya scene tak bisa dibuka/diedit di Blender UI (Selkies) — File ▸ Open menolak `.png`. Mencoba membuat `.blend` dengan menambahkan `save_as_mainfile` di AKHIR `_render_script.py` berhasil tapi memicu render ulang penuh (~26s) yang mubazir, karena render call ada sebelum titik akhir.

## Fix
`_render_script.py` hasil generate punya penanda komentar `# == Render Output ==` (gunakan substring "Render Output"); SEMUA pembangunan scene ada di atasnya, render call di bawahnya. Untuk membuat `.blend` tanpa render: potong script di penanda itu lalu sisipkan save.
```
awk "/Render Output/{exit} {print}" _render_script.py > /tmp/to_blend.py
printf "\nimport bpy\nbpy.ops.wm.save_as_mainfile(filepath=r\"/config/x.blend\")\n" >> /tmp/to_blend.py
blender --background --python /tmp/to_blend.py
```
Sudah dibungkus jadi subcommand: `./blender-agent.sh blend <scene.json> <out.blend>` (commit 705d6df). Output `.blend` mendarat di volume `/config` = home desktop Selkies; buka via File ▸ Open ▸ Home.

## Verification
`./blender-agent.sh blend /config/rumah45.json /config/rumah45_v2.blend` selesai ~1.9s (bukan ~26s), `file config/rumah45_v2.blend` -> "Zstandard compressed data" (.blend valid), dan TIDAK ada stub `.png` tertinggal (render benar-benar dilewati).
