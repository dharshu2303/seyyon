# Seyyon Backend Setup Guide (PHP + MySQL)

## Requirements
- **XAMPP** / **WAMP** / **Laragon** (any PHP + MySQL local server)
- PHP 7.4+ with PDO extension
- MySQL 5.7+

## Quick Setup (5 minutes)

### Step 1: Install XAMPP
- Download from https://www.apachefriends.org
- Install and start **Apache** and **MySQL**

### Step 2: Copy backend files
- Copy the `backend/` folder to your XAMPP web directory:
  - **Windows:** `C:\xampp\htdocs\seyyon\`
  - So the structure is: `C:\xampp\htdocs\seyyon\config.php`, `admin.php`, `api/`, etc.

### Step 3: Create the database
- Open **phpMyAdmin**: http://localhost/phpmyadmin
- Click **"Import"** tab
- Select `backend/database.sql` and click **"Go"**
- Or create database `seyyon_sos` manually and run the SQL

### Step 4: Update config (if needed)
- Edit `backend/config.php` if your MySQL credentials differ:
  ```php
  define('DB_HOST', 'localhost');
  define('DB_NAME', 'seyyon_sos');
  define('DB_USER', 'root');     // your MySQL username
  define('DB_PASS', '');         // your MySQL password
  ```

### Step 5: Test
- Open http://localhost/seyyon/api/test.php — should show `{"success":true}`
- Open http://localhost/seyyon/admin.php — Admin login page

### Step 6: Connect Flutter App
In `lib/services/backend_service.dart`, update the URL:

- **Android Emulator:** `http://10.0.2.2/seyyon/api`
- **Real device (same WiFi):** `http://YOUR_PC_IP/seyyon/api`
  - Find your IP: Open CMD → type `ipconfig` → look for IPv4 Address
  - Example: `http://192.168.1.5/seyyon/api`

## Admin Panel
- URL: http://localhost/seyyon/admin.php
- Default login: `admin` / `password`
- **Change the password** after first login!

## For Production (hosting online)
- Upload `backend/` to any PHP hosting (Hostinger, InfinityFree, etc.)
- Update MySQL credentials in `config.php`
- Update the server URL in the Flutter app
