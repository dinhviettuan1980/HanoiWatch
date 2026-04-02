# 🕐 Hanoi Watch Face — Forerunner 955

Mặt đồng hồ Garmin tối, clone từ ảnh thực tế, tối ưu cho **Forerunner 955**:
- Màn hình 260x260px (MIP display)
- Giờ lớn (12h/24h theo cài đặt máy)
- Ngày tháng tiếng Việt (Thứ 5, 2 Thg 4)
- Thời tiết realtime + nhiệt độ °C + "Hanoi"
- Nhịp tim realtime + icon trái tim đỏ + biểu đồ HR
- Bước chân / mục tiêu + vòng cung xanh lá
- % pin + icon pin màu
- Sunrise / sunset

---

## BƯỚC 1 — Cài môi trường (chỉ làm 1 lần)

### 1. Cài Java JDK 11+
→ https://adoptium.net/ → tải **Temurin JDK 11**

### 2. Cài Garmin Connect IQ SDK
1. Vào https://developer.garmin.com/connect-iq/sdk/
2. Tải **Connect IQ SDK Manager**
3. Mở SDK Manager → tải SDK mới nhất (≥7.x)
4. Tab **Devices** → tìm và tải **Forerunner 955**

### 3. Cài VS Code + extension Monkey C
1. https://code.visualstudio.com/
2. Extensions → tìm **"Monkey C"** (by Garmin) → Install

---

## BƯỚC 2 — Tạo Developer Key (1 lần duy nhất)

Trong VS Code:
- `Ctrl+Shift+P` → gõ `Monkey C: Generate Developer Key`
- Chọn thư mục lưu → VS Code tự nhớ key này

---

## BƯỚC 3 — Build

1. Mở VS Code → **File → Open Folder** → chọn thư mục `HanoiWatchFace`
2. `Ctrl+Shift+P` → `Monkey C: Build Current Project`
3. Chọn device: **fr955**
4. File `.prg` xuất hiện trong thư mục `bin/`

**Test trước trên máy tính (khuyến nghị):**
- `Ctrl+Shift+P` → `Monkey C: Run in Simulator` → chọn **fr955**
- Simulator hiện ra — xem mặt đồng hồ ngay trên màn hình

---

## BƯỚC 4 — Cài lên đồng hồ

### Cách USB (đơn giản nhất):
1. Cắm FR955 vào máy tính bằng cáp USB
2. Mở thư mục đồng hồ như USB drive
3. Copy file `bin/HanoiWatchFace.prg` vào:
   ```
   GARMIN/Apps/
   ```
4. Rút cáp an toàn (Safely Remove)

### Chọn mặt đồng hồ trên FR955:
1. Nhấn giữ nút **UP** (nút trên cùng bên trái)
2. Chọn **Watch Face** (Mặt đồng hồ)
3. Tìm **Hanoi Watch Face** → nhấn **Select**

---

## Lỗi thường gặp

| Lỗi | Cách sửa |
|-----|----------|
| `Symbol not found: FONT_NUMBER_THAI_HOT` | Thay bằng `FONT_NUMBER_HOT` trong `HanoiWatchFaceView.mc` |
| `Device fr955 not installed` | Mở SDK Manager → Devices → tải FR955 |
| Thời tiết hiện `---` | Mở Garmin Connect app → bật chia sẻ vị trí + kết nối Bluetooth với điện thoại |
| Simulator không mở | Kiểm tra Java JDK đã cài chưa |

---

## Cấu trúc file

```
HanoiWatchFace/
├── manifest.xml                  ← Khai báo fr955, permissions
├── monkey.jungle                 ← Build config
├── source/
│   ├── HanoiWatchFaceApp.mc      ← Entry point
│   └── HanoiWatchFaceView.mc     ← Toàn bộ logic vẽ (file chính)
├── resources/
│   ├── strings/strings.xml
│   └── drawables/drawables.xml
└── README.md
```
