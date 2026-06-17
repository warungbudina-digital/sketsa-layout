#!/usr/bin/env bash
#
# blender-agent.sh — wrapper orkestrasi cli-anything-blender di container Blender
# (Kombinasi 1: harness co-located dengan binary Blender, base image linuxserver).
#
# Menangani otomatis 3 gotcha yang ditemukan saat uji:
#   1. docker exec default root  -> selalu pakai `-u abc` (PUID host)
#   2. mutasi tak persist        -> sub-perintah dibungkus REPL + `scene save`
#   3. enum BLENDER_EEVEE_NEXT    -> di-patch ke BLENDER_EEVEE sebelum render
#
# Lihat NOTES.md untuk detail.
#
# Penggunaan:
#   ./blender-agent.sh new   <scene.json>
#   ./blender-agent.sh build <scene.json>   <perintah via stdin/heredoc>
#   ./blender-agent.sh render <scene.json> <out.png>
#   ./blender-agent.sh blend <scene.json> <out.blend>   # buat .blend (tanpa render)
#   ./blender-agent.sh cli   <args...>      # passthrough ke cli-anything-blender
set -euo pipefail

CONTAINER="${BLENDER_CONTAINER:-blender}"
RUN_USER="${BLENDER_USER:-abc}"

dexec()   { docker exec       -u "$RUN_USER" "$CONTAINER" "$@"; }
dexec_i() { docker exec -i    -u "$RUN_USER" "$CONTAINER" "$@"; }

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; s/^#//'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    proj="${1:?Usage: new <scene.json>}"
    # scene new TANPA --project (flag itu memaksa membuka file yang belum ada)
    dexec cli-anything-blender --json scene new -o "$proj"
    ;;

  build)
    # Baca perintah harness dari stdin, jalankan dalam SATU proses REPL,
    # lalu sisipkan `scene save` + `exit` agar perubahan ter-persist ke disk.
    proj="${1:?Usage: build <scene.json>   (perintah dialirkan via stdin)}"
    { cat; printf '\nscene save\nexit\n'; } \
      | dexec_i cli-anything-blender --project "$proj"
    ;;

  render)
    proj="${1:?Usage: render <scene.json> <out.png>}"
    out="${2:?Usage: render <scene.json> <out.png>}"
    script="$(dirname "$out")/_render_script.py"
    # 1) generate bpy script (render execute TIDAK merender, hanya generate)
    dexec cli-anything-blender --json --project "$proj" \
      render execute "$out" --overwrite >/dev/null
    # 2) workaround Blender 5.x: enum EEVEE Next di-rename
    dexec sed -i 's/BLENDER_EEVEE_NEXT/BLENDER_EEVEE/g' "$script"
    # 3) render headless nyata (CPU; warning EGL di VPS tanpa GPU itu non-fatal)
    dexec blender --background --python "$script"
    echo "→ output: $out (di volume /config)"
    ;;

  blend)
    # Buat .blend yang bisa dibuka di Blender UI — TANPA render.
    # Script harness membangun scene lalu merender; kita potong di penanda
    # "# ── Render Output ─" (scene sudah lengkap di atasnya) lalu sisipkan
    # save_as_mainfile. Output .blend mendarat di volume /config.
    proj="${1:?Usage: blend <scene.json> <out.blend>}"
    out="${2:?Usage: blend <scene.json> <out.blend>}"
    stub="$(dirname "$out")/.blend_stub.png"   # render execute hanya generate script
    script="$(dirname "$stub")/_render_script.py"
    dexec cli-anything-blender --json --project "$proj" \
      render execute "$stub" --overwrite >/dev/null
    docker exec -u "$RUN_USER" -e B_SCRIPT="$script" -e B_OUT="$out" "$CONTAINER" bash -lc '
      awk "/Render Output/{exit} {print}" "$B_SCRIPT" > /tmp/to_blend.py
      sed -i "s/BLENDER_EEVEE_NEXT/BLENDER_EEVEE/g" /tmp/to_blend.py
      printf "\nimport bpy\nbpy.ops.wm.save_as_mainfile(filepath=r\"%s\")\nprint(\"SAVED_BLEND\", \"%s\")\n" "$B_OUT" "$B_OUT" >> /tmp/to_blend.py
      blender --background --python /tmp/to_blend.py'
    echo "→ blend: $out (buka di Blender UI: File ▸ Open ▸ Home/$out)"
    ;;

  cli)
    dexec cli-anything-blender "$@"
    ;;

  fix-perms)
    # Samakan kepemilikan /config ke abc (PUID 1000) bila ada file ter-root-kan
    # (mis. sisa eksperimen `docker exec` tanpa `-u abc`).
    docker exec -u root "$CONTAINER" chown -R "$RUN_USER":"$RUN_USER" /config
    echo "→ /config kini dimiliki $RUN_USER"
    ;;

  ""|-h|--help|help)
    usage
    ;;

  *)
    echo "Perintah tak dikenal: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
