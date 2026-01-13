# Traefik Reverse Proxy Docker Setup

A complete Docker-based Traefik reverse proxy setup with HTTP support (port 80). Let's Encrypt/HTTPS support can be added later.

## Features

- **Traefik v2.11** - Modern reverse proxy and load balancer
- **HTTP Support** - Configured for port 80 (HTTP)
- **Dashboard** - Web UI accessible on port 8080
- **Docker Provider** - Automatic service discovery from Docker containers
- **Management Scripts** - Easy-to-use scripts for common operations
- **Backup & Restore** - Built-in backup and restore functionality
- **Ready for HTTPS** - Configuration structure ready for Let's Encrypt integration

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Linux system (tested on Ubuntu/Debian/Raspberry Pi OS)
- Network access for downloading Docker images
- Port 80 available (or change in docker-compose.yml)

### Installation

1. **Clone or download this repository:**
   ```bash
   git clone <repository-url>
   cd traefik
   ```

2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Start Traefik:**
   ```bash
   ./scripts/manage.sh start
   ```

4. **Access Traefik Dashboard:**
   - Open your web browser
   - Navigate to `http://YOUR-IP:8080`
   - Or: `http://traefik.localhost:8080`

## Management

Use the management script for common operations:

```bash
# Start Traefik
./scripts/manage.sh start

# Stop Traefik
./scripts/manage.sh stop

# Restart Traefik
./scripts/manage.sh restart

# View logs
./scripts/manage.sh logs

# Check status
./scripts/manage.sh status

# Update to latest version
./scripts/manage.sh update

# Create backup
./scripts/manage.sh backup

# Restore from backup
./scripts/manage.sh restore /path/to/backup.tar.gz

# Show dashboard URL
./scripts/manage.sh dashboard

# Access container shell
./scripts/manage.sh shell
```

## Directory Structure

```
./
├── docker-compose.yml          # Docker Compose configuration
├── setup.sh                   # Initial setup script
├── config/
│   ├── traefik.yml           # Main Traefik configuration
│   └── dynamic.yml           # Dynamic configuration (can be modified without restart)
├── scripts/
│   └── manage.sh             # Management script
├── data/                      # Traefik data directory (certificates, etc.)
└── backups/                   # Configuration backups
```

## Configuration

### Main Configuration (`config/traefik.yml`)

The main Traefik configuration file includes:
- API/Dashboard settings
- Entry points (HTTP on port 80)
- Docker provider for automatic service discovery
- File provider for dynamic configuration

### Dynamic Configuration (`config/dynamic.yml`)

This file can be modified without restarting Traefik. Currently includes:
- Placeholder for HTTP to HTTPS redirect (for future use)
- Placeholder for TLS options (for future use)

### Adding Services to Traefik

To route traffic through Traefik, add labels to your service containers:

```yaml
services:
  myservice:
    image: myimage:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myservice.rule=Host(`myservice.localhost`)"
      - "traefik.http.routers.myservice.entrypoints=web"
      - "traefik.http.services.myservice.loadbalancer.server.port=8080"
    networks:
      - traefik
```

**Important:** Services must be on the `traefik` network to be discovered.

## Ports

- **80** - HTTP entry point (main traffic)
- **8080** - Traefik dashboard (web UI)

## Security

### Important Security Notes

1. **Current Setup (HTTP Only):**
   - Dashboard is accessible without authentication
   - All traffic is unencrypted
   - Suitable for local network use only

2. **Network Security:**
   - Consider restricting access to trusted networks
   - Use firewall rules to limit access
   - Consider VPN for remote access

3. **Dashboard Security:**
   - Dashboard is currently insecure (HTTP)
   - When adding HTTPS, configure authentication
   - Consider restricting dashboard access to localhost

4. **Docker Socket Access:**
   - Traefik has read-only access to Docker socket
   - This allows automatic service discovery
   - Only install on trusted machines

5. **Updates:**
   - Regularly update Traefik: `./scripts/manage.sh update`
   - Monitor security advisories
   - Keep Docker host system updated

### Future: Adding Let's Encrypt/HTTPS

The configuration is structured to easily add Let's Encrypt support:

