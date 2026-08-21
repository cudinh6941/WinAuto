# WinAuto v2 — Batch On-site Windows Deployment

Hệ thống unattended install Windows phiên bản v2, thiết kế cho **batch on-site deployment** (cài nhiều máy cùng lúc tận nơi) — an toàn, tự động hoàn toàn với cơ chế Phase-based Auto-Resume sau mỗi lần restart.

**Tự động hoàn toàn 9 phases:**
Cài Windows → Driver mạng → Upgrade Pro → Rename + Join Domain → Add Domain User → Tắt BitLocker → Cài Office → Custom Apps → Kaspersky → Finalize.

---

## 📁 Cấu trúc thư mục

```text
WinAuto/
├── prepare.ps1                    ← 🚀 SCRIPT CHÍNH — chạy file này trên mỗi máy
├── config.json                    ← ⚙️ File cấu hình chung cho TẤT CẢ các máy
├── Readme.md                      
├── autounattend_win10.xml         ← Template Win 10 (Home)
├── autounattend_win11.xml         ← Template Win 11 (Home)
│
├── Scripts/
│   ├── post-install.ps1           ← Phase Executor (tự chạy sau mỗi lần restart)
│   ├── SetupComplete.cmd          ← Entry point đầu tiên sau khi cài xong Windows
│   ├── 3dpnet.exe                 ← Driver mạng offline
│   │
│   ├── lib/                       ← Thư viện dùng chung
│   │   ├── common.ps1             ← Logging, DPAPI, Reboot Detection, Retry, Dry-Run
│   │   └── network.ps1            ← Xử lý kết nối WiFi / LAN
│   │
│   └── phases/                    ← Các script riêng cho từng phase
│       ├── phase1-drivers.ps1     ← Driver mạng + kết nối WiFi/LAN
│       ├── phase2-upgrade-pro.ps1 ← Upgrade Home → Pro
│       ├── phase3-domain-join.ps1 ← Rename + Join Domain (ghép 2 bước, 1 restart)
│       ├── phase4-domain-user.ps1 ← Add domain user vào local Administrators
│       ├── phase5-bitlocker.ps1   ← Tắt BitLocker
│       ├── phase6-office.ps1      ← Cài Office 365/2016
│       ├── phase7-custom-apps.ps1 ← Cài Custom Apps (Chrome, Zalo, UltraViewer...)
│       ├── phase8-kaspersky.ps1   ← Cài Kaspersky (cuối cùng, tránh block)
│       └── phase9-finalize.ps1    ← Dọn dẹp, Telegram, switch user
│
├── Software/                      ← 📦 Thư mục chứa bộ cài phần mềm
│   ├── Office365/                 ← (Cần có OfficeSetup.exe)
│   ├── Office2016/                ← (Cần có Office2016.iso)
│   ├── Kaspersky/                 ← (Cần có install.bat)
│   └── CustomApps/                ← (Nơi bỏ các file .exe tùy thích)
│
└── Logs/                          ← 📝 Thư mục chứa log cài đặt của từng máy
```

---

## 🚀 Cách sử dụng (Chỉ 2 bước)

### Bước 1: Chuẩn bị chung (Làm 1 lần)

1. Cập nhật file `config.json` với thông tin chung của đợt cài đặt:
   - `testMode`: `true` để test dry-run, `false` khi chạy thật
   - Thông tin WiFi
   - Domain name, OU, DC IP, DNS servers
   - Path trỏ đến bộ cài Office / Kaspersky (trong thư mục `Software/`)
   - Product key để upgrade lên Win Pro
   - Telegram Bot token & Chat ID
2. Chép toàn bộ thư mục `WinAuto/` và file ISO Windows vào một ổ đĩa trên máy cần cài (thường là ổ `D:`). Đảm bảo ISO là bản Home (có thể dùng ISO multi-edition).

### Bước 2: Chạy trên từng máy

Mở **PowerShell (Admin)** trên máy cần cài, chạy:

```powershell
cd D:\WinAuto
.\prepare.ps1
```

Script sẽ yêu cầu bạn nhập 8 thông tin cho riêng máy này:
1. Tên máy tính (Computer Name)
2. Domain username
3. Password của domain username
4. Cài Win 10 hay 11
5. Có cài Kaspersky không? (Y/N)
6. Cài Office 365 hay 2016?
7. Tài khoản dùng để Join Domain
8. Mật khẩu của tài khoản Join Domain

Sau khi nhập xong, nhấn Enter. **Bạn có thể bỏ đi sang máy khác**. Hệ thống sẽ tự động format ổ C: (giữ nguyên ổ Data), cài đặt Windows và tuần tự thực thi 9 phase cài đặt phần mềm & cấu hình hệ thống. Mọi lần restart bắt buộc (như sau khi Join Domain, Rename PC) đều được hệ thống tự động nhận diện và resume.

---

## 🔒 Chế độ an toàn & Bảo mật

| Thành phần | Ảnh hưởng |
|------------|-----------|
| Partition C: (Windows) | ❌ **Bị format** — cài Windows mới |
| Partition D:, E:, ... | ✅ **Giữ nguyên** — không bị đụng |
| Mật khẩu Domain User & Join Domain | 🛡️ **Bảo mật DPAPI** — Được mã hóa an toàn trong `state.json` và chỉ có thể được giải mã trên chính máy đó. Sẽ tự động xóa sau khi cài xong (Phase 9). |

---

## 📋 Cơ chế Auto-Resume & Xử lý Restart

Tool sử dụng cơ chế **Phase-based State Machine** và **Pending Reboot Detection**:
- Trạng thái cài đặt được lưu an toàn tại `D:\WinAuto\state.json`.
- Sau mỗi phase, script kiểm tra Registry xem Windows có đang cần restart không (CBS, Windows Update, File Rename, Computer Name thay đổi).
- Nếu cần, máy tự động Restart. Một Scheduled Task tên `WinAuto_Resume` sẽ tự kích hoạt lại tiến trình ngay khi máy khởi động lên, tiếp tục từ phase chưa hoàn thành.
- Nếu không cần Restart, hệ thống tự động chạy ngay Phase tiếp theo, tối ưu thời gian chờ đợi.
- Khi Phase 9 hoàn tất, toàn bộ State, Auto-Logon và Scheduled Task sẽ bị xóa sạch khỏi máy. Máy restart lần cuối để login trực tiếp vào tài khoản Domain User.

---

## 🧪 Test Mode (Dry-Run)

Set `"testMode": true` trong `config.json` để test flow mà **không thực thi** các lệnh nguy hiểm:
- `Add-Computer`, `Rename-Computer` → chỉ log
- `slmgr`, `DISM` upgrade → chỉ log
- `Disable-BitLocker` → chỉ log
- Installer (Office, Kaspersky, Custom Apps) → chỉ log
- Kết nối mạng, Telegram → **vẫn chạy thật**
- Cơ chế restart/resume → **vẫn chạy thật**

---

## 🔄 Thứ tự Phase (Tối ưu)

| Phase | Nội dung | Restart? |
|-------|----------|----------|
| 1 | 🌐 Driver mạng + Kết nối WiFi/LAN | Có thể |
| 2 | ⬆️ Upgrade Home → Pro | Có thể |
| 3 | 💻 Rename + Join Domain (ghép 2 bước, tiết kiệm 1 restart) | Có |
| 4 | 👤 Add domain user vào local Administrators | Không |
| 5 | 🔒 Tắt BitLocker | Không |
| 6 | 📎 Cài Office 365/2016 | Không |
| 7 | 📦 Custom Apps (Chrome, Zalo, UltraViewer...) | Có thể |
| 8 | 🛡️ Kaspersky (cuối cùng, tránh block installer) | Có thể |
| 9 | 🏁 Finalize: Dọn dẹp, Telegram, switch user | Có (lần cuối) |
