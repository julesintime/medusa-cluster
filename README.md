# Avada Portfolio WordPress Docker Setup

**Production-ready WordPress development environment with Docker, Cloudflare Tunnel, and global CDN caching.**

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url> avada-portfolio
   cd avada-portfolio
   ```

2. **Start the development environment:**
   ```bash
   docker compose up -d
   ```

3. **Access your services:**
   - WordPress: [http://localhost:38280](http://localhost:38280)
   - External (via Cloudflare): [https://wp.xuperson.net](https://wp.xuperson.net)

## Features

### ✅ Live Development & Customization
- All themes (`wp-content/themes`), plugins (`wp-content/plugins`), and uploads (`wp-content/uploads`) are stored locally and mounted into the container
- Edit, add, or remove themes and upload files directly in these folders — changes are reflected immediately in WordPress
- Custom PHP configuration (`wp-config/php.ini`) for large uploads and extended execution time

### ✅ Cloudflare Tunnel & Global CDN
- Secure external access via Cloudflare Tunnel (no port forwarding needed)
- Global CDN caching with `cf-cache-status: HIT` for optimal performance
- Free Cloudflare caching with "Cache Everything" rule for mostly-static content

### ✅ Cloudflare Setup & External Access
   - To make your site accessible externally (e.g. `wp.xuperson.net`), use [Cloudflared](https://developers.cloudflare.com/cloudflared/):
     1. Login to Cloudflare and create a tunnel:
        ```bash
        cloudflared tunnel login
        cloudflared tunnel create <TUNNEL-NAME>
        cloudflared tunnel route dns <TUNNEL-NAME> wp.xuperson.net
        cloudflared tunnel config > config.yml
        ```
     2. Copy your generated `cert.pem`, tunnel JSON, and `config.yml` into the `cloudflared/` folder in this repo.
     3. In your Cloudflare dashboard, add a CNAME record for `wp.xuperson.net` pointing to `<TUNNEL-UUID>.cfargotunnel.com` (see your tunnel config for the UUID).
     4. Start the stack:
        ```bash
        docker compose up -d
        ```
     5. Wait for DNS propagation, then access your site at `https://wp.xuperson.net`.
   - If you see DNS errors, double-check your Cloudflare DNS settings and tunnel config.

3. **Start all services:**
   ```bash
   docker-compose up -d
   ```

4. **Access your services:**
   - WordPress: [http://localhost:38280](http://localhost:38280)
   - phpMyAdmin: [http://localhost:38281](http://localhost:38281)
   - MailHog: [http://localhost:38125](http://localhost:38125)


## Folder Structure

- `wp-config/` — All WordPress, PHP, MySQL, and .htaccess configs
- `wp-content/themes/` — All themes, stored locally for live development
- `wp-content/uploads/` — All uploads/media, stored locally for persistence and customization
- `wp-content/plugins/` — Plugins (optional, can be mounted similarly)
- `cloudflared/` — Tunnel certs, config, and credentials

## Customization
- Edit `wp-config/wp-config.php` for main WordPress settings
- Develop your own theme in `wp-content/themes/` or upload files to `wp-content/uploads/` — changes are live and persistent
- All config and content files are mounted for instant effect

## Ports Used (Special to Avoid Conflicts)
- WordPress: `38280`
- phpMyAdmin: `38281`
- MailHog Web UI: `38125`
- MailHog SMTP: `31125`
- MySQL: `33806`

## Best Practices
- All credentials/configs are stored in local folders and mounted into containers
- No Makefile or fix-permissions script needed (handled by Docker user)
- `.gitignore` excludes sensitive and unnecessary files
- Ready for git clone and instant deployment

## Updating/Resetting
- All WordPress themes and uploads are mounted for live development. Customize directly in `wp-content/themes/` and `wp-content/uploads/`.
- To update configs, edit files in `wp-config/`.

## Security
- Always generate new security keys for `wp-config-custom.php` from [WordPress.org secret-key service](https://api.wordpress.org/secret-key/1.1/salt/)
- Never commit real credentials or certs to public repos

---

## Troubleshooting

- **Themes/uploads not saving?**
  - Make sure `wp-content/themes` and `wp-content/uploads` exist and are writable on your host.
  - Docker Compose mounts these folders for persistence and live editing.
- **External access not working?**
  - Check your Cloudflare DNS settings: CNAME for `wp.xuperson.net` must point to your tunnel UUID (e.g. `9caa21c6-c522-4e4e-aa7c-be14197b081f.cfargotunnel.com`).
  - Confirm your tunnel config (`cloudflared/config.yml`) matches your Cloudflare dashboard.
  - Wait for DNS propagation after changes.

---

**Clone, configure, and run — your WordPress dev stack is ready for local development and secure external access!**

---

**Clone, configure, and run — your WordPress dev stack is ready!**
