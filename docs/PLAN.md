# CloudOS — Stav a Rozvojový Plán (v0.1.0)

Dátum: 2026-07-02
Analyzované: GitHub repo, lokálny Windows klient, Ubuntu deployment, session história, Hermes skill

---

## I. SÚČASNÝ STAV

### Na Ubuntu nodi (100.79.173.91) — deployed 2026-07-01
| Čo | Stav |
|----|------|
| CloudOS CLI + profiles | ✅ |
| base (netdata:9001, cAdvisor:8082, watchtower) | ✅ |
| auth (Authentik + Caddy + PostgreSQL + Redis) | ✅ |
| filesync (Nextcloud:8081 + OnlyOffice + PostgreSQL) | ✅ |
| search (SearXNG:4000 + Meilisearch:7700) | ✅ |
| dashboard (Homer:8080) | ✅ |
| Syncthing mesh (Ubuntu ↔ Windows) | ✅ |
| OIDC (Authentik → Nextcloud) | ⚠️ funkčné, chýba login button |
| 15 Docker kontajnerov | ✅ |

### Na tomto Windows NTB (giganigga, 100.77.7.48)
| Čo | Stav |
|----|------|
| cloudos init — detekcia prostredia | ✅ — 31GB RAM, Tailscale detected |
| Git repo v sync s GitHub | ✅ |
| Docker Desktop v28.0.1 | ⚠️ nainštalovaný, **nie je spustený** |
| cloudos up | ❌ zlyhá — Docker nie je running |

### Moduly: realita vs README
| Modul | Docker-compose | Setup | Poznámka |
|-------|---------------|-------|----------|
| base | ✅ | ✅ hotový | netdata, cAdvisor, watchtower, alpine healthcheck |
| auth | ✅ | ✅ hotový | Authentik, Caddy, PostgreSQL, Redis, OIDC setup |
| filesync | ✅ | ✅ hotový | Nextcloud, OnlyOffice, PostgreSQL, Redis |
| search | ✅ | ✅ hotový | SearXNG, Meilisearch |
| dashboard | ✅ | ✅ hotový | Homer s auto-discovery |
| ai | ✅ | ✅ hotový | Ollama, Open WebUI, Hermes supervisor (8GB+ RAM) |
| photos | ❌ | ❌ **stub only** | Iba module.yml, chýba compose aj setup |
| media | ❌ | ❌ **neexistuje** | Len v README / help |
| mail | ❌ | ❌ **neexistuje** | Len v README / help |

---

## II. PROBLÉMY A TECHNICKÝ DLH

### 🔴 Kritické
1. **Docker Desktop nie je spustený na Windows** — `cloudos up` padá na `detect_docker`
2. **Disk detection broken na Windows** — `cloudos.yml` má `disk: "Files/Git 459G C:/Program"`
3. **README uvádza moduly ako "Planned"** — ale 6/7 sú už hotové a otestované

### 🟡 Dôležité
4. **OIDC login button nefunguje** — Nextcloud 33 + user_oidc 8.10.1 incompatible
5. **`cloudos join` chýba** — zero-touch setup nového zariadenia
6. **Žiadne issue tracking** — GitHub repo má 0 issues, 0 milestones
7. **Žiadne CI/CD** — nikto nekontroluje syntax bash/compose

### 🟢 Kozmetické
8. **profiles.yml používa flat YAML namiesto štandardného**
9. **Legacy setup cesty** (root-level `auth/`, `filesync/` dirs) — duplicita s `modules/auth/`

---

## III. ROZVOJOVÝ PLÁN (Fázy)

### 🔵 Fáza A — Opravy technického dlhu (tento týždeň)

#### A1 — Fix disk detection na Windows
V `lib/detect.sh` opraviť `get_disk_info()`:
```bash
# Na Windows v git-bash:
df -h /c/ | awk 'NR==2 {print $2, $4, $1}'
# Alebo:
wmic logicaldisk get size,freespace,caption
```

#### A2 — Opraviť README statusy
Všetky moduly skutočne hotové označiť ako ✅ nie 🔧 Planned

#### A3 — Opraviť profiles.yml na štandardný YAML formát
```yaml
profiles:
  mini:
    description: "Minimal setup — RPi Zero 2 / low-power device"
    ram: 1
    modules: [base]
```

---

### 🟣 Fáza B — Chýbajúce moduly (tento mesiac)

#### B1 — photos (Immich)
- docker-compose.yml: Immich server + microservices + ML + PostgreSQL + Redis
- Immich je komplexný (~10 service-ov) — ML tagging, face detection
- setup.sh: .env generovanie, DB inicializácia
- Port: 2283
- requires: optimálne GPU pre ML

#### B2 — media (Jellyfin + Navidrome)
- Jellyfin: filmy/seriály :8096
- Navidrome: hudba :4533
- setup.sh: volumes pre médiá
- depends: auth (OIDC pre Jellyfin)
- Porty: 8096, 4533

