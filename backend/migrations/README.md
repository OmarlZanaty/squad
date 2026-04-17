# Database Migrations

This folder contains all database migration scripts for the SQUAD backend application.

## Migration Files

### Core Migration Script
- **`runMigration.js`** - Main migration script that creates all initial database tables and relationships

### Table Creation Scripts
- **`create_otp_table.sql`** - SQL script to create the OTP (One-Time Password) table
- **`create_media_tables.sql`** - SQL script for media-related tables

### Alter Table Migrations
- **`alter_table_posts_migration.js`** - Adds media-related columns to the posts table
- **`alter_otp_table_migration.js`** - Updates OTP table to use phone instead of email and adds foreign key constraints
- **`remove_phone_number_column_migration.js`** - Removes the redundant phone_number column from users table
- **`add_phone_verified_column_migration.js`** - Adds phone_verified column to users table with default false

## How to Run Migrations

### Initial Setup
For new installations, run the main migration script:
```bash
node migrations/runMigration.js
```

### Specific Updates
For specific table updates, run the individual migration scripts:
```bash
# Update posts table with media columns
node migrations/alter_table_posts_migration.js

# Update OTP table to use phone authentication
node migrations/alter_otp_table_migration.js

# Remove redundant phone_number column from users table
node migrations/remove_phone_number_column_migration.js

# Add phone_verified column to users table
node migrations/add_phone_verified_column_migration.js
```

### SQL Scripts
SQL files can be executed directly in your MySQL client or imported via command line:
```bash
mysql -u username -p database_name < migrations/create_otp_table.sql
```

## Migration Order

1. **runMigration.js** - Create all base tables
2. **alter_table_posts_migration.js** - Add media columns to posts
3. **alter_otp_table_migration.js** - Update OTP system to use phone numbers
4. **remove_phone_number_column_migration.js** - Remove redundant phone_number column
5. **add_phone_verified_column_migration.js** - Add phone_verified column

## Notes

- All migrations are designed to be idempotent (can be run multiple times safely)
- Foreign key constraints ensure data integrity
- Always backup your database before running migrations in production