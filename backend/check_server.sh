#!/bin/bash

# SQUAD Backend - Server Diagnostic Script
# Run this on your EC2 instance to diagnose the connection issue

echo "=========================================="
echo "SQUAD Backend - Server Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 1. Check Node.js
echo "1. Checking Node.js installation..."
if command -v node &> /dev/null; then
    print_status 0 "Node.js is installed: $(node --version)"
else
    print_status 1 "Node.js is NOT installed"
    echo "   Install: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
fi
echo ""

# 2. Check MySQL
echo "2. Checking MySQL/MariaDB..."
if command -v mysql &> /dev/null; then
    print_status 0 "MySQL is installed"
    if systemctl is-active --quiet mysql; then
        print_status 0 "MySQL service is running"
    else
        print_status 1 "MySQL service is NOT running"
        echo "   Start: sudo systemctl start mysql"
    fi
else
    print_status 1 "MySQL is NOT installed"
    echo "   Install: sudo apt install mysql-server -y"
fi
echo ""

# 3. Check PM2
echo "3. Checking PM2..."
if command -v pm2 &> /dev/null; then
    print_status 0 "PM2 is installed"
    echo ""
    pm2 list
else
    print_status 1 "PM2 is NOT installed"
    echo "   Install: sudo npm install -g pm2"
fi
echo ""

# 4. Check if port 3000 is listening
echo "4. Checking if port 3000 is listening..."
if netstat -tuln 2>/dev/null | grep -q ":3000 "; then
    print_status 0 "Port 3000 is in use"
    netstat -tuln | grep ":3000"
else
    print_status 1 "Port 3000 is NOT listening"
    echo "   This means the server is not running!"
fi
echo ""

# 5. Check backend directory
echo "5. Checking backend directory..."
if [ -d "$HOME/squad-backend" ]; then
    print_status 0 "Backend directory exists: $HOME/squad-backend"
    cd $HOME/squad-backend
    
    # Check for required files
    if [ -f "index.js" ]; then
        print_status 0 "index.js found"
    else
        print_status 1 "index.js NOT found"
    fi
    
    if [ -f "package.json" ]; then
        print_status 0 "package.json found"
    else
        print_status 1 "package.json NOT found"
    fi
    
    if [ -f ".env" ]; then
        print_status 0 ".env file found"
    else
        print_status 1 ".env file NOT found"
        print_warning "Creating .env file..."
        cat > .env << 'EOF'
DB_HOST=localhost
DB_USER=squad_user
DB_PASSWORD=StrongPassword123!
DB_NAME=squad_db
JWT_SECRET=a_very_strong_and_secret_jwt_key_that_no_one_can_guess
ADMIN_API_KEY=another_super_secret_admin_key_for_postman_access
PORT=3000
EOF
        print_status 0 ".env file created"
    fi
    
    if [ -d "node_modules" ]; then
        print_status 0 "node_modules directory exists"
    else
        print_status 1 "node_modules NOT found"
        echo "   Run: npm install"
    fi
else
    print_status 1 "Backend directory NOT found at $HOME/squad-backend"
fi
echo ""

# 6. Check database
echo "6. Checking database..."
if command -v mysql &> /dev/null; then
    if mysql -u squad_user -pStrongPassword123! -e "USE squad_db; SHOW TABLES;" 2>/dev/null; then
        print_status 0 "Database 'squad_db' exists and is accessible"
        echo "   Tables:"
        mysql -u squad_user -pStrongPassword123! squad_db -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | sed 's/^/     - /'
    else
        print_status 1 "Database 'squad_db' does not exist or is not accessible"
        echo "   Need to create database and import schema"
    fi
else
    print_warning "MySQL not installed, skipping database check"
fi
echo ""

# 7. Check firewall
echo "7. Checking firewall (UFW)..."
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        print_info "UFW is active"
        if sudo ufw status | grep -q "3000"; then
            print_status 0 "Port 3000 is allowed in UFW"
        else
            print_status 1 "Port 3000 is NOT allowed in UFW"
            echo "   Run: sudo ufw allow 3000/tcp"
        fi
    else
        print_info "UFW is not active"
    fi
else
    print_info "UFW not installed"
fi
echo ""

# 8. Test local connectivity
echo "8. Testing local connectivity..."
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_status 0 "Server responds on localhost:3000"
    echo "   Response:"
    curl -s http://localhost:3000 | head -n 3
else
    print_status 1 "Server does NOT respond on localhost:3000"
fi
echo ""

# 9. Get public IP
echo "9. Server information..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")
print_info "Public IP: $PUBLIC_IP"
print_info "Expected IP: 13.250.156.248"
if [ "$PUBLIC_IP" != "13.250.156.248" ]; then
    print_warning "Public IP mismatch! Update Flutter app with: $PUBLIC_IP"
fi
echo ""

# 10. Check PM2 logs if PM2 is installed
if command -v pm2 &> /dev/null; then
    echo "10. Recent PM2 logs (last 20 lines)..."
    if pm2 list | grep -q "squad-api"; then
        pm2 logs squad-api --lines 20 --nostream
    else
        print_warning "No 'squad-api' process found in PM2"
    fi
fi
echo ""

echo "=========================================="
echo "DIAGNOSTIC SUMMARY"
echo "=========================================="
echo ""

# Provide recommendations
echo "RECOMMENDED ACTIONS:"
echo ""

if ! netstat -tuln 2>/dev/null | grep -q ":3000 "; then
    echo "🔴 CRITICAL: Server is not running on port 3000"
    echo "   → Start the server (see instructions below)"
    echo ""
fi

if ! mysql -u squad_user -pStrongPassword123! -e "USE squad_db;" 2>/dev/null; then
    echo "🔴 CRITICAL: Database is not set up"
    echo "   → Create database and import schema (see instructions below)"
    echo ""
fi

if [ ! -d "$HOME/squad-backend/node_modules" ]; then
    echo "🟡 WARNING: Dependencies not installed"
    echo "   → Run: cd ~/squad-backend && npm install"
    echo ""
fi

echo "=========================================="
echo "QUICK FIX COMMANDS"
echo "=========================================="
echo ""
echo "If database doesn't exist:"
echo "  sudo mysql -e \"CREATE DATABASE IF NOT EXISTS squad_db;\""
echo "  sudo mysql -e \"CREATE USER IF NOT EXISTS 'squad_user'@'localhost' IDENTIFIED BY 'StrongPassword123!';\""
echo "  sudo mysql -e \"GRANT ALL PRIVILEGES ON squad_db.* TO 'squad_user'@'localhost';\""
echo "  sudo mysql -e \"FLUSH PRIVILEGES;\""
echo "  cd ~/squad-backend && mysql -u squad_user -pStrongPassword123! squad_db < squad.sql"
echo ""
echo "If dependencies not installed:"
echo "  cd ~/squad-backend && npm install"
echo ""
echo "If server not running:"
echo "  cd ~/squad-backend && pm2 start index.js --name squad-api"
echo "  pm2 save"
echo ""
echo "If port blocked by firewall:"
echo "  sudo ufw allow 3000/tcp && sudo ufw reload"
echo ""
echo "To restart everything:"
echo "  cd ~/squad-backend && pm2 restart squad-api"
echo ""
