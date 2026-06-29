# Fortran Fortress 🏰 — Mô phỏng Đảo nhiệt Đô thị TP.HCM

Dự án **tính toán khoa học** bằng Fortran hiện đại, mô phỏng hiệu ứng **đảo nhiệt đô thị**
(Urban Heat Island — UHI) trên lưới 2D các quận/khu vực của TP. Hồ Chí Minh. Mỗi ô lưới mang
các tham số thực tế (nhiệt độ không khí, độ ẩm, khoảng cách tới sông/biển, mật độ xây dựng,
mật độ cây xanh, đô thị/nông thôn). Chương trình tính **nhiệt độ cảm nhận** (feels-like) cho
từng ô, quét qua **chu kỳ ngày–đêm** và các **kịch bản what-if**, rồi xuất **CSV** để vẽ biểu
đồ bằng công cụ ngoài, kèm một **bản tóm tắt console** dễ đọc.

> **Mục tiêu khoa học (core value):** bản đồ nhiệt phải **đáng tin về mặt định tính** — ô đô
> thị dày đặc, ít cây phải nóng hơn ô xanh / ven sông / nông thôn cho **cùng một nền thời
> tiết**, và **khoảng cách nhiệt đô thị–nông thôn ban đêm phải lớn hơn giữa trưa**. Mô hình
> mang tính *minh hoạ*, không phải dự báo: ưu tiên hành vi định tính đúng hơn là độ chính xác
> khí tượng.

---

## Tổng quan luồng chạy

Một lần `fpm run` chạy trọn pipeline, không có bước thủ công trung gian:

```
load (coeffs.nml + hcmc_districts.csv)
   → physics (feels-like mỗi ô)
      → diurnal (4 mốc thời gian)
         → scenarios (baseline + add_trees + more_concrete)
            → results.csv  +  console summary
```

---

## Yêu cầu môi trường

| Thành phần | Phiên bản | Ghi chú |
|------------|-----------|---------|
| `gfortran` | GCC 16.x (Homebrew) | Hỗ trợ đầy đủ F2018 |
| `fpm` (Fortran Package Manager) | ≥ 0.13.0 | Tự giải thứ tự biên dịch module |
| Nền tảng | macOS / Apple Silicon | Dùng `-mcpu=native`, **không** `-march=native` |

