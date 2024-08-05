---
date:
  created: 2024-08-05
# draft: true
---

# Deploying a CI/CD Infrastructure with Docker Compose

In this article, I will demonstrate how to deploy a CI/CD infrastructure using Docker Compose. It will require the following components:

- a database (postgres)
- a git server (gitea)
- a reverse proxy server (openresty)
- jekins(not finished)

1. Create Two Docker Network Bridges

   ```shell
   # For any app that needs to connect to PostgreSQL
   docker network create --driver bridge postgres_network
   # For the reverse proxy server to connect to the Gitea web service
   docker network create --driver bridge gitea_network
   ```

2. Start Postgres

   Use the Docker Compose [file](../../Docker/ComposeFiles/postgres.yml) to start a PostgreSQL server, Besides the offical postgres image, Bitnami/PostgreSQL is also a good choice as it provides more flexable control over postgres.

3. Config Gitea Database

   ```bash
   # Replace 'giteaPassword' with a strong password
   docker compose exec -it postgres psql -U postgres -c "CREATE ROLE gitea WITH LOGIN PASSWORD 'giteaPassword';"
   docker compose exec -it postgres psql -U postgres -c "CREATE DATABASE giteadb WITH OWNER gitea TEMPLATE template0 ENCODING UTF8 LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';"
   ```

4. Start Gitea

   Use the Docker Compose [file](../../Docker/ComposeFiles/gitea.yml) to start up gitea server. Remember to replace `GITEA__database__PASSWD` and `SECRET_KEY` with strong values., the `HTTP_PORT` is irrelevant as we will only expose it on the internal `gitea_network`. To publish the Gitea service with a subpath like `/gitea`, configure `DOMAIN` and `ROOT_URL` accordingly.

   <span id ="create_administrator_account">After Gitea starts, create an administrator account</span>

   ```bash
   docker compose exec -it gitea su git -c "gitea admin user create --username <ADMIN> --password <AdminPassword> --email <AdminEmailAddress>"
   ```

5. Reverse Proxy Server

   I'll use OpenResty as a reverse proxy server. It's like an Nginx server with many plugins, so I won't need to recompile Nginx for additional functionality.

   First, create an Nginx configuration file. Similar to the official Nginx Docker image, the OpenResty Docker image allows users to customize the configuration file by overwriting `/etc/nginx/conf.d/default.conf` within the container. The main configuration file `/usr/local/openresty/nginx/conf/nginx.conf` has an entry `include conf.d/*.conf`. Here's my configuration file:

   ```conf
   # The default Docker DNS resolver, required for Nginx to resolve Gitea container IP
   resolver 127.0.0.11 valid=30s;
   access_log /var/log/nginx/access.log ;
   error_log /var/log/nginx/error.log ;
   server {
    listen 443;
    server_name _;
    charset utf-8;
    # gitea service will also need a 'v2' sub path
    location ~ ^/(gitea|v2)($|/) {
        client_max_body_size 512M;
        rewrite ^ $request_uri;
        rewrite ^(/gitea)?(/.*) $2 break;
        proxy_pass http://gitea:3000$uri;
        proxy_set_header Connection $http_connection;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
   }
   ```

   Then, start the OpenResty server using the Compose [file](../../Docker/ComposeFiles/openresty.yml). After that, we can access the gitea server using the [accout](#create_administrator_account) we created

6. Jenkins
   ...
