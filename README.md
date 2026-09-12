*This project has been created as part of the 42 curriculum by luiz-dos.*

# Inception

## Description

Inception is a system administration project focused on Docker. The goal is to build a small,
self-contained web infrastructure entirely from custom Docker images (no pre-built images from
Docker Hub, aside from the base OS layer), orchestrated with Docker Compose, and running inside
a personal virtual machine.

The stack is made of three services, each running in its own dedicated container:

- **NGINX** — the single entrypoint of the whole infrastructure, reachable from outside only on
  port 443, speaking TLSv1.2/TLSv1.3 exclusively.
- **WordPress + php-fpm** — the web application itself, with no web server bundled in the
  container (NGINX is the only one talking to the outside world; WordPress is only reachable
  from NGINX over the internal Docker network, via FastCGI).
- **MariaDB** — the database backend used by WordPress, reachable only from the WordPress
  container over the internal network.

Persistent data (the database, and the WordPress site files) lives in two Docker named volumes,
bind-mounted to `/home/luiz-dos/data` on the host. All three containers communicate over a
dedicated Docker bridge network, and all credentials are handled through Docker secrets — never
hardcoded in a Dockerfile or committed to the repository.

## Instructions

### Prerequisites

- A Linux virtual machine with Docker and the Docker Compose plugin installed.
- `git`.

### Setup

This repository intentionally does **not** track credentials or environment-specific values —
they must be created locally before the first build, next to the `srcs/` folder:

```
inception/
├── Makefile
├── README.md
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    └── docker-compose.yml
```

1. Create the `secrets/` folder at the repository root, with one file per secret, containing
   only the plaintext value (no trailing key name, no quotes):
   - `db_password.txt` — password for the WordPress database user.
   - `db_root_password.txt` — password for the MariaDB `root` user.
   - `wp_admin_password.txt` — password for the WordPress administrator account.
   - `wp_user_password.txt` — password for the second (non-admin) WordPress account.
2. Create `srcs/.env` with the non-sensitive configuration:
   ```
   DOMAIN_NAME=luiz-dos.42.fr
   MYSQL_DATABASE=wordpress
   MYSQL_USER=wp_user
   WP_TITLE=Inception
   WP_ADMIN_USER=luiz-dos_owner
   WP_ADMIN_EMAIL=you@example.com
   WP_USER=your_second_user
   WP_USER_EMAIL=you2@example.com
   ```
   `WP_ADMIN_USER` must not contain `admin`/`administrator` in any casing.
3. Point your domain (`DOMAIN_NAME`) at the VM's local IP — on the VM itself, add it to
   `/etc/hosts` (`echo "127.0.0.1 luiz-dos.42.fr" | sudo tee -a /etc/hosts`); to reach the site
   from another machine, add an equivalent entry pointing to the VM's IP there instead.

### Build and run

```bash
make            # builds every image and starts the stack in the background
```

Other available targets:

| Target | What it does |
|---|---|
| `make build` | Builds the three images only. |
| `make up` / `make down` | Starts / stops and removes the containers. |
| `make stop` | Stops the containers without removing them. |
| `make clean` | Removes containers, network, and **only this project's** images and volumes. |
| `make fclean` | `clean` + wipes `/home/luiz-dos/data`. |
| `make nocache` | Rebuilds every image from scratch, ignoring the build cache. |
| `make re` | `fclean` + `nocache` + `up` — a full, cache-free reset. |

Once up, the site is reachable at `https://luiz-dos.42.fr/` (self-signed certificate — the
browser will warn about it, this is expected for a development/evaluation setup).

