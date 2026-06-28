# Fortran Fortress 🏰

Dự án mẫu **tính toán khoa học** bằng Fortran hiện đại, mô phỏng hiệu ứng đảo nhiệt đô thị (Urban Heat Island - UHI) tại TP.HCM.

## Yêu cầu

- `gfortran` (khuyên dùng GCC 16)
- `fpm` (Fortran Package Manager >= 0.13.0)

## Cấu trúc

```
fortran-fortress/
├── app/
│   └── main.f90          # Chương trình chính
├── src/
│   ├── kinds.f90         # Định nghĩa các kiểu dữ liệu (wp=real64)
│   ├── constants.f90     # Các hằng số vật lý và giới hạn xác thực
│   └── grid.f90          # Cấu trúc dữ liệu lưới (cell, grid_t, coeffs_t)
├── test/
│   └── main.f90          # Thư mục chứa unit test (test-drive)
├── fpm.toml              # Manifest cấu hình build và dependency
└── README.md
```

## Cách dùng (fpm workflow)

```bash
fpm build    # Biên dịch dự án (mặc định là debug profile)
fpm run      # Biên dịch và chạy chương trình chính
fpm test     # Chạy unit tests
```

### Flag Profiles

Dự án được cấu hình với 2 profile biên dịch rõ ràng trong `fpm.toml`. Cả hai đều tuân thủ chuẩn F2018 và cấm các cờ tối ưu hóa có thể phá vỡ chuẩn IEEE (như `-ffast-math`).

1. **Debug (mặc định)**: Dùng để phát triển, bật tối đa các cờ cảnh báo và kiểm tra mảng.
   *Fallback command:* `fpm build --flag "-g -O0 -std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -finit-real=snan"`

2. **Release**: Dùng khi cần hiệu năng, tối ưu hóa an toàn ở mức `-O2`.
   *Fallback command:* `fpm build --profile release --flag "-O2 -std=f2018 -fimplicit-none -Wall"`
