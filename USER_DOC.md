# User Documentation

This document explains how to use the Inception stack as an end user or administrator, no
Docker or development knowledge required. If you want to understand how the project is built or
modify it, see `DEV_DOC.md` instead.

## What this stack provides

Three services work together to serve a single WordPress website over HTTPS:

| Service | Role |
|---|---|
| **nginx** | The only thing reachable from outside, serves the site over HTTPS (port 443). |
| **wordpress** | Runs the WordPress application itself (not reachable from outside directly). |
| **mariadb** | Stores the website's data: posts, pages, users, settings (not reachable from outside directly). |

You only ever interact with the site through your browser, at the project's domain. You never
need to talk to `wordpress` or `mariadb` directly.

## Starting and stopping the project

From the repository root, on the machine where the project is set up:

```bash
make        # builds (if needed) and starts all three services
```

To check whether everything is running:

```bash
docker compose -f srcs/docker-compose.yml ps
```

You should see `mariadb`, `wordpress`, and `nginx`, all with a status of `Up`.

To stop the project without deleting anything (containers can be started again with their data
intact):

```bash
make stop
```

To stop and remove the containers (site data is untouched, it lives outside the containers):

```bash
make down
```

To start again after either of the above:

```bash
make up
```

## Accessing the website and the admin panel

- **The website**: open `https://<domain-name>/` in a browser (the domain is whatever was
  configured as `DOMAIN_NAME` when the project was set up, for this project,
  `https://luiz-dos.42.fr/`).
- **The admin panel**: go to `https://<domain-name>/wp-admin/` and log in.

Because the site uses a self-signed TLS certificate (not issued by a public certificate
authority), your browser will show a warning like "Your connection is not private" the first
time you visit. This is expected for this kind of setup, the connection is still encrypted,
there's simply no external authority vouching for the certificate. You can safely proceed past
the warning (in Chrome: "Advanced" → "Proceed to ... (unsafe)"; in Firefox: "Advanced" →
"Accept the Risk and Continue").

There are two accounts:

- An **administrator** account (`WP_ADMIN_USER`), with full access: plugins, themes, settings,
  managing other users.
- A **regular (author)** account (`WP_USER`), which can write and manage its own posts, but has
  no access to site-wide settings, plugins, or other users.

## Locating and managing credentials

Passwords are never stored inside the running containers' images, nor written anywhere in the
Git repository. They live in plain text files on the host machine, next to the project:

```
secrets/
├── db_password.txt          # WordPress database user's password
├── db_root_password.txt     # MariaDB root password
├── wp_admin_password.txt    # WordPress administrator's password
└── wp_user_password.txt     # WordPress regular user's password
```

The corresponding usernames (`WP_ADMIN_USER`, `WP_USER`, `MYSQL_USER`, ...) and the domain name
are stored in `srcs/.env`, also outside of Git.

To change a password: edit the relevant `secrets/*.txt` file with the new value, then restart
the affected service (`docker compose -f srcs/docker-compose.yml restart wordpress` for
WordPress account passwords, for example). Note that this only updates the secret the container
receives; the WordPress/MariaDB accounts themselves keep whatever password was set when they
were created, changing the file alone does not retroactively change an already-created account's
password. To actually change an existing account's password, do it from the WordPress admin
panel (Users → your profile → "New Password") or via a database tool, and update the secret file
to match, for your own records.

## Checking that everything is running correctly

1. **Containers are up:**
   ```bash
   docker compose -f srcs/docker-compose.yml ps
   ```
   All three should show `Up`, none should show `Restarting` in a loop.

2. **The site responds:**
   ```bash
   curl -k -o /dev/null -s -w "%{http_code}\n" https://<domain-name>/
   ```
   Should print `200`.

3. **Logs look clean:**
   ```bash
   docker compose -f srcs/docker-compose.yml logs mariadb
   docker compose -f srcs/docker-compose.yml logs wordpress
   docker compose -f srcs/docker-compose.yml logs nginx
   ```
   No `[error]`/`[Warning]`-level messages related to startup failing; the `wordpress` log should
   end with either a successful install message (first start) or a checksum verification message
   (subsequent starts).

4. **A service crashed and came back on its own:** if a container's `STATUS` column ever briefly
   shows something other than `Up` and then recovers by itself, that is the expected behavior.
   Every service is configured to restart automatically if it crashes, without needing anyone to
   intervene.
