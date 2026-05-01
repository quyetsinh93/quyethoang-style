# Danh sách chuẩn bị Deploy (Deploy Checklist)

## 1. Ngôn ngữ / Framework đang sử dụng
- **Backend:** PowerShell (`server.ps1` chạy HTTP Listener)
- **Frontend:** HTML, CSS, JS thuần (Vanilla)
- **Cơ sở dữ liệu:** SQLite (`brain.db`)

## 2. Các file cần tạo thêm để deploy
- [x] `README.md`: Hướng dẫn deploy chi tiết trên Linux VPS.
- [x] `.env.example`: File mẫu chứa các biến môi trường bảo mật (để không hardcode vào source code).
- [x] `website.service`: File cấu hình để chạy ứng dụng ngầm như một service trên Linux bằng systemd.

## 3. Các thông tin bí mật đang lộ trong code
- [x] **ĐÃ FIX LỘ API KEY:** Trong file `send_email.ps1`, biến `$RESEND_API_KEY` đã được xóa hardcode và chuyển sang đọc từ biến môi trường `$env:RESEND_API_KEY`.

## 4. Danh sách những việc cần chuẩn bị trước khi deploy
- [x] Xóa/ẩn Resend API key khỏi mã nguồn (chuyển sang đọc từ biến môi trường).
- [x] Tạo file `.env.example` chứa danh sách các key cần thiết.
- [x] Viết file `README.md` kèm hướng dẫn cài đặt `PowerShell Core` (pwsh) và `SQLite` trên Linux.
- [x] Viết file cấu hình systemd (`website.service`) để server tự khởi động lại nếu bị sập.
- [ ] Mở port `8081` trên VPS firewall. (Cần thực hiện thủ công trên VPS)
