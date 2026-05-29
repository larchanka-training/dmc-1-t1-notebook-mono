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

### Step 0. Prepare .env

```bash
cp .env.example .env
```

Open `.env` and replace all values marked `[REQUIRED]`.

```bash
docker compose up
```

### Stopping Services

```
docker compose down
```

---

## How `docker compose up` Handles Everything

You don't need to manually install dependencies or start dev servers — it's all wired into the Docker configuration.

**API** (`api/Dockerfile`):
- Dependencies are installed during image build: `pip install -r requirements.txt`
- `docker-compose.yaml` overrides the default command to run FastAPI in dev mode with hot-reload:
  ```
  fastapi dev app/main.py --host 0.0.0.0 --port 8000
  ```
- Source code is mounted as a volume (`./api:/app`), so local file changes are reflected immediately without rebuilding.

**Frontend** (`docker-compose.yaml`, `command:`):
- The compose file uses the `builder` stage of `ui/Dockerfile` and sets the startup command to:
  ```
  npm ci --prefer-offline && npm run dev -- --host
  ```
- Node modules are stored in a named Docker volume (`ui-node-modules`) so they persist between restarts.
- Source code is mounted as a volume (`./ui:/home/app`), enabling hot-reload via Vite.

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
