# Secure NFC Wallet Application

Ứng dụng ví điện tử NFC bảo mật kết hợp giữa **Node.js/Express Backend (Prisma ORM & SQLite)** và **Flutter Frontend Mobile App**.

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Dự Án Cho Người Mới Clone Từ GitHub

Khi clone dự án từ GitHub về máy cá nhân, bạn cần thực hiện thiết lập cho cả **Backend (Máy chủ)** và **Frontend (Ứng dụng di động Flutter)**.

---

### 1. Cấu Hình & Chạy Backend Server (`backend/`)

#### **Bước 1: Di chuyển vào thư mục backend và cài đặt thư viện**
```bash
cd backend
npm install
```

#### **Bước 2: Tạo file biến môi trường `.env`**
Tạo file `.env` nằm trong thư mục `backend/` (hoặc copy từ `.env.example`):
```env
PORT=3000
JWT_SECRET=supersecretnfcwalletkey123
DATABASE_URL="file:./dev.db"
```

#### **Bước 3: Khởi tạo Cơ sở dữ liệu SQLite (Prisma DB)**
Chạy lệnh sau để tự động tạo file CSDL `dev.db` và đồng bộ schema:
```bash
npx prisma db push
```

*(Tùy chọn) Chạy seed dữ liệu mẫu ban đầu:*
```bash
node seeders/init.js
```

#### **Bước 4: Khởi chạy Backend Server**
```bash
npm run dev
# Hoặc: npm start
```
Máy chủ sẽ chạy tại địa chỉ: `http://localhost:3000`

---

### 2. Cấu Hình & Chạy Frontend App (`frontend/`)

#### **Bước 1: Di chuyển vào thư mục frontend và lấy thư viện Flutter**
Open a new terminal window / tab:
```bash
cd frontend
flutter pub get
```

#### **Bước 2: Kiểm tra cấu hình địa chỉ IP máy chủ API (`api_config.dart`)**
Mở file `frontend/lib/services/api_config.dart`:
- **Chạy trên Android Emulator**: Giữ nguyên `http://10.0.2.2:3000`.
- **Chạy trên Web / iOS Simulator / Desktop**: Giữ nguyên `http://localhost:3000`.
- **Chạy trên Điện thoại Android thật (qua Wi-Fi/USB)**: Đổi `10.0.2.2` hoặc `localhost` thành IP máy tính cá nhân của bạn trong mạng LAN (Ví dụ: `http://192.168.1.5:3000`).

#### **Bước 3: Chạy ứng dụng Flutter**
```bash
flutter run
```

---

## 🛠 Cấu Trúc Dự Án

```
mobile-scan-card/
├── backend/                  # Node.js Express REST API server
│   ├── prisma/               # Prisma Schema & CSDL SQLite (dev.db)
│   ├── routes/               # API Routes (auth, cards, transactions, user)
│   ├── middleware/           # JWT Authentication Middleware
│   ├── seeders/              # Initial database seed scripts
│   └── index.js              # Entrypoint backend server
│
├── frontend/                 # Flutter Mobile Client
│   ├── lib/
│   │   ├── models/           # Data Models
│   │   ├── providers/        # State Management (AuthProvider, ThemeProvider, LocaleProvider)
│   │   ├── screens/          # Screens (Home, Wallet, Login, Register, Profile, Settings)
│   │   └── services/         # API, NFC, Backup, Haptic services
│   └── pubspec.yaml
│
└── README.md
```

---

## 🔐 Các Tính Năng Nổi Bật

- **Phân quyền & Cách ly dữ liệu**: Mỗi tài khoản chỉ truy cập và quản lý các thẻ/giao dịch của riêng mình.
- **NFC Tag Scanning**: Đọc và tích hợp thẻ NFC trực tiếp vào ví.
- **Mã hóa AES-256**: Bảo mật dữ liệu sao lưu (Backup / Import).
- **Khóa tự động (Auto-Lock)**: Khóa ứng dụng khi không thao tác bằng PIN 6 chữ số.
- **Hỗ trợ Đa ngôn ngữ & Giao diện Tối (Dark Theme)**.
