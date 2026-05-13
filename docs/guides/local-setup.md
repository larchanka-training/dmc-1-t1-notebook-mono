# Local Setup Guide

## Why All This?

### Docker — consistent environment for the entire team

All services run in containers, which guarantees identical configuration for all developers and eliminates "it works on my machine" problems.

### Local domains (notebook.com and subdomains)

Used for:
- proper cookie handling (especially **SameSite**, secure cookies),
- correct OAuth / redirect-URL functionality,
- reverse-proxy setup via virtual hosts,
- production infrastructure emulation.

### HTTPS even locally

A self-signed certificate enables:
- secure cookies,
- service workers,
- APIs that require https,
- correct auth process functionality.

The browser will warn that the certificate is untrusted — this is normal for dev. Just click **Advanced → Continue anyway**.

---

## Setting Up Local Domains

To access `notebook.com`, `api.notebook.com`, and `pgadmin.notebook.com` locally, add these entries to your hosts file:

```
127.0.0.1 notebook.com
127.0.0.1 api.notebook.com
127.0.0.1 pgadmin.notebook.com
```

### How to edit `hosts`

**macOS / Linux:**

```
sudo nano /etc/hosts
```

**Windows:**

Open Notepad as Administrator → open file:
`C:\Windows\System32\drivers\etc\hosts`

After making changes, flush your DNS cache (e.g., `ipconfig /flushdns` on Windows).

---

## Running the Project Locally

**macOS / Linux:**

```bash
chmod +x start-services.sh
./start-services.sh
```

**Windows (PowerShell):**

```powershell
.\start-services.ps1
```

### Stopping Services

```
docker-compose down
```

---

## What `start-services.sh` Does

The script automates the entire startup process: bringing up Docker containers, launching the backend and frontend in dev mode, and preparing the environment.

1. **Stops execution on any error** — prevents incorrect startup.
2. **Runs docker-compose** — starts all services from `docker-compose.yml`: database, API container, frontend container, pgAdmin, proxy, etc.
3. **Waits** — gives containers time to fully start up.
4. **Launches the backend inside its container** — finds the API container, installs Python dependencies (`pip install`), starts FastAPI in development mode.
5. **Launches the frontend inside its container** — finds the frontend container, installs npm dependencies, starts the dev server.
6. **Displays a success message** — frontend and backend are ready to use.

---

## Available Addresses After Startup

| Service | URL |
|---------|-----|
| Frontend | [https://notebook.com](https://notebook.com/) |
| API | [https://api.notebook.com](https://api.notebook.com/) |
| pgAdmin | [https://pgadmin.notebook.com](https://pgadmin.notebook.com/) |

A certificate warning may appear on first access — this is expected.

---

## Self-Signed Certificate Warning

Your browser will show an untrusted connection message. Click **Advanced → Continue to site**.

This is typical for local development. If you want full dev-https without warnings, use `mkcert` to generate a trusted local certificate.

---

## Useful Commands

| Command | Description |
|---------|-------------|
| `docker ps` | View running containers |
| `docker compose logs -f` | Stream service logs |
| `docker compose down` | Stop all services |
| `docker compose up -d --build` | Rebuild and restart |

---

## Troubleshooting

### Site won't open

Check:
- your hosts file,
- that containers are running (`docker ps`),
- logs (`docker compose logs`).

### Port already in use

Find what's using it:
- macOS/Linux: `lsof -i :80` / `lsof -i :443`
- Windows: `netstat -a -b`

### Certificate warning

This is normal. Click **Continue**. To remove warnings, use `mkcert`.

### Frontend or backend didn't start

Check:
- that the container was found (name matches expected),
- that dependencies installed correctly.
