# Installing Vaultwarden via Docker

## 1. Install Docker

Install Docker on your system first.

## 2. Pull Docker Images

- vaultwarden/server:1.33.2
- openresty/openresty:bookworm

```bash
mkdir -p /home/vaultwarden /home/openresty/{ssl,conf.d}
```

## 3. Vaultwarden Setup

### Create a dedicated Vaultwarden network to avoid direct exposure

```bash
docker network create --driver bridge vaultwarden_network
```

### Create the Vaultwarden startup file at /home/vaultwarden/compose.yml

```yml
services:
  vaultwarden:
    image: vaultwarden/server:1.33.2
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      TZ: Asia/Shanghai
      ENABLE_WEBSOCKET: false
      # SIGNUPS_ALLOWED: false # Disable new user registration
      SIGNUPS_ALLOWED: true # Allow new user registration
      # ADMIN_TOKEN: Argon2 PHC hashed password for /admin access
      # Generate using: echo -n "YourPassword" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
      # Or use: docker run --rm -it vaultwarden/server /vaultwarden hash
      ADMIN_TOKEN: xxx
    volumes:
      - ./vw-data:/data
    networks:
      - vaultwarden_network
networks:
  vaultwarden_network:
    external: true
```

### Start Vaultwarden

```bash
cd /home/vaultwarden
docker compose up -d
```

## 4. Generate an SSL Certificate

```bash
cd /home/openresty/ssl
# Generate private key
openssl ecparam -name prime256v1 -genkey -noout -out key.pem
# Create certificate signing request
openssl req -new -key key.pem -out server.csr \
    -subj "/CN=localhost"
# Generate self-signed certificate
openssl x509 -req -in server.csr -signkey key.pem -out cert.pem -days 3650
```

## 5. OpenResty Setup

### Configure /home/openresty/nginx.conf

```conf
pcre_jit on;
worker_processes auto;
events {
    worker_connections 1024;
}
http {
    log_format main '$remote_addr - $remote_user [$time_iso8601] "$request" '
    '$status $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"'
    '"$request_time" "$upstream_response_time"';
    open_log_file_cache max=1024 inactive=1m valid=5m min_uses=2;
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log debug;
    underscores_in_headers off;
    include mime.types;
    default_type application/octet-stream;
    client_body_temp_path /var/run/openresty/nginx-client-body;
    proxy_temp_path /var/run/openresty/nginx-proxy;
    fastcgi_temp_path /var/run/openresty/nginx-fastcgi;
    uwsgi_temp_path /var/run/openresty/nginx-uwsgi;
    scgi_temp_path /var/run/openresty/nginx-scgi;
    sendfile on;
    keepalive_timeout 65;
    server_tokens off;
    resolver 127.0.0.11 valid=30s;
    types_hash_max_size 4096;
    client_max_body_size 1024M;
    client_body_timeout 1m;
    proxy_connect_timeout 1m;
    proxy_read_timeout 10m;
    proxy_send_timeout 10m;
    include /etc/nginx/conf.d/*.conf;
}
```

### Configure /home/openresty/conf.d/vaultwarden.conf

```conf
upstream vaultwarden-default {
    zone vaultwarden-default 64k;
    server vaultwarden:80;
    keepalive 2;
}
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' "";
}
server {
    listen 80;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    http2 on;
    server_name _;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1h;
    client_max_body_size 525M;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 777;
    proxy_send_timeout 777;
    proxy_read_timeout 777;
    send_timeout 777;
    location / {
      proxy_pass http://vaultwarden-default;
    }
}
```

### Configure /home/openresty/compose.yml

```yml
services:
  openresty:
    image: openresty/openresty:bookworm
    container_name: openresty
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d/:ro
      - ./default.d/:/etc/nginx/default.d/:ro
      - ./log:/var/log/nginx/:rw
      - ./ssl:/etc/nginx/ssl/:ro
      - ./socks:/var/run/socks
    networks:
      - vaultwarden_network
networks:
  vaultwarden_network:
    external: true
    driver: bridge
```

### Start OpenResty

```bash
cd /home/openresty
docker compose up -d
```

## 6. Access Vaultwarden

- User interface: <https://ip/>
- Admin panel: <https://ip/admin>, password: `Password used to generated ADMIN_TOKEN`

## 7. Toggle New User Registration

To enable/disable new user registration:
1. Modify `/home/vaultwarden/compose.yml`: toggle the `SIGNUPS_ALLOWED` value
2. Restart Vaultwarden: `docker compose restart`

Users can be managed through the admin interface.

## 8. Browser Setup

Install the Bitwarden browser extension to start using Vaultwarden.
