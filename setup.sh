#!/bin/bash
# Setup script for Traefik reverse proxy Docker container
# This script creates a complete Traefik setup with HTTP support (port 80)
# Let's Encrypt support can be added later

# Prevent script from being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    :
else
    echo "This script should not be sourced. Please run it directly:"
    echo "./setup.sh"
    return 1
fi

# Get the project root directory based on the script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

# Configuration variables
CONTAINER_NAME="traefik"
HOST_PORT_HTTP=80
HOST_PORT_DASHBOARD=8080
DATA_DIR="$PROJECT_ROOT/data"
CONFIG_DIR="$PROJECT_ROOT/config"

# Color output for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Traefik setup...${NC}"
echo -e "${GREEN}Project root: $PROJECT_ROOT${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing Docker...${NC}"
    
    # Detect system type
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Could not detect OS type. Please install Docker manually.${NC}"
        exit 1
    fi

    # Update package lists
    sudo apt-get update
    
    # Install common prerequisites
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    if [[ "$OS" == *"Ubuntu"* ]]; then
        echo -e "${GREEN}Detected Ubuntu system. Installing Docker using Ubuntu repository...${NC}"
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker repository for Ubuntu
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    elif [[ "$OS" == *"Raspberry Pi"* ]] || [[ "$OS" == *"Debian"* ]]; then
        echo -e "${GREEN}Detected Raspberry Pi OS/Debian system. Installing Docker using Debian repository...${NC}"
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker repository for Debian
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo -e "${YELLOW}Unknown OS type. Attempting to install Docker using get.docker.com script...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    fi

    # Update package lists again
    sudo apt-get update

    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null; then
        sudo groupadd docker
    fi

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Enable and start Docker service
    echo -e "${GREEN}Enabling Docker to start on boot...${NC}"
    sudo systemctl enable docker
    sudo systemctl start docker

    echo -e "${GREEN}Docker installed successfully. You may need to log out and back in for group changes to take effect.${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
    # Ensure Docker is enabled to start on boot
    if ! systemctl is-enabled docker > /dev/null; then
        echo -e "${YELLOW}Enabling Docker to start on boot...${NC}"
        sudo systemctl enable docker
    fi
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing Docker Compose...${NC}"
    
    # Install Docker Compose plugin (modern method)
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    
    echo -e "${GREEN}Docker Compose installed successfully.${NC}"
else
    echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

# Create necessary directories
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$DATA_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$PROJECT_ROOT/scripts"
mkdir -p "$PROJECT_ROOT/backups"

# Create Traefik configuration file
echo -e "${YELLOW}Creating Traefik configuration...${NC}"
cat > "$CONFIG_DIR/traefik.yml" << 'EOF'
# Traefik configuration file
# HTTP-only configuration (Let's Encrypt can be added later)

api:
  dashboard: true
  insecure: true  # Set to false when using HTTPS

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: web
          scheme: http

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

log:
  level: INFO
  filePath: ""

accessLog: {}

# Global settings
global:
  checkNewVersion: true
  sendAnonymousUsage: false
EOF

echo -e "${GREEN}Created Traefik configuration at $CONFIG_DIR/traefik.yml${NC}"

# Create dynamic configuration file (for future use)
echo -e "${YELLOW}Creating dynamic configuration...${NC}"
cat > "$CONFIG_DIR/dynamic.yml" << 'EOF'
# Dynamic configuration for Traefik
# This file can be modified without restarting Traefik

# HTTP to HTTPS redirect (uncomment when Let's Encrypt is configured)
# http:
#   middlewares:
#     redirect-to-https:
#       redirectScheme:
#         scheme: https
#         permanent: true

# TLS configuration (uncomment when Let's Encrypt is configured)
# tls:
#   options:
#     default:
#       sslProtocols:
#         - "TLSv1.2"
#         - "TLSv1.3"
EOF

echo -e "${GREEN}Created dynamic configuration at $CONFIG_DIR/dynamic.yml${NC}"

