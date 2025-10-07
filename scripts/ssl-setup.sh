#!/bin/bash

# LabFace SSL Setup Script
# This script sets up SSL/TLS certificates for the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSL_DIR="./ssl"
CERT_DIR="/etc/nginx/ssl"
DOMAIN_NAME=${1:-"localhost"}
EMAIL=${2:-"admin@labface.edu"}
SSL_LOG="logs/ssl_setup.log"

echo -e "${BLUE}LabFace SSL Setup${NC}"
echo "=================="
echo "Domain: $DOMAIN_NAME"
echo "Email: $EMAIL"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SSL_LOG"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if certbot is installed
    if ! command -v certbot >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Certbot is not installed${NC}"
        echo "Installing certbot..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y certbot
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y certbot
        elif command -v brew >/dev/null 2>&1; then
            brew install certbot
        else
            echo -e "${RED}✗ Cannot install certbot automatically${NC}"
            echo "Please install certbot manually: https://certbot.eff.org/"
            exit 1
        fi
    fi
    
    # Check if openssl is installed
    if ! command -v openssl >/dev/null 2>&1; then
        echo -e "${RED}✗ OpenSSL is not installed${NC}"
        exit 1
    fi
    
    # Check if nginx is installed
    if ! command -v nginx >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Nginx is not installed${NC}"
        echo "Installing nginx..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y nginx
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y nginx
        elif command -v brew >/dev/null 2>&1; then
            brew install nginx
        else
            echo -e "${RED}✗ Cannot install nginx automatically${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    log "PREREQUISITES: Check passed"
}

# Function to create SSL directory
create_ssl_directory() {
    echo -e "${YELLOW}Creating SSL directory...${NC}"
    
    mkdir -p "$SSL_DIR"
    mkdir -p "$CERT_DIR"
    
    echo -e "${GREEN}✓ SSL directory created${NC}"
    log "SSL_DIR: Created $SSL_DIR and $CERT_DIR"
}

# Function to generate self-signed certificate
generate_self_signed() {
    echo -e "${YELLOW}Generating self-signed certificate...${NC}"
    
    # Generate private key
    openssl genrsa -out "$SSL_DIR/key.pem" 2048
    
    # Generate certificate
    openssl req -new -x509 -key "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.pem" -days 365 -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$DOMAIN_NAME"
    
    # Set proper permissions
    chmod 600 "$SSL_DIR/key.pem"
    chmod 644 "$SSL_DIR/cert.pem"
    
    # Copy to nginx directory
    sudo cp "$SSL_DIR/cert.pem" "$CERT_DIR/"
    sudo cp "$SSL_DIR/key.pem" "$CERT_DIR/"
    sudo chmod 600 "$CERT_DIR/key.pem"
    sudo chmod 644 "$CERT_DIR/cert.pem"
    
    echo -e "${GREEN}✓ Self-signed certificate generated${NC}"
    log "SELF_SIGNED: Certificate generated for $DOMAIN_NAME"
}

# Function to generate Let's Encrypt certificate
generate_letsencrypt() {
    echo -e "${YELLOW}Generating Let's Encrypt certificate...${NC}"
    
    # Stop nginx if running
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Generate certificate
    sudo certbot certonly --standalone -d "$DOMAIN_NAME" --email "$EMAIL" --agree-tos --non-interactive
    
    # Copy certificates
    sudo cp "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" "$SSL_DIR/cert.pem"
    sudo cp "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem" "$SSL_DIR/key.pem"
    sudo chown $USER:$USER "$SSL_DIR/cert.pem" "$SSL_DIR/key.pem"
    
    # Copy to nginx directory
    sudo cp "$SSL_DIR/cert.pem" "$CERT_DIR/"
    sudo cp "$SSL_DIR/key.pem" "$CERT_DIR/"
    sudo chmod 600 "$CERT_DIR/key.pem"
    sudo chmod 644 "$CERT_DIR/cert.pem"
    
    echo -e "${GREEN}✓ Let's Encrypt certificate generated${NC}"
    log "LETSENCRYPT: Certificate generated for $DOMAIN_NAME"
}

