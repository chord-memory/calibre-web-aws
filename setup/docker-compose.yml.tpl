services:
  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - 80:80
      - 443:443
    volumes:
      - /srv/cweb-setup/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - calibre-web
      - flask
    restart: unless-stopped

  calibre-web:
    image: ${docker_image}
    container_name: calibre-web
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Chicago
      - HARDCOVER_TOKEN=${hardcover_token}
    volumes:
      - /srv/config:/config
      - /srv/ingest:/cwa-book-ingest
      - /srv/library:/calibre-library
    ports:
      - 8083:8083
    restart: unless-stopped

  flask:
    container_name: flask
    build: /srv/cweb-setup/api
    ports:
      - 5000:5000
    environment:
      - FLASK_DEBUG=0
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config: