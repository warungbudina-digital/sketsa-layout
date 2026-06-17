# cloudflared ke Selkies: origin HTTPS self-signed wajib No-TLS-Verify

## What went wrong
Mengekspos UI Selkies (container `blender`, port 3040) lewat cloudflared tunnel mudah salah: Selkies menyajikan **HTTPS self-signed** dan memaksa HTTPS. Bila Public Hostname di Cloudflare diarahkan ke origin `http://blender:3040` → redirect loop / 502; bila `https://` tanpa skip verifikasi cert → gagal verifikasi TLS (cert self-signed, CN tak cocok nama service). Kekhawatiran "double HTTPS bentrok" TIDAK relevan: cloudflared outbound-only, tak bind port inbound apa pun di VPS, TLS publik diterminasi di edge Cloudflare.

## Fix
Di Cloudflare Zero Trust ▸ Tunnels ▸ Public Hostname, set:
- Service Type: **HTTPS**, URL: **`blender:3040`** (nama service compose, bukan localhost — cloudflared di container terpisah, resolve via DNS network compose)
- Additional application settings ▸ TLS ▸ **No TLS Verify = ON**
Token taruh di `.env` (`TUNNEL_TOKEN`, jangan commit). VPS tak perlu buka port 443; mapping `ports: 3040:3040` jadi opsional. Streaming Selkies berbasis WebSocket → didukung tunnel.

## Verification
`docker compose logs -f cloudflared` menampilkan `Registered tunnel connection`; `https://<domain>` membuka desktop Selkies dengan cert Cloudflare valid (tanpa warning). Detail di RUNBOOK §F.
