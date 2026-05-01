# Hướng dẫn Deploy Website lên Linux VPS

Dự án này sử dụng PowerShell Core làm backend server và SQLite làm cơ sở dữ liệu. Dưới đây là hướng dẫn để đưa dự án này lên một máy chủ Linux (Ubuntu/Debian).

## 1. Cài đặt các thành phần cần thiết trên VPS

### Cài đặt PowerShell Core (pwsh) trên Ubuntu
Chạy các lệnh sau trên terminal của VPS:
```bash
# Cập nhật danh sách gói
sudo apt-get update
# Cài đặt các gói điều kiện
sudo apt-get install -y wget apt-transport-https software-properties-common
# Tải Microsoft repository GPG keys
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
# Đăng ký GPG keys
sudo dpkg -i packages-microsoft-prod.deb
# Cập nhật lại danh sách gói sau khi thêm repo
sudo apt-get update
# Cài đặt PowerShell
sudo apt-get install -y powershell
```

### Cài đặt SQLite3
```bash
sudo apt-get install -y sqlite3
```

## 2. Chuẩn bị mã nguồn

1. Copy toàn bộ thư mục dự án lên VPS (ví dụ để ở `/var/www/website`).
2. Copy file `.env.example` thành `.env` và điền `RESEND_API_KEY`:
   ```bash
   cp .env.example .env
   nano .env
   ```
3. (Tùy chọn) Nếu bạn dùng chung database `brain.db` với một thư mục khác, hãy trỏ đường dẫn tuyệt đối của DB vào biến `DB_PATH` trong file `.env`. Nếu không, hệ thống sẽ mặc định dùng file `brain.db` nằm cùng thư mục.

## 3. Mở Port tường lửa
Server đang chạy ở port `8081` (hoặc tuỳ chỉnh qua `.env`). Đảm bảo bạn đã mở port này:
```bash
sudo ufw allow 8081/tcp
```

## 4. Chạy server bằng Systemd (Khuyên dùng)

Để server tự động chạy ngầm và tự khởi động lại khi sập, hãy dùng file `website.service`:

1. Sửa file `website.service`, đảm bảo đường dẫn trong `ExecStart` và `WorkingDirectory` đúng với thư mục mã nguồn của bạn.
2. Copy file này vào thư mục cấu hình của systemd:
   ```bash
   sudo cp website.service /etc/systemd/system/
   ```
3. Cập nhật lại cấu hình systemd và khởi động dịch vụ:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable website.service
   sudo systemctl start website.service
   ```
4. Kiểm tra trạng thái:
   ```bash
   sudo systemctl status website.service
   ```

Bây giờ bạn có thể truy cập trang web thông qua địa chỉ IP của VPS: `http://<IP_VPS>:8081/`.
