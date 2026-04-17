# SQUAD Backend - Setup & Deployment Guide

## What's Included

This is the **100% complete** SQUAD backend as per the blueprint. All features are implemented:

✅ **Authentication System**
- POST /api/auth/register (with player approval workflow)
- POST /api/auth/login (with JWT)
- GET /api/auth/profile

✅ **Admin System**
- POST /api/admin/approve-player/:id (protected by API key)

✅ **Posts System**
- POST /api/posts/upload (with local file storage)
- GET /api/posts (with country & position filtering)
- GET /api/posts/:id
- POST /api/posts/:id/react

✅ **Follow System**
- POST /api/users/:id/follow
- POST /api/users/:id/unfollow
- GET /api/users/:id/followers
- GET /api/users/:id/following

✅ **Chat System**
- POST /api/chats/start
- POST /api/chats/:id/send
- GET /api/chats/:id/messages (supports polling)
- GET /api/chats (list all user chats)

---

## Quick Start (Local Development)

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Create or edit the `.env` file in the root directory:

```env
# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=squad

# JWT Secret (use a strong random string)
JWT_SECRET=your_super_secret_jwt_key_here

# Admin API Key (for approving players via Postman)
ADMIN_API_KEY=your_admin_secret_key

# Server Port
PORT=3000
```

### 3. Create the Database

Run the SQL schema file to create all tables:

```bash
mysql -u root -p < squad.sql
```

Or manually:
1. Open MySQL client: `mysql -u root -p`
2. Create database: `CREATE DATABASE squad;`
3. Use database: `USE squad;`
4. Run the schema: `source squad.sql;`

### 4. Start the Server

```bash
node index.js
```

The server will start on `http://localhost:3000`

---

## API Endpoints Reference

### Base URL
```
http://localhost:3000/api
```

### Authentication

**Register**
```http
POST /auth/register
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password123",
  "type": "player",
  "country": "Egypt",
  "position": "ST",
  "bio": "Professional striker"
}
```

**Login**
```http
POST /auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

**Get Profile**
```http
GET /auth/profile
Authorization: Bearer YOUR_JWT_TOKEN
```

### Admin

**Approve Player**
```http
POST /admin/approve-player/1
x-admin-api-key: your_admin_secret_key
```

### Posts

**Upload Post**
```http
POST /posts/upload
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: multipart/form-data

media: [file]
caption: "Great goal today!"
```

**Get Posts (with filters)**
```http
GET /posts?country=Egypt&position=ST&page=1
```

**React to Post**
```http
POST /posts/1/react
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "reaction_type": "amazing"
}
```

### Follow

**Follow User**
```http
POST /users/5/follow
Authorization: Bearer YOUR_JWT_TOKEN
```

**Get Followers**
```http
GET /users/5/followers
```

### Chat

**Start Chat**
```http
POST /chats/start
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "other_user_id": 5
}
```

**Send Message**
```http
POST /chats/1/send
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "message": "Hello!"
}
```

**Get Messages (with polling support)**
```http
GET /chats/1/messages?since=2024-11-10T12:00:00
Authorization: Bearer YOUR_JWT_TOKEN
```

---

## Deployment to AWS EC2

### 1. Connect to EC2 Instance

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. Install Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 3. Install MySQL/MariaDB

```bash
sudo apt update
sudo apt install mysql-server -y
sudo mysql_secure_installation
```

### 4. Upload Backend Code

```bash
scp -i your-key.pem -r squad-backend ubuntu@your-ec2-ip:~/
```

### 5. Setup Database

```bash
mysql -u root -p < squad.sql
```

### 6. Install PM2

```bash
sudo npm install -g pm2
```

### 7. Start Application with PM2

```bash
cd squad-backend
npm install
pm2 start index.js --name squad-api
pm2 save
pm2 startup
```

### 8. Configure Nginx (Optional)

```bash
sudo apt install nginx -y
```

Create Nginx config:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## File Storage

Currently, media files are stored **locally** in the `uploads/posts/media/` directory. Files are accessible via:

```
http://localhost:3000/uploads/posts/media/filename.jpg
```

### To Migrate to AWS S3 Later:

1. Install AWS SDK: `npm install @aws-sdk/client-s3`
2. Update `config/storage.js` to use S3
3. Update `controllers/postController.js` to upload to S3

---

## Testing with Postman

1. Import the endpoints above into Postman
2. Register a player account
3. Use the admin endpoint to approve the player
4. Login to get a JWT token
5. Test all other endpoints with the token

---

## Project Structure

```
squad-backend/
├── config/
│   └── storage.js          # Multer configuration
├── controllers/
│   ├── adminController.js  # Admin approval logic
│   ├── authController.js   # Registration, login, profile
│   ├── chatController.js   # Chat & messaging
│   ├── postController.js   # Posts & reactions
│   └── userController.js   # Follow system
├── middleware/
│   └── authMiddleware.js   # JWT & admin verification
├── routes/
│   ├── admin.js
│   ├── auth.js
│   ├── chat.js
│   ├── posts.js
│   └── user.js
├── uploads/                # Local file storage
├── db.js                   # Database connection
├── index.js                # Main server file
├── squad.sql               # Database schema
├── package.json
└── .env                    # Environment variables
```

---

## Next Steps

1. ✅ Backend is 100% complete
2. 🔄 Build Flutter frontend
3. 🔄 Connect frontend to backend
4. 🔄 Test full flow
5. 🔄 Deploy both to production

---

**Backend Status: COMPLETE ✅**
