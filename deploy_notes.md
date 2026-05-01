# 📋 Deploy Notes — quyethoang-style Website

## 🏗️ Architecture

| Thành phần | Công nghệ |
|---|---|
| **Frontend** | HTML + CSS + Vanilla JS (static files) |
| **Backend Server** | **PowerShell** (`server.ps1`) — `System.Net.HttpListener` |
| **Database** | SQLite (`brain.db`) — truy vấn qua `sqlite3` CLI |
| **Email** | Resend API (gửi qua `send_email.ps1`) |
| **Payment webhook** | SePay → `/api/sepay-webhook` |
| **Process Manager** | `systemd` (`website.service`) |

> ⚠️ **Không phải Node.js/Express.** Server là PowerShell Core (`pwsh`).
> Không cần `npm install` hay build step. Chạy thẳng `pwsh server.ps1`.

---

## 🔐 Biến môi trường cần có trên VPS

Tạo file `/var/www/website/.env` với nội dung:

```env
PORT=8081
RESEND_API_KEY=<your_resend_api_key>
RESEND_FROM=onboarding@resend.dev
RESEND_FROM_NAME=Quyet Hoang
DB_PATH=/var/www/website/brain.db
```

---

## 🚀 Lệnh chạy server

### Chạy thủ công (test):
```bash
pwsh /var/www/website/server.ps1
```

### Chạy qua systemd (production):
```bash
# Cài service
cp /var/www/website/website.service /etc/systemd/system/ps-website.service
systemctl daemon-reload
systemctl enable ps-website
systemctl start ps-website

# Kiểm tra
systemctl status ps-website
```

---

## 🌐 Cổng & Routing

| URL | Nội dung |
|---|---|
| `http://localhost:8081/` | Trang landing chính |
| `http://localhost:8081/leadmagnet` | Trang lead magnet / tài liệu miễn phí |
| `http://localhost:8081/product-1` | Trang bán hàng (Capsule Wardrobe) |
| `http://localhost:8081/admin` | CRM admin panel |
| `http://localhost:8081/api/...` | API endpoints |

> Nginx reverse proxy từ port 80/443 → 8081

---

## 📦 Dependencies cần cài trên VPS

```bash
# PowerShell Core
apt-get install -y powershell

# SQLite CLI
apt-get install -y sqlite3

# Nginx (reverse proxy)
apt-get install -y nginx
```

---

## 📁 Cấu trúc thư mục trên VPS

```
/var/www/website/
├── server.ps1          # Backend server chính
├── send_email.ps1      # Email helper (dot-sourced bởi server.ps1)
├── .env                # ⚠️ Secrets — KHÔNG commit Git
├── brain.db            # ⚠️ Database — KHÔNG commit Git
├── schema.sql          # Schema khởi tạo DB (có thể commit)
├── website.service     # Systemd service file
├── index.html          # Landing page
├── style.css
├── script.js
├── assets/
├── admin/index.html    # CRM panel
├── leadmagnet/index.html
├── product-1/index.html
├── products/
└── test-pay/
```

---

## 🔄 Quy trình update code lên VPS

```bash
# Trên máy local (Windows):
scp -P 2018 -r . root@103.97.127.180:/var/www/website/

# Hoặc nếu dùng Git:
# Trên VPS:
cd /var/www/website && git pull
systemctl restart ps-website
```

---

## 🗂️ File nên có trong .gitignore

```
.env
brain.db
resend_config.txt
sqlite3.exe
sqlite3_analyzer.exe
sqldiff.exe
sqlite.zip
*.db-shm
*.db-wal
```

---

## ✅ Checklist trước khi deploy

- [ ] File `.env` đã tạo trên VPS với đúng giá trị
- [ ] `brain.db` đã init từ `schema.sql`
- [ ] `pwsh` và `sqlite3` đã cài
- [ ] Nginx config đã trỏ về port 8081
- [ ] Systemd service đã enable và start
- [ ] Domain DNS đã trỏ đúng IP VPS
- [ ] SePay webhook URL đã update thành `https://style.quyetsinh.com/api/sepay-webhook`
