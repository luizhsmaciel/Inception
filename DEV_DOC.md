# Developer Documentation

This document describes how to set up, build, and work on the Inception project as a developer.
For instructions on simply using the already-running site, see `USER_DOC.md`.

## Repository layout

```
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                       (not tracked by git, created locally, see below)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                       (not tracked by git, created locally, see below)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf
        │   └── tools/init.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/init.sh
        └── nginx/
            ├── Dockerfile
            ├── conf/nginx.conf.template
            └── tools/init.sh
```

## Setting up the environment from scratch

### Prerequisites

- A Linux virtual machine with Docker Engine and the Docker Compose plugin installed.
- `git`, `make`.

### Configuration files (not in Git)

`secrets/` and `srcs/.env` are excluded via `.gitignore` on purpose, since the subject requires
that no credential ever reaches the repository. They must be created manually on any machine
this project is checked out on.

1. **`secrets/`**, one file per secret, at the repository root, containing only the plaintext
   value:
   - `db_password.txt`
   - `db_root_password.txt`
   - `wp_admin_password.txt`
   - `wp_user_password.txt`

2. **`srcs/.env`**, non-sensitive configuration, read by both the Makefile and
   `docker-compose.yml`:
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
   `WP_ADMIN_USER` must not contain `admin`/`administrator` (any casing).

3. **Domain resolution**: since `DOMAIN_NAME` isn't a real registered domain, point it at the VM
   locally: `echo "127.0.0.1 luiz-dos.42.fr" | sudo tee -a /etc/hosts`.

## Building and launching the project

| Command | Effect |
|---|---|
| `make` | Creates `/home/luiz-dos/data/{mariadb,wordpress}` if missing, builds all three images, starts the stack detached. |
| `make build` | Builds the images only, does not start anything. |
| `make up` | Starts the stack (images must already be built). |
| `make down` | Stops and removes the containers and the network. Volumes and host data are untouched. |
| `make stop` | Stops the containers without removing them. |
| `make clean` | `down` plus removes only this project's images and named volumes. |
| `make fclean` | `clean` plus wipes `/home/luiz-dos/data` on the host. |
| `make nocache` | Rebuilds every image with `--no-cache`. |
| `make re` | `fclean` + `nocache` + `up`, a complete reset. |

## Managing containers and volumes

```bash
docker compose -f srcs/docker-compose.yml ps                # list container status
docker compose -f srcs/docker-compose.yml logs -f <service>  # follow a service's logs
docker compose -f srcs/docker-compose.yml restart <service>  # restart one service in place
docker compose -f srcs/docker-compose.yml exec <service> sh  # shell into a running container
docker compose -f srcs/docker-compose.yml build <service>    # rebuild a single service

docker volume ls                                              # list volumes
docker volume inspect srcs_mariadb_data srcs_wordpress_data    # inspect this project's volumes
```

## Where project data is stored and how it persists

The database and the WordPress site files are stored in two Docker named volumes:

| Volume | Mounted in container at | Backed by, on the host |
|---|---|---|
| `mariadb_data` | `/var/lib/mysql` (mariadb) | `/home/luiz-dos/data/mariadb` |
| `wordpress_data` | `/var/www/html` (wordpress, and read-only in nginx) | `/home/luiz-dos/data/wordpress` |

They are declared with `driver: local` and `driver_opts: {type: none, o: bind, device: <path>}`
in `srcs/docker-compose.yml`, so that Docker manages them as real named volumes while their
actual data is physically stored at the required `/home/luiz-dos/data/...` path on the host:

```bash
ls -la /home/luiz-dos/data/mariadb /home/luiz-dos/data/wordpress
```

Removing a container (`make down`) never touches this data. Only `make fclean` does, since it
explicitly wipes the host directory as a separate step.
