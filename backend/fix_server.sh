#!/bin/bash

# SQUAD Backend - Automated Fix Script
# This script will attempt to fix common issues and start the server

set -e  # Exit on error

echo "=========================================="
echo "SQUAD Backend - Automated Fix"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Step 1: Check if we're in the right directory
print_step "Step 1: Navigating to backend directory..."
if [ -d "$HOME/squad-backend" ]; then
    cd $HOME/squad-backend
    print_success "In directory: $(pwd)"
else
    echo "Error: squad-backend directory not found at $HOME/squad-backend"
    echo "Please ensure the backend code is uploaded to the server."
    exit 1
fi
echo ""

# Step 2: Create .env if it doesn't exist
print_step "Step 2: Checking .env file..."
if [ ! -f ".env" ]; then
    print_warning ".env not found, creating..."
    cat > .env << 'EOF'
DB_HOST=localhost
DB_USER=squad_user
DB_PASSWORD=StrongPassword123!
DB_NAME=squad_db
JWT_SECRET=a_very_strong_and_secret_jwt_key_that_no_one_can_guess
ADMIN_API_KEY=another_super_secret_admin_key_for_postman_access
PORT=3000
EOF
    print_success ".env file created"
else
    print_success ".env file exists"
fi
echo ""

# Step 3: Install dependencies if needed
print_step "Step 3: Checking npm dependencies..."
if [ ! -d "node_modules" ]; then
    print_warning "node_modules not found, installing..."
    npm install
    print_success "Dependencies installed"
else
    print_success "Dependencies already installed"
fi
echo ""

# Step 4: Set up database
print_step "Step 4: Setting up database..."

# Create database and user
print_warning "Creating database and user (will skip if exists)..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS squad_db;" 2>/dev/null || true
sudo mysql -e "CREATE USER IF NOT EXISTS 'squad_user'@'localhost' IDENTIFIED BY 'StrongPassword123!';" 2>/dev/null || true
sudo mysql -e "GRANT ALL PRIVILEGES ON squad_db.* TO 'squad_user'@'localhost';" 2>/dev/null || true
sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# Check if tables exist
TABLE_COUNT=$(mysql -u squad_user -pStrongPassword123! squad_db -e "SHOW TABLES;" 2>/dev/null | wc -l)

if [ "$TABLE_COUNT" -lt 2 ]; then
    print_warning "Database tables not found, importing schema..."
    if [ -f "squad.sql" ]; then
        mysql -u squad_user -pStrongPassword123! squad_db < squad.sql
        print_success "Database schema imported"
    else
        print_warning "squad.sql not found, skipping schema import"
    fi
else
    print_success "Database tables already exist"
fi
echo ""

# Step 5: Fix chat endpoint
print_step "Step 5: Fixing chat endpoint..."
if [ -f "routes/chat.js" ]; then
    if grep -q "'/:id/send'" routes/chat.js; then
        sed -i "s|'/:id/send'|'/:id/messages'|g" routes/chat.js
        print_success "Chat endpoint fixed"
    else
        print_success "Chat endpoint already correct"
    fi
else
    print_warning "routes/chat.js not found"
fi
echo ""

# Step 6: Configure firewall
print_step "Step 6: Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 3000/tcp 2>/dev/null || true
    print_success "Firewall configured"
else
    print_warning "UFW not installed, skipping"
fi
echo ""

# Step 7: Stop existing PM2 process
print_step "Step 7: Managing PM2 processes..."
if command -v pm2 &> /dev/null; then
    if pm2 list | grep -q "squad-api"; then
        print_warning "Stopping existing squad-api process..."
        pm2 stop squad-api 2>/dev/null || true
        pm2 delete squad-api 2>/dev/null || true
        print_success "Old process removed"
    fi
else
    echo "PM2 not installed. Installing..."
    sudo npm install -g pm2
    print_success "PM2 installed"
fi
echo ""

# Step 8: Start the server
print_step "Step 8: Starting the server..."
pm2 start index.js --name squad-api
pm2 save
print_success "Server started with PM2"
echo ""

# Step 9: Set up auto-start
print_step "Step 9: Configuring auto-start..."
pm2 startup | tail -n 1 | sudo bash 2>/dev/null || true
print_success "Auto-start configured"
echo ""

# Step 10: Wait and test
print_step "Step 10: Testing server..."
sleep 3

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_success "Server is responding!"
    echo ""
    echo "Response from server:"
    curl -s http://localhost:3000
    echo ""
else
    print_warning "Server is not responding yet. Checking logs..."
    pm2 logs squad-api --lines 20 --nostream
fi
echo ""

# Final status
echo "=========================================="
echo "SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Server Status:"
pm2 list
echo ""
echo "Public IP: $(curl -s ifconfig.me)"
echo "API URL: http://$(curl -s ifconfig.me):3000/api"
echo ""
echo "Useful commands:"
echo "  pm2 logs squad-api    - View logs"
echo "  pm2 restart squad-api - Restart server"
echo "  pm2 monit             - Monitor resources"
echo ""
echo "Test the API:"
echo "  curl http://localhost:3000"
echo "  curl http://$(curl -s ifconfig.me):3000"
echo ""
