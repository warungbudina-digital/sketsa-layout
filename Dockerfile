# syntax=docker/dockerfile:1
#
# Kombinasi 1 — Co-located: harness CLI-Anything (tangan) dipasang DI DALAM
# container Blender linuxserver (tubuh: binary `blender` + desktop web Selkies).
# Claude (otak) mengorkestrasi dari host via `docker exec`.
#
# Base sudah berisi: /usr/bin/blender (symlink) + GUI Selkies.
# Ganti baris FROM ke tag build lokal docker-blender milikmu bila perlu,
# mis. FROM blender:local
FROM lscr.io/linuxserver/blender:latest

# --- Ganti port UI web ke 3040 ---------------------------------------------
# Image Selkies linuxserver mendukung CUSTOM_PORT (HTTP) & CUSTOM_HTTPS_PORT.
# HTTPS WAJIB pada image terbaru, jadi UI diakses di: https://<host>:3040/
ENV CUSTOM_HTTPS_PORT=3040

# --- Pasang harness cli-anything-blender (Claude = otak) -------------------
# Ubuntu 24.04+ menerapkan PEP 668 (externally-managed), jadi harness dipasang
# di venv terisolasi /opt/cli-anything agar tidak mengganggu Python sistem.
RUN \
  echo "**** install python toolchain ****" && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    python3 \
    python3-venv \
    python3-pip && \
  echo "**** install cli-anything-blender harness ****" && \
  python3 -m venv /opt/cli-anything && \
  /opt/cli-anything/bin/pip install --no-cache-dir --upgrade pip && \
  /opt/cli-anything/bin/pip install --no-cache-dir cli-anything-blender && \
  # --- Fallback bila PyPI tidak tersedia: install langsung dari source repo ---
  # /opt/cli-anything/bin/pip install --no-cache-dir \
  #   "git+https://github.com/HKUDS/CLI-Anything.git#subdirectory=blender/agent-harness" && \
  echo "**** verify harness + binary co-located ****" && \
  /opt/cli-anything/bin/cli-anything-blender --help >/dev/null && \
  blender --version && \
  echo "**** cleanup ****" && \
  apt-get clean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Pastikan harness ada di PATH untuk semua sesi `docker exec` (default user root).
ENV PATH="/opt/cli-anything/bin:${PATH}"
RUN ln -sf /opt/cli-anything/bin/cli-anything-blender /usr/local/bin/cli-anything-blender

# Port UI baru + volume state persisten (scene JSON, preview bundle, render).
EXPOSE 3040
VOLUME /config