# Check if docker-compose.yml already exists
if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    echo -e "${YELLOW}Warning: docker-compose.yml already exists!${NC}"
    echo -e "${YELLOW}Running setup.sh will OVERWRITE your existing configuration.${NC}"
    echo -e "${YELLOW}Any customizations or comments will be lost.${NC}"
    echo ""
    read -p "Do you want to continue and overwrite it? (y/N): " OVERWRITE_CONFIRM
    if [[ ! "$OVERWRITE_CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled. Your existing docker-compose.yml is unchanged.${NC}"
        exit 0
    fi
    
    # Create backup before overwriting
    BACKUP_FILE="$PROJECT_ROOT/docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$PROJECT_ROOT/docker-compose.yml" "$BACKUP_FILE"
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
fi

# Create docker-compose.yml
echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
cat > "$PROJECT_ROOT/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  traefik:
    container_name: traefik
    image: traefik:v2.11
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"      # HTTP
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./config/dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./data:/data
    environment:
      - TZ=Europe/London
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.localhost`)"
      - "traefik.http.routers.traefik.entrypoints=web"
      - "traefik.http.services.traefik.loadbalancer.server.port=8080"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  traefik:
    name: traefik
    driver: bridge
EOF

echo -e "${GREEN}Created docker-compose.yml${NC}"

# Create a management script
echo -e "${YELLOW}Creating management scripts...${NC}"
cat > "$PROJECT_ROOT/scripts/manage.sh" << 'EOF'
#!/bin/bash
# Traefik management script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "Traefik Management Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start           Start Traefik"
    echo "  stop            Stop Traefik"
    echo "  restart         Restart Traefik"
    echo "  logs            Show Traefik logs"
    echo "  status          Show container status"
    echo "  update          Update Traefik to latest version"
    echo "  backup          Create a backup of configuration"
    echo "  restore [file]  Restore configuration from backup"
    echo "  shell           Access Traefik container shell"
    echo "  dashboard       Show dashboard URL"
    echo "  help            Show this help message"
    echo ""
}

start_traefik() {
    echo -e "${YELLOW}Starting Traefik...${NC}"
    cd "$PROJECT_ROOT"
    docker compose up -d
    echo -e "${GREEN}Traefik started successfully!${NC}"
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}Access dashboard at: http://${IP_ADDRESS}:8080${NC}"
    echo -e "${BLUE}Or: http://traefik.localhost:8080${NC}"
}

stop_traefik() {
    echo -e "${YELLOW}Stopping Traefik...${NC}"
    cd "$PROJECT_ROOT"
    docker compose down
    echo -e "${GREEN}Traefik stopped successfully!${NC}"
}

restart_traefik() {
    echo -e "${YELLOW}Restarting Traefik...${NC}"
    cd "$PROJECT_ROOT"
    docker compose restart
    echo -e "${GREEN}Traefik restarted successfully!${NC}"
}

show_logs() {
    echo -e "${YELLOW}Showing Traefik logs (Ctrl+C to exit)...${NC}"
    cd "$PROJECT_ROOT"
    docker compose logs -f
}

show_status() {
    echo -e "${YELLOW}Container Status:${NC}"
    cd "$PROJECT_ROOT"
    docker compose ps
    echo ""
    echo -e "${YELLOW}System Resources:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" traefik
}

update_traefik() {
    echo -e "${YELLOW}Updating Traefik...${NC}"
    cd "$PROJECT_ROOT"
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}Traefik updated successfully!${NC}"
}

backup_config() {
    BACKUP_DIR="$PROJECT_ROOT/backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/traefik-config-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    echo -e "${YELLOW}Creating backup...${NC}"
    tar -czf "$BACKUP_FILE" -C "$PROJECT_ROOT" config data
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
}

restore_config() {
    if [ -z "$1" ]; then
        echo -e "${RED}Please specify backup file to restore${NC}"
        echo "Usage: $0 restore /path/to/backup.tar.gz"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}Backup file not found: $1${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring configuration from $1...${NC}"
    echo -e "${RED}This will overwrite current configuration. Continue? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        stop_traefik
        tar -xzf "$1" -C "$PROJECT_ROOT"
        start_traefik
        echo -e "${GREEN}Configuration restored successfully!${NC}"
    else
        echo -e "${YELLOW}Restore cancelled${NC}"
    fi
}

access_shell() {
    echo -e "${YELLOW}Accessing Traefik container shell...${NC}"
    cd "$PROJECT_ROOT"
    docker compose exec traefik /bin/sh
}

show_dashboard() {
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}Traefik Dashboard URLs:${NC}"
    echo -e "${YELLOW}  http://${IP_ADDRESS}:8080${NC}"
    echo -e "${YELLOW}  http://traefik.localhost:8080${NC}"
    echo ""
    echo -e "${BLUE}Note: Dashboard is currently insecure (HTTP only)${NC}"
    echo -e "${BLUE}This is expected for initial setup. HTTPS can be configured later.${NC}"
}

case "$1" in
    start)
        start_traefik
        ;;
    stop)
        stop_traefik
        ;;
    restart)
        restart_traefik
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    update)
        update_traefik
        ;;
    backup)
        backup_config
        ;;
    restore)
        restore_config "$2"
        ;;
    shell)
        access_shell
        ;;
    dashboard)
        show_dashboard
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x "$PROJECT_ROOT/scripts/manage.sh"

# Create .gitignore file
echo -e "${YELLOW}Creating .gitignore file...${NC}"
cat > "$PROJECT_ROOT/.gitignore" << 'EOF'
# Traefik data
data/

# Temporary files
*.tmp
*.log
.DS_Store
Thumbs.db

# Docker
.docker/

# Backups (optional - you might want to keep these)
backups/

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# Configuration backups
*.backup.*
EOF

# Set proper permissions
echo -e "${YELLOW}Setting proper permissions...${NC}"
chmod +x "$PROJECT_ROOT/scripts/manage.sh"
chmod 755 "$DATA_DIR"
chmod 755 "$CONFIG_DIR"

# Get the IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Display completion information
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Traefik setup completed!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "${YELLOW}1. Start Traefik:${NC}"
echo -e "   ./scripts/manage.sh start"
echo ""
echo -e "${YELLOW}2. Access Traefik Dashboard:${NC}"
echo -e "   http://${IP_ADDRESS}:8080"
echo -e "   Or: http://traefik.localhost:8080"
echo ""
echo -e "${YELLOW}3. Configure services to use Traefik:${NC}"
echo -e "   Add labels to your service containers to enable Traefik routing"
echo ""
echo -e "${BLUE}Traefik management commands:${NC}"
echo -e "${YELLOW}* Start:     ./scripts/manage.sh start${NC}"
echo -e "${YELLOW}* Stop:      ./scripts/manage.sh stop${NC}"
echo -e "${YELLOW}* Logs:      ./scripts/manage.sh logs${NC}"
echo -e "${YELLOW}* Status:   ./scripts/manage.sh status${NC}"
echo -e "${YELLOW}* Update:    ./scripts/manage.sh update${NC}"
echo -e "${YELLOW}* Backup:    ./scripts/manage.sh backup${NC}"
echo -e "${YELLOW}* Dashboard: ./scripts/manage.sh dashboard${NC}"
echo -e "${YELLOW}* Help:      ./scripts/manage.sh help${NC}"
echo ""
echo -e "${GREEN}For detailed instructions, see README.md${NC}"
echo -e "${GREEN}=====================================${NC}"

