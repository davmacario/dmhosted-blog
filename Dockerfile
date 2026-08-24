FROM caddy:2-alpine

ENV XDG_CONFIG_HOME=/tmp/caddy-config \
    XDG_DATA_HOME=/tmp/caddy-data

COPY Caddyfile /etc/caddy/Caddyfile
COPY public/   /srv/

USER 1000:1000

EXPOSE 8080