Phụ thuộc dev duy nhất là [`test-drive`](https://github.com/fortran-lang/test-drive) `v0.6.0`,
được `fpm` tự kéo về khi chạy `fpm test`. Không cần thư viện ngoài nào khác.

---

## Build · Run · Test

```bash
fpm build    # Biên dịch
fpm run      # Chạy: sinh results.csv + in tóm tắt console
fpm test     # Chạy toàn bộ unit test (test-drive)
```

### Cờ biên dịch nghiêm ngặt (khuyên dùng khi phát triển)

> ⚠️ **fpm 0.13.0 từ chối khối `[profiles.*.gfortran]` trong manifest.** Áp cờ dev nghiêm ngặt
> qua `--flag` chứ **không** qua manifest profile:

```bash
fpm run  --flag "-std=f2018 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra -finit-real=snan"
fpm test --flag "-std=f2018 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra -finit-real=snan"
```

- `-fcheck=all` — bắt lỗi vượt biên mảng lúc chạy.
- `-ffpe-trap=invalid,zero,overflow` — NaN/Inf crash ngay tại nguồn, không lan vào CSV.
- `-finit-real=snan` — lộ biến chưa khởi tạo ngay lập tức.
- `-Wall -Wextra` — cảnh báo biến thừa/chưa dùng/ép kiểu ngầm.

Chạy hiệu năng dùng `-O2` (đủ cho lưới cỡ quận); tránh `-O3 -ffast-math` (phá IEEE, có thể
che/sinh NaN — làm hỏng tính "số liệu đáng tin").

---

## Đầu ra

### 1. `results.csv` (OUT-01) — deterministic, dễ vẽ

Ghi đè mỗi lần chạy, ở thư mục gốc. **1 dòng header + 168 dòng dữ liệu** (14 quận có dữ liệu ×
3 kịch bản × 4 mốc giờ), thứ tự cố định `scenario → timestep → i → j` nên **byte-reproducible**.
Dấu thập phân luôn là `.` (không phụ thuộc locale), format width-free nên không bao giờ tràn
thành `*****`.

| Cột | Ý nghĩa |
|-----|---------|
| `i`, `j` | toạ độ ô trên lưới 8×10 |
| `name` | tên quận/khu vực |
| `time_label` | `morning` / `afternoon` / `evening` / `predawn` |
| `scenario` | `baseline` / `add_trees` / `more_concrete` |
| `t_air` | nhiệt độ không khí **đầu vào** của ô (cột tham chiếu) |
| `base_t` | nhiệt độ nền đồng nhất mô hình thực dùng ở mốc giờ đó |
| `feels_c` | nhiệt độ cảm nhận tính được |
| `uhi_offset_c` | offset UHI **đã áp** ở mốc đó = `m(t)·ΔT_UHI` |

> `t_air` chỉ là cột tham chiếu — **không** được đưa vào phép tính feels (xem D-03/WR-01 trong
> [DECISION_LOGS.md](DECISION_LOGS.md)). Mang cả `t_air` lẫn `base_t` giúp người đọc thấy
> feels-like neo vào `base_t`, tránh hiểu nhầm "feels < t_air".

### 2. Console summary (OUT-02)

- **Bảng baseline mỗi mốc giờ:** ô nóng nhất (tên + °C), ô mát nhất (tên + °C), feels-like
  trung bình thành phố, và khoảng cách đô thị–nông thôn.
- **Recap kịch bản:** Δ feels-like trung bình thành phố của `add_trees` và `more_concrete`.

Console chỉ in feels-like, **không** in `t_air` cạnh feels (D-08).

---

## Cấu trúc dự án

```
fortran-fortress/
├── app/
│   └── main.f90          # Driver: orchestrate load → physics → diurnal → scenarios → output
├── src/
│   ├── kinds.f90         # wp = real64 (iso_fortran_env)
│   ├── constants.f90     # giới hạn validation + hệ số Rothfusz + c_to_f/f_to_c
│   ├── grid.f90          # type(cell), grid_t, coeffs_t, allocate_grid
│   ├── heat_index.f90    # heat_index_f — Steadman/Rothfusz hai nhánh
│   ├── uhi.f90           # uhi_offset — offset UHI cộng tính
│   ├── feels.f90         # feels_like_c — ghép heat index + UHI, có sàn
│   ├── diurnal.f90       # NT=4, diurnal_m, diurnal_base, time_label
│   ├── scenario.f90      # scenario_t, apply_scenario (copy-then-mutate)
│   ├── summary.f90       # urban_rural_gap, city_average, hottest, coolest
│   └── io.f90            # read_coeffs_nml, read_grid_csv, write_results_csv, real2str
├── test/                 # unit test test-drive (heat index, uhi, ordering, diurnal, gap, io, output...)
├── data/
│   ├── coeffs.nml        # hệ số mô hình (sửa được, không cần biên dịch lại)
│   └── hcmc_districts.csv# lưới mầm 14 quận HCMC
├── fpm.toml
├── README.md             # (file này)
├── ARCHITECTURE.md       # tài liệu kỹ thuật cốt lõi + sơ đồ + trade-off
└── DECISION_LOGS.md      # nhật ký mọi quyết định (D-01 … D-XX)
```

---

## Các công thức sử dụng

Tất cả kernel vật lý là `elemental pure`, tính bằng `real64`. Ký hiệu: `T` nhiệt độ, `RH` độ ẩm
tương đối (%), `_f` = °F, `_c` = °C.

### 1. Heat index — `heat_index_f(T_f, RH)` (°F)

Hai nhánh theo ngưỡng ~26.7 °C (80 °F):

**Bước Steadman (luôn tính trước):**
```
HI = 0.5·( T_f + 61 + (T_f − 68)·1.2 + RH·0.094 )
HI = (HI + T_f) / 2
```

**Nếu `HI ≥ 80 °F` → hồi quy Rothfusz:**
```
HI = c1 + c2·T + c3·RH + c4·T·RH + c5·T² + c6·RH²
        + c7·T²·RH + c8·T·RH² + c9·T²·RH²
```
với `c1=-42.379, c2=2.04901523, c3=10.14333127, c4=-0.22475541, c5=-0.00683783,
c6=-0.05481717, c7=0.00122874, c8=0.00085282, c9=-0.00000199`.

**Hiệu chỉnh biên** (giống NWS): trừ một lượng khi `RH<13%` và `80≤T≤112`; cộng một lượng khi
`RH>85%` và `80≤T≤87`. Ngưỡng 80 °F đảm bảo ô mát/ban đêm không cho feels thấp hơn nhiệt độ
không khí.

### 2. Offset UHI — `uhi_offset(...)` (°C, cộng tính, một "ngân sách" duy nhất)

```
U     = 1 nếu là đô thị, ngược lại 0
Wprox = exp( −water_km / d0 )                 # gần nước → Wprox→1 → mát hơn
ΔT_UHI = w_build·building + w_urban·U − w_tree·tree − w_water·Wprox
```

Mật độ xây dựng & lớp đô thị **làm nóng**; cây xanh & gần nước **làm mát**. `d0` là khoảng suy
giảm ảnh hưởng nước (mặc định 2.5 km).

### 3. Nhiệt độ cảm nhận — `feels_like_c(...)` (°C)

```
t_adj = base_t + m(t)·ΔT_UHI
feels = max( F→C( heat_index_f( C→F(t_adj), RH ) ),  t_adj )
```

`max(...)` là **sàn**: feels không bao giờ thấp hơn nhiệt độ đã hiệu chỉnh UHI. Lưu ý feels neo
vào `base_t` (nền đồng nhất), **không** vào `t_air` của ô → tránh đếm trùng hiệu ứng UHI.

### 4. Chu kỳ ngày–đêm

Bốn mốc giờ `NT=4`: morning, afternoon, evening, predawn. Mỗi mốc có:
- `base(t)` — nhiệt độ nền **đồng nhất** toàn thành phố.
- `m(t)` — hệ số nhân scale offset UHI.

Vì `base(t)` đồng nhất nên nó **triệt tiêu** trong hiệu đô thị–nông thôn → khoảng cách do
`m(t)·ΔT_UHI` gánh. `m` lớn nhất lúc predawn (1.0) và nhỏ nhất giữa trưa (0.3) ⇒ **gap ban đêm
> gap giữa trưa** dù giữa trưa nóng tuyệt đối nhất.

### 5. Reductions thống kê — `summary_mod`

```
city_average    = mean( feels | occupied )
urban_rural_gap = mean( feels | urban ∧ occupied ) − mean( feels | rural ∧ occupied )
hottest/coolest = maxloc/minloc( feels, mask = occupied )   → (i,j) + giá trị
```

### 6. Kịch bản — `apply_scenario` (copy-then-mutate, không động baseline)

```
tree'     = clamp( tree     + tree_delta,     0, 1 )
building' = clamp( building + building_delta, 0, 1 )
```
- `baseline`: không đổi.
- `add_trees`: `tree_delta = +0.2`.
- `more_concrete`: `building_delta = +0.2`.

### Hệ số mặc định (`data/coeffs.nml`)

| Nhóm | Giá trị |
|------|---------|
| trọng số UHI | `w_build=3.0, w_urban=1.0, w_tree=2.5, w_water=2.0`, `d0=2.5` |
| `m(t)` | morning `0.5`, afternoon `0.3`, evening `0.8`, predawn `1.0` |
| `base(t)` (°C) | morning `29`, afternoon `33`, evening `30`, predawn `25` |
| delta kịch bản | `add_trees_delta=0.2`, `concrete_delta=0.2` |
| lưới | `nx=8, ny=10` |

Mọi hệ số sửa trong `coeffs.nml` rồi `fpm run` lại — không cần biên dịch lại.

---

## Tài liệu thêm

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — kiến trúc, sơ đồ mermaid, trade-off, tiêu chí chấp
  nhận, lý do cho từng quyết định kỹ thuật.
- **[DECISION_LOGS.md](DECISION_LOGS.md)** — nhật ký toàn bộ quyết định theo thứ tự thời gian
  (D-01 … D-XX).
