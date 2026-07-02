# CloudOS — Your personal cloud, modular & distributed

One command to deploy your private cloud. AI-configured, modular, mesh-ready.

## Vízia

CloudOS je opensource platforma, ktorá spája silu FOSS self-hosted služieb s jednoduchosťou Google/Apple ekosystému.

### Princípy

1. **Zero-to-cloud v jednom príkaze** — `cloudos up` detekuje tvoje prostredie a spustí všetko čo potrebuješ
2. **Modulárny dizajn** — každá služba je samostatný modul. Pridávaš iba to, čo reálne chceš
3. **AI glue** — Hermes agent konfiguruje, monitoruje, self-heal-uje
4. **Mesh ready** — jedna inštancia je fajn, ale v jednote je sila. CloudOS spája viacero zariadení do distribuovaného cloudu

### Moduly

| Modul | Služba | Status |
|-------|--------|--------|
| `base` | Netdata + cAdvisor + Watchtower | ✅ Hotovo |
| `auth` | Authentik + Caddy + OIDC | ✅ Hotovo |
| `filesync` | Nextcloud + OnlyOffice | ✅ Hotovo |
| `search` | SearXNG + Meilisearch | ✅ Hotovo |
| `dashboard` | Homer unified dashboard | ✅ Hotovo |
| `ai` | Ollama + Open WebUI + Hermes supervisor | ✅ Hotovo |
| `photos` | Immich + AI tagging | 🔧 Chystá sa |
| `media` | Jellyfin + Navidrome | 🔧 Chystá sa |
| `mail` | Mailcow / Maddy | 🔧 Chystá sa |

### Použitie

```bash
# Detekcia prostredia
cloudos init

# Pridanie modulu
cloudos module add auth
cloudos module add filesync

# Spustenie všetkého
cloudos up

# Status celej inštancie
cloudos status

# Pridanie nodu do mesh clusteru
cloudos cluster join --invite <hash>
```

## Licence

MIT