# Function to configure nginx for SSL
configure_nginx() {
    echo -e "${YELLOW}Configuring nginx for SSL...${NC}"
    
    # Create nginx configuration
    cat > nginx-ssl.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream frontend {
        server frontend:3000;
    }

    upstream backend {
        server backend:4000;
    }

    upstream ml-service {
        server ml-service:8000;
    }

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name $DOMAIN_NAME;
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $DOMAIN_NAME;

        ssl_certificate $CERT_DIR/cert.pem;
        ssl_certificate_key $CERT_DIR/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Frontend
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # API routes
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Auth routes with stricter rate limiting
        location /api/auth/ {
            limit_req zone=login burst=5 nodelay;
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # WebSocket support
        location /socket.io/ {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # ML Service
        location /ml/ {
            proxy_pass http://ml-service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Static files caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

    # Copy nginx configuration
    sudo cp nginx-ssl.conf /etc/nginx/nginx.conf
    
    # Test nginx configuration
    sudo nginx -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
    else
        echo -e "${RED}✗ Nginx configuration is invalid${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Nginx configured for SSL${NC}"
    log "NGINX: Configured for SSL with $DOMAIN_NAME"
}

# Function to start nginx
start_nginx() {
    echo -e "${YELLOW}Starting nginx...${NC}"
    
    # Start nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # Check nginx status
    if sudo systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx is running${NC}"
    else
        echo -e "${RED}✗ Nginx failed to start${NC}"
        exit 1
    fi
    
    log "NGINX: Started successfully"
}

# Function to setup certificate renewal
setup_renewal() {
    echo -e "${YELLOW}Setting up certificate renewal...${NC}"
    
    # Create renewal script
    cat > ssl-renew.sh << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script

# Renew Let's Encrypt certificate
sudo certbot renew --quiet

# Copy renewed certificates
sudo cp /etc/letsencrypt/live/*/fullchain.pem /etc/nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/*/privkey.pem /etc/nginx/ssl/key.pem

# Reload nginx
sudo systemctl reload nginx

echo "SSL certificates renewed successfully"
EOF

    chmod +x ssl-renew.sh
    
    # Add to crontab for automatic renewal
    (crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/ssl-renew.sh >> $(pwd)/logs/ssl_renewal.log 2>&1") | crontab -
    
    echo -e "${GREEN}✓ Certificate renewal configured${NC}"
    log "RENEWAL: Configured automatic renewal"
}

# Function to test SSL configuration
test_ssl() {
    echo -e "${YELLOW}Testing SSL configuration...${NC}"
    
    # Test HTTPS connection
    if curl -k -f -s "https://$DOMAIN_NAME" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ HTTPS connection successful${NC}"
    else
        echo -e "${RED}✗ HTTPS connection failed${NC}"
        return 1
    fi
    
    # Test SSL certificate
    local cert_info=$(openssl s_client -connect "$DOMAIN_NAME:443" -servername "$DOMAIN_NAME" < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "Certificate check failed")
    
    if [ "$cert_info" != "Certificate check failed" ]; then
        echo -e "${GREEN}✓ SSL certificate is valid${NC}"
        echo "Certificate info:"
        echo "$cert_info"
    else
        echo -e "${RED}✗ SSL certificate check failed${NC}"
        return 1
    fi
    
    log "SSL_TEST: HTTPS connection successful"
}

# Function to show SSL information
show_ssl_info() {
    echo ""
    echo -e "${BLUE}SSL Configuration:${NC}"
    echo "=================="
    echo "Domain: $DOMAIN_NAME"
    echo "Certificate: $SSL_DIR/cert.pem"
    echo "Private Key: $SSL_DIR/key.pem"
    echo "Nginx Config: /etc/nginx/nginx.conf"
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "============"
    echo "HTTPS: https://$DOMAIN_NAME"
    echo "API: https://$DOMAIN_NAME/api"
    echo "ML Service: https://$DOMAIN_NAME/ml"
    echo ""
    echo -e "${BLUE}Certificate Information:${NC}"
    echo "=========================="
    if [ -f "$SSL_DIR/cert.pem" ]; then
        openssl x509 -in "$SSL_DIR/cert.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
    fi
    echo ""
}

# Function to perform full SSL setup
full_setup() {
    echo "Starting full SSL setup..."
    echo ""
    
    check_prerequisites
    create_ssl_directory
    
    if [ "$DOMAIN_NAME" = "localhost" ]; then
        generate_self_signed
    else
        generate_letsencrypt
    fi
    
    configure_nginx
    start_nginx
    setup_renewal
    test_ssl
    show_ssl_info
    
    echo -e "${GREEN}✓ SSL setup completed successfully!${NC}"
    log "SSL_SETUP: Completed successfully for $DOMAIN_NAME"
}

# Function to perform quick setup
quick_setup() {
    echo "Starting quick SSL setup..."
    echo ""
    
    check_prerequisites
    create_ssl_directory
    generate_self_signed
    configure_nginx
    start_nginx
    test_ssl
    show_ssl_info
    
    echo -e "${GREEN}✓ Quick SSL setup completed!${NC}"
    log "SSL_SETUP: Quick setup completed for $DOMAIN_NAME"
}

# Main execution
main() {
    case "${3:-full}" in
        "full")
            full_setup
            ;;
        "quick")
            quick_setup
            ;;
        "self-signed")
            check_prerequisites
            create_ssl_directory
            generate_self_signed
            configure_nginx
            start_nginx
            test_ssl
            show_ssl_info
            ;;
        "letsencrypt")
            check_prerequisites
            create_ssl_directory
            generate_letsencrypt
            configure_nginx
            start_nginx
            setup_renewal
            test_ssl
            show_ssl_info
            ;;
        "test")
            test_ssl
            ;;
        "renew")
            setup_renewal
            ;;
        *)
            echo "Usage: $0 <domain> <email> [full|quick|self-signed|letsencrypt|test|renew]"
            echo ""
            echo "Arguments:"
            echo "  domain  - Domain name for SSL certificate (default: localhost)"
            echo "  email   - Email address for Let's Encrypt (default: admin@labface.edu)"
            echo ""
            echo "Commands:"
            echo "  full         - Perform full SSL setup (default)"
            echo "  quick        - Perform quick SSL setup"
            echo "  self-signed  - Generate self-signed certificate only"
            echo "  letsencrypt  - Generate Let's Encrypt certificate only"
            echo "  test         - Test SSL configuration only"
            echo "  renew        - Setup certificate renewal only"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
