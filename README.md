# Dr. Shamantha Rai — Portfolio Website

> Academic portfolio deployed via Docker + Nginx with HTTPS on **dr-shamantha-rai.tech**

---

## Architecture

```
Client (Browser)
       │
       ▼
┌──────────────┐
│   Nginx      │  ← Ports 80 & 443
│  (Alpine)    │  ← Serves static files
│              │  ← SSL termination
└──────┬───────┘
       │
┌──────┴───────┐
│   Certbot    │  ← Auto-renews SSL certs every 12h
│  (Let's      │
│   Encrypt)   │
└──────────────┘
```

---

## Prerequisites

- **AWS EC2 Instance** — Ubuntu 22.04 / 24.04 LTS (t2.micro or higher)
- **Domain** — `dr-shamantha-rai.tech` with DNS configured
- **Security Group** — Ports 22, 80, 443 open

---

## Step-by-Step Deployment on AWS Ubuntu

### 1. Launch EC2 Instance

1. Go to **AWS Console → EC2 → Launch Instance**
2. Choose **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type**
3. Instance type: **t2.micro** (free tier) or higher
4. Configure Security Group with these inbound rules:

   | Type  | Port | Source    | Purpose       |
   |-------|------|-----------|---------------|
   | SSH   | 22   | Your IP   | SSH access    |
   | HTTP  | 80   | 0.0.0.0/0 | HTTP redirect |
   | HTTPS | 443  | 0.0.0.0/0 | HTTPS traffic |

5. Launch and download your `.pem` key pair

### 2. Connect to Your Instance

```bash
# Set permissions on your key
chmod 400 your-key.pem

# SSH into the instance
ssh -i your-key.pem ubuntu@<YOUR_EC2_PUBLIC_IP>
```

### 3. Install Docker & Docker Compose

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group (avoids needing sudo for docker commands)
sudo usermod -aG docker $USER

# Apply group change (or log out and back in)
newgrp docker

# Verify installation
docker --version
docker compose version
```

### 4. Configure DNS

Go to your domain registrar (where you bought `dr-shamantha-rai.tech`) and create these DNS records:

| Type | Host | Value              | TTL  |
|------|------|--------------------|------|
| A    | @    | `<EC2_PUBLIC_IP>`  | 300  |
| A    | www  | `<EC2_PUBLIC_IP>`  | 300  |

> **Important:** DNS propagation can take 5–30 minutes. Verify with:
> ```bash
> dig dr-shamantha-rai.tech +short
> dig www.dr-shamantha-rai.tech +short
> ```
> Both should return your EC2 public IP.

### 5. Upload Project Files to EC2

**Option A — From your local machine (SCP):**

```bash
# Run this from your LOCAL machine (not the EC2 instance)
scp -i your-key.pem -r /home/shrinidhi/Downloads/portfolio ubuntu@<YOUR_EC2_PUBLIC_IP>:~/
```

**Option B — Using Git (if you push to a repo first):**

```bash
# On EC2
sudo apt install -y git
git clone https://github.com/<your-username>/portfolio.git
cd portfolio
```

### 6. Edit Email for SSL Certificate

```bash
cd ~/portfolio
nano init-letsencrypt.sh
```

Change this line to your real email:
```bash
EMAIL="admin@dr-shamantha-rai.tech"  # ← Replace with your actual email
```

### 7. Obtain SSL Certificates (First Time Only)

```bash
# RECOMMENDED: Test with staging first to avoid rate limits
# Edit init-letsencrypt.sh and set STAGING=1, then run:
sudo ./init-letsencrypt.sh

# If staging succeeds, set STAGING=0 and run again:
sudo ./init-letsencrypt.sh
```

> **What this script does:**
> 1. Creates a temporary self-signed certificate
> 2. Starts Nginx so it can respond to Let's Encrypt's HTTP challenge
> 3. Requests a real certificate from Let's Encrypt
> 4. Reloads Nginx with the production certificate

### 8. Start the Application

```bash
docker compose up -d
```

Verify everything is running:
```bash
docker compose ps
```

Expected output:
```
NAME                          STATUS
dr-shamantha-rai-portfolio    Up
certbot                       Up
```

### 9. Verify Deployment

```bash
# Check HTTPS is working
curl -I https://dr-shamantha-rai.tech

