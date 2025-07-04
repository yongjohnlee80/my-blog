---
date: 2025-07-03
categories:
  - HomeLab
tags: 
    - Blog
    - Mailcow
    - Email
    - nginx
---

# 📧 Setting Up a Self-Hosted Email Server with Mailcow

Self-hosting an email server has always been a hot topic among homelab enthusiasts and privacy-conscious users. After years of running various services in a Proxmox-based homelab—exposed selectively over the internet through Cloudflare tunnels—my focus shifted to creating a more integrated and privacy-preserving email solution. This blog post shares the rationale, benefits, and high-level setup details of running your own email server, with particular emphasis on Mailcow.
<!-- more -->
---

## Why Run Your Own Email Service?

• Privacy & Control
Most commercial email providers can (and do) access users’ messages in various ways. Hosting your own server grants you full control over how your data is stored and managed, removing a layer of third-party oversight.

• Centralized Identity Management
Operating an in-house email domain lets you maintain a consistent email address across all personal homelab services. This approach simplifies user provisioning and management when new sign-ups or permissions become necessary.

• In-House SMTP for Notifications
Services like Nextcloud, Vaultwarden, or any other productivity tools often require outbound email for user alerts or password recovery. While external SMTP relays exist, hosting your own server removes extra dependencies and simplifies testing in custom scenarios.

• Development & Testing Flexibility
As a full-stack developer, I frequently need multiple test email accounts to validate sign-up and authentication workflows. Relying on external providers (e.g., Gmail) can introduce complexity (OAuth or additional security restrictions), making automated tests harder. Self-hosting avoids these roadblocks.

---

## The Challenges

### 1. Hosting Requirements
• **Open Ports** – Many consumer ISPs filter essential email ports (25, 587, etc.). Renting a VPS that supports open email ports is often mandatory.  
• **Ongoing Maintenance** – Self-hosted email requires monitoring DNS records (SPF, DKIM, DMARC), SSL/TLS certificates, spam filtering, and security patches.

### 2. VPS Considerations
I chose a Contabo VPS for its affordability and capacity (4 CPU cores, 6 GB RAM, 400 GB SSD). This hardware is sufficient not just for Mailcow, but also for hosting additional services like Vaultwarden and documentation blogs. For users planning to run Mailcow alone, the installation process is straightforward. However, combining multiple services on one VPS may require extra work with a reverse proxy and port management.

---

## Introducing Mailcow