See `USER_DOC.md` for day-to-day usage and `DEV_DOC.md` for a deeper walkthrough of the setup
aimed at anyone who wants to modify the project.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI documentation](https://wp-cli.org/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- [NGINX documentation](https://nginx.org/en/docs/)
- [pid_namespaces(7) — Linux manual page](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)

### AI usage

AI (Claude) was used throughout this project as a learning and review tool. Concretely, it was
used to:

- Get explanations of Docker/Linux concepts encountered while building this project (named
  volumes vs. bind mounts, Docker secrets, PID 1 and signal handling inside a PID namespace, TLS
  configuration, PHP-FPM process management, systemd/init behavior and why it doesn't apply
  inside a container).
- Debug two real issues hit during development: a stale, pre-populated `/var/lib/mysql`
  baked into the MariaDB image by the Debian package's post-install script (which defeated the
  first-run detection in `init.sh`), and a missing `/run/mysqld` directory at container start
  (not created automatically the way it would be on a normal system).
- Review and compare design choices against a peer's implementation of the same project, to
  understand trade-offs (e.g. Alpine vs. Debian package behavior, certificate configuration,
  file permission handling).
- Draft and refine documentation (`USER_DOC.md`, `DEV_DOC.md`, this `README.md`).

## Project description

### Design choices

- Every image is built from `debian:bookworm-slim` (the penultimate stable Debian release),
  kept minimal with `--no-install-recommends`.
- Each container's entry script ends by `exec`-ing its main process (`mysqld`, `php-fpm8.2 -F`,
  `nginx -g "daemon off;"`), so that process becomes PID 1 and receives signals directly — no
  `tail -f`/`sleep infinity` keep-alive hacks.
- The WordPress image downloads WordPress core at **build time**, so a first-run container
  doesn't depend on network access to become usable, and so `wp core verify-checksums` has a
  known-good reference to check against on subsequent starts.
- Every entry script is idempotent: it detects whether its service was already initialized
  (MariaDB checks for existing system tables, WordPress checks `wp core is-installed` against
  the database) so that restarting a container never wipes or reinstalls existing data.

### Virtual Machines vs Docker

A virtual machine virtualizes an entire computer, including its own kernel, through a hypervisor
— each VM is a full, isolated OS, which makes it heavy to boot and to run in numbers. A Docker
container shares the host machine's kernel and isolates a process using Linux namespaces and
cgroups instead of full hardware virtualization, which makes it far lighter and faster to start.
This project actually uses both, at different levels: the whole project runs inside one VM (as
required by the subject), and inside that VM, Docker is used to run three lightweight, isolated
containers instead of three full VMs — getting isolation between services without the overhead
of virtualizing three separate operating systems.

### Secrets vs Environment Variables

An environment variable set on a container is visible through `docker inspect`, is inherited by
every child process spawned inside that container, and can end up in logs or core dumps. A
Docker secret is instead delivered as a read-only file inside `/run/secrets/<name>`, only inside
the containers that explicitly declare it, and never appears in `docker inspect`. In this
project, non-sensitive configuration (domain name, database name, usernames, emails) is passed
through `.env`/environment variables, while every password is passed exclusively through Docker
secrets, read inside each entry script with `cat /run/secrets/<name>`.

### Docker Network vs Host Network

`network: host` makes a container share the host's network namespace directly — it binds to the
host's real network interfaces, with no isolation and no way to control what a container can
reach. This project instead defines a dedicated Docker bridge network (`inception`); each
container gets its own network namespace, containers resolve each other by service name through
Docker's embedded DNS (e.g. `wordpress:9000`, `mariadb`), and only what is explicitly published
to the host — the NGINX container's port 443 — is reachable from outside. `mariadb` and
`wordpress` publish no ports at all; they only exist inside this internal network.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary path on the host directly into a container, chosen at mount time;
Docker itself doesn't manage or track it as a resource (it never shows up in `docker volume ls`).
A named volume is a storage object Docker manages and tracks by name, independent of the
container's lifecycle. This project uses named volumes (`mariadb_data`, `wordpress_data`),
configured with the `local` driver and `driver_opts: {type: none, o: bind, device: ...}` so that
they are, at the same time, genuine Docker-managed named volumes (visible via `docker volume ls`
and `docker volume inspect`) **and** physically stored at the required host path
(`/home/luiz-dos/data/mariadb`, `/home/luiz-dos/data/wordpress`), satisfying both the "must be a
named volume" and "must live under `/home/login/data`" requirements at once.
