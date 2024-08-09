---
date:
  created: 2024-08-05
  updated: 2024-08-09
# draft: true
---

# Deploying a CI/CD Infrastructure with Docker Compose

In this article, I will demonstrate how to deploy a CI/CD infrastructure using Docker Compose. It will require the following components:

- a database (postgres)
- a git server (gitea)
- a reverse proxy server (openresty)
- jenkins

## Create Two Docker Network Bridges

```bash
# For any app that needs to connect to PostgreSQL
docker network create --driver bridge postgres_network
# For the reverse proxy server to connect to the Gitea web service
docker network create --driver bridge gitea_network
# For jenkins/dind/openresty
docker network create --driver bridge jenkins
```

## Create Jenkins Named Volumes

```bash
# Data Volumes share data between dind, jekins, and openresty(jenkins's web static file)
docker volume create jenkins-data
docker volume create jenkins-docker-certs
```

## Start Postgres

Use the Docker Compose [File](../../Docker/ComposeFiles/postgres.yml) to start a PostgreSQL server, Besides the offical postgres image, Bitnami/PostgreSQL is also a good choice as it provides more flexable control over postgres.

## Config Gitea Database

```bash
# Replace 'giteaPassword' with a strong password
docker compose exec -it postgres psql -U postgres -c "CREATE ROLE gitea WITH LOGIN PASSWORD 'giteaPassword';"
docker compose exec -it postgres psql -U postgres -c "CREATE DATABASE giteadb WITH OWNER gitea TEMPLATE template0 ENCODING UTF8 LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';"
```

## Start Gitea

Use the Docker Compose [File](../../Docker/ComposeFiles/gitea.yml) to start up gitea server. Remember to replace `GITEA__database__PASSWD` and `SECRET_KEY` with strong values., the `HTTP_PORT` is irrelevant as we will only expose it on the internal `gitea_network`. To publish the Gitea service with a subpath like `/gitea`, configure `DOMAIN` and `ROOT_URL` accordingly.

<span id ="create_administrator_account">After Gitea starts, create an administrator account</span>

```bash
docker compose exec -it gitea su git -c "gitea admin user create --username <ADMIN> --password <AdminPassword> --email <AdminEmailAddress>"
```

## Jenkins

<https://www.jenkins.io/doc/book/installing/docker/>  
<https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-with-jenkins/reverse-proxy-configuration-nginx/>  
It's quite tricky here, in order to use OpenResty to reverse proxy Jenkins web interface to a sub directory, we must start jenkins with the argument `--prefix=/jenkins`. However the offical document does not mention this, and in fact, the official Jenkins image doesn't support changing the startup behavior through environment variables.  
Therefore, we have to use `docker image inspect jenkins/jenkins:lts-jdk21` to find that he `Entrypoint` is `/usr/bin/tini -- /usr/local/bin/jenkins.sh`. To achieve our goal, we'll need to overwrite it with `/usr/bin/tini -- /usr/local/bin/jenkins.sh --prefix=/jenkins` in the Docker Compose [File](../../Docker/ComposeFiles/jenkins.yml)

## Reverse Proxy Server

I'll use OpenResty as a reverse proxy server. It's like an Nginx server with many plugins, so I won't need to recompile Nginx for additional functionality.

First, create an Nginx configuration file. Similar to the official Nginx Docker image, the OpenResty Docker image allows users to customize the configuration file by overwriting `/etc/nginx/conf.d/default.conf` within the container. The main configuration file `/usr/local/openresty/nginx/conf/nginx.conf` has an entry `include conf.d/*.conf`. Here's my configuration file:

```conf
server_tokens off;
resolver 127.0.0.11 valid=30s;
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
'$status $body_bytes_sent "$http_referer" '
'"$http_user_agent" "$http_x_forwarded_for"';
tcp_nopush on;
tcp_nodelay on;
types_hash_max_size 4096;
client_max_body_size 1024M;
server {
    listen your_http_port;
    server_name _;
    charset utf-8;
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log info;
    # pass through headers from Jenkins that Nginx considers invalid
    ignore_invalid_headers off;

    add_header X-Frame-Options SAMEORIGIN;

    location / {
        root /usr/local/openresty/nginx/html;
        index index.html index.htm;
    }
    include /etc/nginx/default.d/*.conf;
}
```

In the configuation above, we utilize `include /etc/nginx/default.d/*.conf;` directive within the `server` block to modularize location configuration for each application. This approach enhances configuration management by separating concerns and promoting better organization.

```conf
# gitea location
location ~ ^/(gitea|v2)($|/) {
   access_log /var/log/nginx/gitea.log main;
   error_log /var/log/nginx/gitea.log info;
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
```

```conf
# jenkins location
location ~ "^/jenkins/static/[0-9a-fA-F]{8}\/(.*)$" {
    rewrite "^/jenkins/static/[0-9a-fA-F]{8}/(.*)" /jenkins/$1 last;
}
location /jenkins/userContent {
    root /var/jenkins_home/userContent;
    if (!-f $request_filename) {
        rewrite (.*) /$1 last;
        break;
    }
}
location /jenkins/ {
    access_log /var/log/nginx/jenkins.log main;
    error_log /var/log/nginx/jenkins.log info;
    proxy_pass http://jenkins-blueocean:8080/jenkins/;
    proxy_redirect default;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_max_temp_file_size 0;
    client_max_body_size 10m;
    client_body_buffer_size 128k;
    proxy_connect_timeout 90;
    proxy_send_timeout 90;
    proxy_read_timeout 90;
    proxy_request_buffering off; # Required for HTTP CLI commands
    root /var/jenkins_home/war/;
}
```

To serve Jenkins' static web content using OpenResty, we must mount the Jenkins data volume: ``jenkins-data` into the OpenResty container. Subsequently, the OpenResty configuration should be adjusted to set the `root` directive within the relevant location block to `/var/jenkins_home/war/`. This ensures that OpenResty correctly locates and serves the necessary static files.

Then, start the OpenResty server using the Compose [file](../../Docker/ComposeFiles/openresty.yml). After that, we can access the gitea server using the [accout](#create_administrator_account) we created