#### B3 — mail (Mailcow)
- Mailcow: nginx, postfix, dovecot, rspamd, mysql, etc.
- Alternatíva: Maddy (lightweight, single binary)
- Vyžaduje port 25 (mnoho ISP blokuje) + DNS MX záznamy + reverzný DNS
- Porty: 25, 587, 993, 443

---

### 🟠 Fáza C — Nové funkcie (1-2 mesiace)

#### C1 — `cloudos join` — zero-touch nové zariadenie
```bash
cloudos join --server=100.79.173.91 --email=admin@cloudos.local
```
Komponenty:
- `lib/join.sh` — join orchestracia
- Authentik API token získanie
- Stiahnutie profilu z Ubuntu nodu
- Auto-deployment modulov
- Pridanie do Syncthing mesh + Tailscale

#### C2 — `cloudos cluster` — multi-node orchestracia
```bash
cloudos cluster status   # zoznam všetkých nodov
cloudos cluster invite   # vygeneruje invite pre iný node
cloudos cluster sync     # sync config medzi nodmi
```
Distribuované úložisko: Garage (S3-compatible) namiesto Syncthing
- Garage = distributed object storage (Rust, lightweight)
- Každý node má replica dát
- Prístup cez S3 API
- Alternatíva: Syncthing je fajn, ale nie je to distributed storage

#### C3 — `cloudos supervisor` — AI správca systému
- Hermes cron job pre health monitoring
- Self-heal (reštart padnutých service-ov)
- Automatické aktualizácie (watchtower už je)
- Alerting cez ntfy / Telegram
- Resource usage analytics

---

### 🔴 Fáza D — Budúcnosť

#### D1 — CI/CD pipeline
- GitHub Actions: bash syntax check, YAML lint, docker-compose validate
- Release tagging (v0.2.0, v0.3.0...)
- Docker image build pre custom service-y

#### D2 — GitHub Issues ako product management
- Milestone-y: v0.2.0 (moduly), v0.3.0 (join), v1.0.0 (stable)
- Label-y: module/photos, module/media, infra, docs, bug
- Issue: feature request / bug report templates

#### D3 — Web admin UI
- Lightweight admin panel (nie Homer)
- Zoznam nodov, modulov, status
- One-click pridanie / odobratie modulu
- Log viewer

#### D4 — Hermes skill upgrade
- skills: monitoring, troubleshooting, backup
- Rozšíriť `cloudos-deployment` skill

---

## IV. PRIORITY PODĽA HODNOTY / NÁROČNOSTI

| # | Čo | Hodnota | Náročnosť | Závisí na |
|---|----|---------|-----------|-----------|
| 1 | Docker Desktop autostart na Win | 🔥 nutné | ⭐ | — |
| 2 | Fix disk detection | nízka | ⭐ | — |
| 3 | Opraviť README | nízka | ⭐ | — |
| 4 | Photos (Immich) modul | 🔥 vysoká | ⭐⭐⭐⭐ | auth |
| 5 | `cloudos join` | 🔥 vysoká | ⭐⭐⭐⭐ | auth API |
| 6 | Media (Jellyfin + Navidrome) | stredná | ⭐⭐ | auth |
| 7 | Mail (Mailcow/Maddy) | nízka | ⭐⭐⭐⭐⭐ | DNS, port 25 |
| 8 | `cloudos cluster` | stredná | ⭐⭐⭐⭐⭐ | join |
| 9 | `cloudos supervisor` | stredná | ⭐⭐⭐ | ai modul |
| 10 | CI/CD | nízka | ⭐⭐ | — |

---

## V. TESTOVACIA SÉRIA NA TOMTO WINDOWS NTB

### Test 1 — `cloudos init` ✅
```bash
bash cloudos init
# Výsledok: win, 31GB RAM, Tailscale 100.77.7.48, Docker not running
```

### Test 2 — `cloudos version` ✅
```bash
bash cloudos version
# Výsledok: CloudOS v0.1.0
```

### Test 3 — `cloudos module list` ✅
```bash
bash cloudos module list
# Výsledok: 7 modulov (6 installed, photos: not installed)
```

### Test 4 — `cloudos profile list` ✅
```bash
bash cloudos profile list
# Výsledok: 5 profilov (mini, household, power, pro, mesh)
```

### Test 5 — `cloudos status` ✅ (bez Dockeru)
```bash
bash cloudos status
# Výsledok: Docker not running (korektné)
```

### Test 6 — `cloudos up` ❌ (bez Dockeru)
```bash
bash cloudos up
# Zlyhá: "Docker is not running"
# Riešenie: spustiť Docker Desktop
```

---

## VI. OTVORENÉ ROZHODNUTIA

| Otázka | Opcie |
|--------|-------|
| Windows architektúra | Docker Desktop na Win vs všetko na Ubuntu + SSH client |
| Photo manažér | Immich (výkonný) vs Photoprism (stabilný) |
| Mesh storage | Garage (distribuované S3) vs Syncthing (file sync) |
| Mail stack | Mailcow (full stack) vs Maddy (lightweight) |
