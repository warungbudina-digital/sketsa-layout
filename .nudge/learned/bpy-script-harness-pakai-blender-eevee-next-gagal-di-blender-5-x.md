# bpy script harness pakai BLENDER_EEVEE_NEXT, gagal di Blender 5.x

## What went wrong
Menjalankan `_render_script.py` hasil generate `cli-anything-blender` dengan engine EEVEE gagal di image ini (Blender 5.1.2):
`TypeError: bpy_struct: item.attr = val: enum "BLENDER_EEVEE_NEXT" not found in ('BLENDER_EEVEE', 'BLENDER_WORKBENCH', 'CYCLES')`.
Harness ditulis untuk era Blender 4.2-4.x (di mana EEVEE Next ber-id `BLENDER_EEVEE_NEXT`); di Blender 5.x id-nya di-rename balik menjadi `BLENDER_EEVEE`.

## Fix
Gunakan engine `CYCLES` atau `WORKBENCH` (valid di semua versi), ATAU patch script sebelum render:
`sed -i 's/BLENDER_EEVEE_NEXT/BLENDER_EEVEE/g' /config/_render_script.py`
Catatan: error `EGL_BAD_MATCH (0x3009)` saat render di VPS tanpa GPU adalah warning, BUKAN fatal — output PNG tetap tersimpan.

## Verification
`docker exec -u abc blender blender --background --python /config/_render_script.py` mengeluarkan baris `Saved: '/config/out.png'` dan `file /config/out.png` melaporkan PNG valid.
