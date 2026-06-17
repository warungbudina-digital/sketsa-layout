# cli-anything-blender: state hanya persist via REPL + scene save

## What went wrong
Mengorkestrasi harness `cli-anything-blender` (v1.0.0) lewat panggilan `docker exec` one-shot terpisah membuat scene KOSONG. Perintah mutasi (`object add`, `light add`, `camera add`, `render settings`) hanya mengubah project di memori — tidak ada auto-save / `call_on_close` / `result_callback`. Tiap proses `docker exec` membaca ulang file dari disk yang belum berubah, jadi `object list` selalu `[]`. Selain itu `scene new` GAGAL bila diberi `--project` (flag itu memaksa membuka file yang belum ada → FileNotFoundError), dan `render execute OUTPUT_PATH` TIDAK merender — ia hanya men-generate `_render_script.py` lalu mengembalikan string `command`.

## Fix
- `scene new` dijalankan TANPA `--project`, pakai `-o /config/scene.json`.
- Mutasi harus dalam SATU proses REPL (pipe via stdin) dan diakhiri `scene save`, lalu sub-perintah lain pakai `--project`. Contoh:
  `docker exec -i -u abc blender cli-anything-blender --project /config/scene.json <<EOF` ... `scene save` / `exit` / `EOF`
- Render nyata = setelah `render execute`, jalankan `blender --background --python /config/_render_script.py` (atau pakai jalur `preview capture`).

## Verification
`docker exec -u abc blender cli-anything-blender --json --project /config/scene.json object list` menampilkan object setelah `scene save` (bukan `[]`); file `/config/out.png` muncul setelah menjalankan `_render_script.py`.