1. **Update `config/traefik.yml`:**
   - Add HTTPS entry point (port 443)
   - Configure Let's Encrypt certificate resolver
   - Enable HTTPS redirect

2. **Update `docker-compose.yml`:**
   - Add port 443 mapping
   - Add ACME volume for certificates

3. **Update `config/dynamic.yml`:**
   - Uncomment HTTPS redirect middleware
   - Configure TLS options

See Traefik documentation for detailed Let's Encrypt setup.

## Backup and Restore

### Automatic Backups

Create regular backups:

```bash
# Create backup
./scripts/manage.sh backup

# Backups are stored in ./backups/ directory
```

### Restore Configuration

```bash
# Restore from backup
./scripts/manage.sh restore ./backups/traefik-config-20231201-120000.tar.gz
```

**Note:** Restoring will overwrite your current configuration. Make sure to backup first!

## Troubleshooting

### Common Issues

1. **Container won't start:**
   ```bash
   # Check logs
   ./scripts/manage.sh logs
   
   # Check Docker status
   sudo systemctl status docker
   ```

2. **Port 80 already in use:**
   ```bash
   # Check what's using port 80
   sudo netstat -tulpn | grep :80
   
   # Or change port in docker-compose.yml
   ports:
     - "8081:80"  # Use port 8081 instead
   ```

3. **Services not discovered:**
   - Ensure services are on the `traefik` network
   - Check that `traefik.enable=true` label is set
   - Verify Docker socket is accessible

4. **Permission issues:**
   ```bash
   # Fix Docker socket permissions
   sudo chmod 666 /var/run/docker.sock
   
   # Or add user to docker group (requires logout/login)
   sudo usermod -aG docker $USER
   ```

5. **Dashboard not accessible:**
   - Check firewall rules
   - Verify container is running: `./scripts/manage.sh status`
   - Check logs for errors: `./scripts/manage.sh logs`

### Getting Help

- **Traefik Documentation:** https://doc.traefik.io/traefik/
- **Traefik GitHub:** https://github.com/traefik/traefik
- **Traefik Community:** https://community.traefik.io/

## Advanced Configuration

### Custom Ports

Edit `docker-compose.yml` to change ports:

```yaml
ports:
  - "8081:80"      # Change HTTP port to 8081
  - "9080:8080"    # Change dashboard port to 9080
```

### Resource Limits

Add resource limits to `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

### Custom Networks

Traefik creates a `traefik` network by default. Services must join this network:

```yaml
services:
  myservice:
    networks:
      - traefik

networks:
  traefik:
    external: true
```

### Logging

Configure logging in `config/traefik.yml`:

```yaml
log:
  level: DEBUG  # Change to DEBUG for more verbose logging
  filePath: "/var/log/traefik.log"

accessLog:
  filePath: "/var/log/traefik-access.log"
```

## Example: Routing a Service

Here's a complete example of routing a service through Traefik:

```yaml
version: '3.8'

services:
  webapp:
    image: nginx:alpine
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webapp.rule=Host(`webapp.localhost`)"
      - "traefik.http.routers.webapp.entrypoints=web"
      - "traefik.http.services.webapp.loadbalancer.server.port=80"
    networks:
      - traefik

networks:
  traefik:
    external: true
```

Access the service at: `http://webapp.localhost`

## Updates and Maintenance

### Regular Maintenance

1. **Monthly:**
   - Update Traefik: `./scripts/manage.sh update`
   - Create backup: `./scripts/manage.sh backup`
   - Review logs for errors

2. **Quarterly:**
   - Review service configurations
   - Check for unused routes
   - Verify network connectivity

3. **When adding HTTPS:**
   - Update configuration files
   - Test certificate renewal
   - Verify redirects work correctly

### Version Management

- Traefik follows semantic versioning
- Breaking changes are announced in release notes
- Test updates in a development environment when possible
- Keep configuration files backed up

## Next Steps

1. **Start Traefik:** `./scripts/manage.sh start`
2. **Access Dashboard:** `http://YOUR-IP:8080`
3. **Add Services:** Configure your services with Traefik labels
4. **Test Routing:** Verify services are accessible through Traefik
5. **Add HTTPS:** When ready, configure Let's Encrypt (see documentation)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

