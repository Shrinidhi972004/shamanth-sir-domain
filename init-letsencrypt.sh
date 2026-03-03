#!/bin/bash
# ============================================================
# init-letsencrypt.sh
# First-time SSL certificate setup for dr-shamantha-rai.tech
# ============================================================

set -e

DOMAIN="dr-shamantha-rai.tech"
EMAIL="shetty.ashil003@gmail.com"  # <-- Change this to your real email
STAGING=0  # Set to 1 to test against staging environment (avoids rate limits)

DATA_PATH="./certbot"

if [ -d "$DATA_PATH/conf/live/$DOMAIN" ]; then
  echo "Certificates already exist. Skipping..."
  exit 0
fi

echo "### Creating directories..."
mkdir -p "$DATA_PATH/conf" "$DATA_PATH/www"

echo "### Downloading recommended TLS parameters..."
mkdir -p "$DATA_PATH/conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$DATA_PATH/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$DATA_PATH/conf/ssl-dhparams.pem"

echo "### Creating dummy certificate for $DOMAIN..."
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
mkdir -p "$DATA_PATH/conf/live/$DOMAIN"
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
    -keyout '$CERT_PATH/privkey.pem' \
    -out '$CERT_PATH/fullchain.pem' \
    -subj '/CN=localhost'" certbot

echo "### Starting nginx..."
docker compose up -d web

echo "### Deleting dummy certificate..."
docker compose run --rm --entrypoint "\
  rm -rf /etc/letsencrypt/live/$DOMAIN && \
  rm -rf /etc/letsencrypt/archive/$DOMAIN && \
  rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf" certbot

echo "### Requesting real certificate from Let's Encrypt..."

# Select staging or production
if [ $STAGING != "0" ]; then
  STAGING_ARG="--staging"
else
  STAGING_ARG=""
fi

docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $STAGING_ARG \
    --email $EMAIL \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --rsa-key-size 4096 \
    --agree-tos \
    --no-eff-email \
    --force-renewal" certbot

echo "### Reloading nginx..."
docker compose exec web nginx -s reload

echo ""
echo "=== SSL setup complete for $DOMAIN ==="
echo "Your site is now available at https://$DOMAIN"
