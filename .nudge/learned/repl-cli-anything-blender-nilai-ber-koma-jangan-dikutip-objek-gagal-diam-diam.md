# REPL cli-anything-blender: nilai ber-koma JANGAN dikutip (objek gagal diam-diam)

## What went wrong
Saat membangun scene via `./blender-agent.sh build` (mode REPL piped stdin), memberi TANDA KUTIP pada argumen ber-koma membuat objek/material gagal terbuat TANPA error yang terlihat. Contoh gagal: `object add cube -s "3,3.75,1.5" -l "0,0,1.5"`, `material create -c "0.9,0.8,0.7,1"`, `camera add -l "13,-15,8"`. Akibat: `object list` -> 0 objek, padahal `render settings --samples 48` (tanpa koma) tetap tersimpan, sehingga `scene info` menunjukkan engine/samples benar tapi `objects: 0` -> menyesatkan. Penyebab: parser baris REPL tidak meng-shlex tanda kutip, jadi token jadi literal `"3,3.75,1.5"` lalu `float()` gagal saat parse, command di-skip diam-diam. (Berbeda dari pemanggilan one-shot `docker exec` di mana shell host yang melakukan dequote.)

## Fix
Di dalam REPL/`build`, tulis nilai ber-koma TANPA kutip (koma tanpa spasi = satu token), termasuk nilai negatif:
`object add cube -s 3,3.75,1.5 -l 0,0,1.5`
`material create -n wall -c 0.92,0.88,0.78,1 --roughness 0.85`
`camera add -l 13,-15,8 -r 72,0,41 -f 35 --active`
`light add sun -r 120,0,-30 -w 1.2 -c 0.8,0.85,1`

## Verification
`./blender-agent.sh cli --json --project <scene>.json object list | grep -c name` mengembalikan jumlah objek yang benar (mis. 7), bukan 0. Setelah perbaikan, render rumah tipe 45 (CYCLES CPU, 800x600, 48 sample) sukses dalam ~26s -> `config/rumah45.png`.
