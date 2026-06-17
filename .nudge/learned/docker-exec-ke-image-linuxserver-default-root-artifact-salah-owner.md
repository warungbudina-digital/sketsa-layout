# docker exec ke image linuxserver default root → artifact salah owner

## What went wrong
Mengorkestrasi container `blender` (base linuxserver/selkies, PUID/PGID=1000) lewat `docker exec` tanpa `-u` berjalan sebagai root. Artifact di volume `/config` (mis. `out.png`, `scene.json`, `_render_script.py`) jadi milik `root:root` di host, padahal GUI Selkies berjalan sebagai user `abc` (PUID 1000) → file tidak bisa di-edit user host dan bisa bentrok dengan GUI.

Gejala downstream yang MENYESATKAN: setelah ada file root-owned di `/config`,
menjalankan harness sebagai `-u abc` gagal dengan traceback `prompt_toolkit`
yang panjang — `Unhandled exception in event loop ... Permission denied:
'/config/.cli-anything-blender/history'` di REPL, dan `PermissionError: ...
'/config/_render_script.py'` saat `render execute`. Itu BUKAN bug REPL/piping,
murni masalah izin tulis karena owner campur root vs abc.

## Fix
Selalu tambahkan `-u abc` pada `docker exec` agar file dimiliki PUID/PGID host:
`docker exec -u abc blender <cmd>`
Bila terlanjur tercampur owner root, samakan sekali:
`docker exec -u root blender chown -R abc:abc /config`  (atau `./blender-agent.sh fix-perms`).

## Verification
`ls -la config/out.png` di host menampilkan owner user (uid 1000), bukan `root`.
Setelah `fix-perms`, `./blender-agent.sh build ...` dan `render` berjalan tanpa
`Permission denied` (mis. `Saved: '/config/suzanne.png'`).
