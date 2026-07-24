# WinAuto — Tự động cài lại Windows từ xa

Hệ thống unattended install Windows, thiết kế cho **remote** — an toàn, chỉ format C:, giữ nguyên D: và các partition khác.

**Tự động hoàn toàn**:
Cài Windows 10/11 Home → Cài driver mạng → Kết nối WiFi → Cài AnyDesk → Gửi Telegram

---

## 📁 Cấu trúc thư mục

```
WinAuto/
├── prepare.ps1                    ← 🚀 SCRIPT CHÍNH — chạy file này
├── Readme.md                     ← File này
├── autounattend_win10.xml        ← Template Win 10 Home
├── autounattend_win11.xml        ← Template Win 11 Home (bypass TPM)
└── Scripts/
    ├── SetupComplete.cmd         ← Entry point sau cài xong
    ├── setup-anydesk.ps1         ← Script setup (driver → WiFi → AnyDesk → Telegram)
    ├── WlanProfile.xml           ← WiFi profile (tên + mật khẩu)
    ├── 3dpnet.exe                ← Driver mạng offline
    ├── AnyDesk.exe               ← ⚠️ CẦN TỰ COPY installer vào đây
    └── AnyDesk.lnk               ← Shortcut AnyDesk cho Desktop
```

---

## 🚀 Cách sử dụng (Chỉ 3 bước)

### Bước 1: Chuẩn bị (làm 1 lần)

1. **Copy AnyDesk.exe** installer thực (~5MB) vào thư mục `Scripts/`
2. **Sửa WiFi** trong `Scripts/WlanProfile.xml` nếu cần:
   ```xml
   <name>TÊN_WIFI</name>                    <!-- Dòng 3 + 5 -->
   <keyMaterial>MẬT_KHẨU_WIFI</keyMaterial> <!-- Dòng 19 -->
   ```
3. **Sửa Telegram** trong `Scripts/setup-anydesk.ps1` (3 dòng đầu):
   ```powershell
   $token    = "BOT_TOKEN"
   $chatId   = "CHAT_ID"
   $password = "MẬT_KHẨU_ANYDESK"
   ```

### Bước 2: Chuyển file đến máy xa

- Remote vào máy (qua AnyDesk/TeamViewer hiện tại)
- Copy thư mục `WinAuto/` sang máy xa
- Copy (hoặc download) file ISO Windows lên máy xa

### Bước 3: Chạy script

Mở **PowerShell (Admin)** trên máy xa, chạy:

```powershell
cd C:\WinAuto
.\prepare.ps1
```

Script sẽ:
1. ❓ Hỏi bạn cài Win 10 hay Win 11
2. 🔍 Tự tìm file ISO trên máy
3. 📊 Hiển thị layout ổ cứng — chỗ nào bị format, chỗ nào giữ nguyên
4. ✅ Xác nhận lần cuối (gõ `GO` để bắt đầu)
5. 📦 Tự giải nén ISO, copy scripts, sinh autounattend.xml
6. 🚀 Chạy Windows Setup

Sau đó **mất kết nối remote** (bình thường!) → chờ 15-30 phút → 📱 nhận Telegram.

---

## 🔒 Chế độ an toàn

| Thành phần | Ảnh hưởng |
|------------|-----------|
| Partition C: (Windows) | ❌ **Bị format** — cài Windows mới |
| Partition D:, E:, ... | ✅ **Giữ nguyên** — không bị đụng |
| Ổ cứng thứ 2 (Disk 1+) | ✅ **Giữ nguyên** — không bị đụng |

Script tự phát hiện C: nằm ở Disk mấy, Partition mấy và chỉ cài vào đúng chỗ đó.

---

## 📋 Checklist

- [ ] File `AnyDesk.exe` (installer thực) trong `Scripts/`
- [ ] WiFi profile `WlanProfile.xml` đúng tên + mật khẩu
- [ ] Telegram bot token + chat ID đúng
- [ ] File ISO Windows đã có trên máy xa
- [ ] Chạy PowerShell với quyền **Administrator**

---

## 📝 Log & Debug

Sau khi cài xong, kiểm tra log:
```
C:\WinAuto_setup.log
```

Log ghi chi tiết: cài driver, WiFi, AnyDesk, Telegram — mỗi bước có timestamp.

---

## ⚠️ Lưu ý

- **Chỉ partition C: bị format** — dữ liệu trên D: an toàn
- Generic Product Key chỉ dùng để cài, **không kích hoạt** Windows
- Win 11 đã có bypass TPM/SecureBoot/RAM
- Nếu không nhận Telegram sau 30 phút → WiFi profile có thể sai → cần ra tận nơi check
- File `AnyDesk.lnk` là shortcut, **không phải installer**

---

## 🔒 TODO: Kế hoạch Bảo vệ & Quản lý Script (Sau khi hoàn tất)

- [ ] **Đóng gói thành EXE:** Dùng `PS2EXE` chuyển `prepare.ps1` thành file thực thi duy nhất để giấu mã nguồn và các file XML.
- [ ] **Tích hợp giới hạn (Time-bomb / Telegram 2FA):** 
  - Đặt hạn sử dụng cứng (VD: 3 tháng) vào file EXE.
  - *Hoặc* tích hợp cơ chế báo cáo & chờ duyệt OTP qua Telegram Bot trước khi cho phép chạy `setup.exe`.
- [ ] **Thêm Watermark:** Khẳng định quyền tác giả trong banner của tool.