[Mailcow](https://mailcow.email/) is an open-source, Docker-based email server suite that integrates key components—Postfix, Dovecot, Rspamd, SOGo, and more—within containers. This approach simplifies updates and ensures better isolation. Mailcow also offers:

• **SSL/TLS Encryption**: Automatic certificate handling via Let’s Encrypt or manual configuration.
• **Security Policies**: Two-factor authentication, enforcing DMARC/DKIM/SPF, and powerful spam filtering through Rspamd.
• **User-Friendly GUI**: An intuitive web interface for managing mail domains, aliases, mailboxes, and monitoring activity.

These built-in features minimize the time and effort you’d otherwise need to assemble such a stack manually.

---

## Managing a Multi-Service VPS

### Domain & DNS Setup
Before installing Mailcow, set up DNS for your domain (e.g., johnosoft.org):
• **A Record**: Points mail.johnosoft.org to your server’s IP.
• **MX Record**: Points to mail.johnosoft.org.
• **SPF Record**: Set up a TXT record (e.g., `v=spf1 mx ~all`) or more specific if you know the IP.
• **DKIM / DMARC**: Will be configured later within Mailcow.

If you’re using a single domain (e.g., johnosoft.org) both for homelab services (behind Cloudflare) and direct mail delivery, be mindful of how you manage certificates. Cloudflare can issue and renew certificates for proxied (orange-cloud) hosts, but publicly exposed subdomains (like your mail server) typically require a valid certificate from Let’s Encrypt or another CA.

### Reverse Proxy Configuration
A common approach is to install an Nginx reverse proxy on the VPS. With a reverse proxy:
1. Services behind Cloudflare stay proxied, offloading certificate renewal to Cloudflare.
2. Mail traffic typically remains off Cloudflare’s proxy to ensure reliable email deliverability. Certbot or another ACME client can then handle certificates for mail subdomains independently.

This structure allows you to manage multiple domains or subdomains in a consistent way, while isolating the email server’s security requirements.

---

## Installing Mailcow

### 1. **Clone the Repository**
``` bash
git clone https://github.com/mailcow/mailcow•dockerized
cd mailcow-dockerized
```

### 2. **Generate Configuration File**
``` bash
./generate_config.sh
```
• Provide your domain (e.g., mail.johnosoft.org) when prompted.

### 3. **Configure IP bindings**
Required only if you need a reverse proxy for multiple services. Otherwise, skip to step 6.
```toml
# modify 'mailcow.conf' to bind the IP and ports so that reverse proxy can 
# listen to the port 80 and 8443.
# The reverse proxy will have to provide the certificates as wel.
HTTP_PORT=8080
HTTP_BIND=127.0.0.1
HTTPS_PORT=8443
HTTPS_BIND=127.0.0.1
SKIP_LETS_ENCRYPT=y
AUTODISCOVER_SAN=n 
```

### 4. **Create docker-compose.override.yml**
Create an external network (“proxy”) if you want Mailcow services and your reverse proxy on the same Docker network.

```bash
# let's create an external network to group services with reverse proxy.
docker network create proxy
```

```yaml
services:
  postfix-mailcow:
    ports:
      - "25:25"
      - "465:465"
      - "587:587"

  # mailcow comes with nginx for the orchestrating its components.
  # You can also remove the following container and have your reverse proxy to
  # map all of the Mailcow endpoints and they are properly forwarded.
  # This includes TLS termination, correct handling of HTTP/HTTPS redirections, 
  # and passing WebSocket traffic where needed.
  nginx-mailcow:
    networks:
      - proxy

networks:
  proxy:
    external: true
```

### 5. **Create TLS certificates for your mail domain**
Install Certbot, then request certificates for your domain.
```bash
sudo apt update
sudo apt install certbot
```

```bash
# Replace these with your actual subdomains
sudo certbot certonly --standalone \
       -d mail.johnosoft.org \
       -d autoconfig.johnosoft.org \
       -d autodiscover.johnosoft.org
```

Certs and private keys are located in `/etc/letsencrypt/live/[your-domain]/`. If needed for a reverse proxy, copy them to the web server’s directory (using “cp -a” or symlinks), ensuring you don’t break renewal paths. Adjust file ownership and permissions so that Nginx (or another web server) can read them:
```bash
sudo cp -a /etc/letsencrypt/live/mail.johnosoft.org <desination_folder>
sudo chmod 640 <desination_folder>/privkey.pem
sudo chmod 644 <desination_folder>/fullchain.pem
```

### 6. **Start Mailcow**
```bash
sudo docker-compose up -d
```

```bash
# Check if all Mailcow containers are running:
sudo docker-compose ps
```

### 7. **Configure your reverse proxy (nginx)**
Example configuration:
```yaml title:"docker-compose.yml"
version: "3.8"

services:
  nginx:
    image: nginx:latest
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./conf.d:/etc/nginx/conf.d
      - ./ssl:/etc/nginx/ssl
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    networks:
      - proxy

networks:
  proxy:
    external: true
```

Then map the Mailcow endpoints in Nginx configuration to proxy traffic to Mailcow’s internal Nginx container (port 8080).
```text title:"mailcow.conf"
server {
    listen 80;
    server_name mail.johnosoft.org autoconfig.johnosoft.org autodiscover.johnosoft.org;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name mail.johnosoft.org autoconfig.johnosoft.org autodiscover.johnosoft.org;

    ssl_certificate     <cert_location>/fullchain.pem;
    ssl_certificate_key <cert_location>/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5:!SHA1:!kRSA;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    location /Microsoft-Server-ActiveSync {
        proxy_pass http://nginx-mailcow:8080/Microsoft-Server-ActiveSync;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 75;
        proxy_send_timeout 3650;
        proxy_read_timeout 3650;
        proxy_buffers 64 512k;
        client_body_buffer_size 512k;
        client_max_body_size 0;
    }

    location / {
        proxy_pass http://nginx-mailcow:8080/;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffer_size 128k;
        proxy_buffers 64 512k;
        proxy_busy_buffers_size 512k;
        client_max_body_size 0;
    }
}
```

### 8. **Administrating Webmail**
• Log in to Admin Panel: `mail.johnosoft.org/admin`, and change the credential immediately.
> Username: admin
> Password: moohoo

• Configure 2FA right away

### 9. **Configure DKIM and DMARC**
• Go to **Configuration** → **ARC/DKIM keys** to generate a new key.
• Add the displayed DKIM record to your DNS.
• For DMARC, add a TXT record in your DNS: read about DMARC as it's pretty straight forward, and will only take a few minutes.
• The following `_dmarc` TXT record instructs the policy of "quarantine" (e.g., spam folder) of 50% threshold. In other words, this record is telling recipients that if a message does not pass DMARC alignment, half of those failing messages should be quarantined, and aggregate feedback will be sent to the specified email address.
    ```text
    "v=DMARC1; p=quarantine; pct=50; rua=mailto:postmaster@mail.johnosoft.org;"
    ```

### 10. **Create mailbox (a user) and test it**
• Under **Mail setup** → **Mailboxes**, create user mailboxes as needed.
• Send and receive test emails to confirm that everything works correctly. Use [mail-tester](https://www.mail-tester.com/) to verify and review the score of your email-server's reputation.
---

## Final Thoughts

Ultimately, self-hosting an email service requires more diligence than using a free provider, but the benefits can be significant. Mailcow streamlines the administrative workload while providing excellent security and reliability:

- **Complete Data Ownership**: No more worrying about whether a third-party mailbox provider scans or logs your messages.
- **Tailored Configuration**: You control spam filtering, domain policies, aliases, and more.
- **Improved Testing Environment**: Especially beneficial for developers who need flexible, localized testing without the constraints imposed by external mail providers.

Be sure to stay current with security updates and best practices (SPF, DKIM, DMARC, etc.) to maintain a good sending reputation and keep your mail domain trusted. If you are comfortable with Docker and basic DNS routing, Mailcow can be an excellent choice for personal or small-business email hosting.