# Expected: HTTP/2 200
```

Open in browser: **https://dr-shamantha-rai.tech**

---

## Project Structure

```
portfolio/
├── Dockerfile              # Nginx Alpine image with static site
├── docker-compose.yml      # Orchestrates Nginx + Certbot
├── init-letsencrypt.sh     # One-time SSL certificate setup
├── .dockerignore           # Files excluded from Docker build
├── nginx/
│   └── default.conf        # Nginx config (HTTPS, gzip, caching)
├── portfolio/
│   ├── index.html          # Main portfolio page
│   └── images/
│       ├── profile.jpg
│       ├── book1-cover.jpg
│       ├── book2-cover.jpg
│       ├── ieee-logo.png
│       ├── iiita-logo.png
│       ├── jpam-logo.png
│       ├── mystyle-logo.png
│       ├── pa-college-logo.png
│       ├── quantiphi-logo.png
│       ├── sahyadri-logo.png
│       ├── sahynex-logo.png
│       └── springer-logo.png
└── certbot/                # Created by init script (not in repo)
    ├── conf/               # SSL certificates
    └── www/                # ACME challenge files
```

---

## Common Operations

### Rebuild After Changes

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### View Logs

```bash
# All services
docker compose logs -f

# Nginx only
docker compose logs -f web

# Certbot only
docker compose logs -f certbot
```

### Manually Renew SSL Certificate

```bash
docker compose run --rm certbot renew
docker compose exec web nginx -s reload
```

> Certbot auto-renews every 12 hours, so manual renewal is rarely needed.

### Stop Everything

```bash
docker compose down
```

### Restart

```bash
docker compose restart
```

---

## Troubleshooting

### "Connection refused" on port 443

```bash
# Check if containers are running
docker compose ps

# Check Nginx logs for config errors
docker compose logs web

# Verify ports are open
sudo ufw status
sudo iptables -L -n | grep -E '80|443'
```

### SSL Certificate Issues

```bash
# Check certificate status
docker compose run --rm certbot certificates

# If rate-limited, wait 1 hour and try again, or use staging:
# Set STAGING=1 in init-letsencrypt.sh
```

### DNS Not Resolving

```bash
# Verify DNS records
dig dr-shamantha-rai.tech +short
nslookup dr-shamantha-rai.tech

# If no result, check your domain registrar's DNS settings
# DNS can take up to 48 hours to propagate globally
```

### Nginx Config Syntax Check

```bash
docker compose exec web nginx -t
```

### Disk Space Issues

```bash
# Clean unused Docker resources
docker system prune -a
```

---

## Elastic IP (Recommended)

By default, EC2 public IPs change on reboot. To keep a fixed IP:

1. Go to **EC2 → Elastic IPs → Allocate Elastic IP address**
2. Associate it with your instance
3. Update your DNS A records to point to the Elastic IP

> Elastic IPs are free while associated with a running instance.

---

## Auto-Start on Reboot

To ensure Docker containers start automatically after an EC2 reboot:

```bash
# Docker is already set to start on boot, and containers have restart: unless-stopped
# Verify Docker service is enabled:
sudo systemctl enable docker
```

---

## Cost Estimate (AWS)

| Resource           | Monthly Cost           |
|--------------------|------------------------|
| EC2 t2.micro       | Free (first 12 months) / ~$8.50 after |
| Elastic IP         | Free (if attached to running instance) |
| Data Transfer      | Free up to 100 GB/month |
| SSL (Let's Encrypt)| Free                   |
| **Total**          | **Free** (within free tier) / **~$8.50/month** |

---

## Security Recommendations

- [ ] Restrict SSH access to your IP only in the Security Group
- [ ] Enable HSTS header in [nginx/default.conf](nginx/default.conf) after confirming SSL works (uncomment the line)
- [ ] Set up AWS CloudWatch for monitoring
- [ ] Enable automatic security updates: `sudo apt install unattended-upgrades`
- [ ] Consider using AWS CloudFront CDN for faster global delivery

---

## Quick Reference Commands

```bash
# Deploy from scratch (full sequence)
ssh -i your-key.pem ubuntu@<IP>
sudo apt update && sudo apt upgrade -y
# ... (install Docker — see Step 3)
cd ~/portfolio
nano init-letsencrypt.sh          # Set your email
sudo ./init-letsencrypt.sh        # Get SSL certs
docker compose up -d              # Launch site

# Update site content
docker compose down
docker compose build --no-cache
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
curl -I https://dr-shamantha-rai.tech
```

---

**Live URL:** https://dr-shamantha-rai.tech
# shamanth-sir-domain
