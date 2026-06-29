# Decision Log — Fortran Fortress (HCMC UHI Simulator)

Nhật ký **mọi quyết định** của dự án, theo **thứ tự thời gian**, đánh số toàn cục `D-01 … D-XX`.

> **Cách đọc.** Mỗi quyết định có ID toàn cục `D-NN`. Cột *ref* giữ ID gốc trong tài liệu
> `.planning` để truy vết: REQ-ID (`GRID-01`…), nhãn pitfall (`A9`, `B2`…), và ID cục bộ theo
> phase (`P2 D-09` = quyết định D-09 *trong* Phase 2 — các ID này reset mỗi phase nên ở đây
> được ánh xạ lại sang D-NN toàn cục). `WR-`/`IN-` là finding từ code review.
> Trùng lặp giữa các tầng (charter → requirements → research → roadmap → phases) được **gộp**
> tại lần xuất hiện sớm nhất; lần tái khẳng định sau ghi "reaffirms D-xx".
>
> **Dòng thời gian:** Project charter → Requirements → Research (stack · architecture · physics ·
> pitfalls) → Roadmap → Phase 1 → Phase 2 → Phase 3 → Phase 4 (gồm review + khắc phục).

---

## Stage 0 — Project Charter (`PROJECT.md`)

**D-01 — Core value: bản đồ nhiệt phải đáng tin về định tính** · *PROJECT.md*
Ô đô thị dày đặc/ít cây phải nóng hơn ô xanh/ven sông/nông thôn, và gap đô thị–nông thôn ban
đêm phải lớn hơn giữa trưa — cho cùng nền thời tiết. **Why:** Nếu pattern không gian sai thì
mọi thứ khác vô nghĩa; đây là tiêu chí thành công bao trùm.

**D-02 — Biểu diễn dạng lưới 2D district-cell** · *PROJECT.md*
Mô hình hoá HCMC như lưới 2D các ô cỡ quận, không phải máy tính điểm hay chuỗi thời gian.
**Why:** Thể hiện rõ nhất pattern UHI theo không gian.

**D-03 — Dữ liệu mầm HCMC thực tế, nạp từ file sửa được** · *PROJECT.md*
Lưới khởi tạo từ các quận HCMC có thật, đọc từ file dữ liệu. **Why:** Quen thuộc, dễ kiểm tra
trực giác, demo thuyết phục, và sửa được không cần biên dịch lại.

**D-04 — Chu kỳ ngày–đêm (đa thời điểm), không phải một snapshot** · *PROJECT.md*
Đánh giá lưới ở nhiều mốc giờ trong ngày. **Why:** Gap UHI ban đêm là kết quả khoa học chữ ký
đáng trưng bày.

**D-05 — So sánh kịch bản what-if trong v1** · *PROJECT.md*
Có baseline + các kịch bản thay thế ("thêm cây" / "thêm bê tông") ngay từ bản đầu. **Why:**
Định lượng "thêm cây → mát bao nhiêu" là payoff minh hoạ chính.

**D-06 — Xuất CSV + tóm tắt console (không đồ hoạ tích hợp)** · *PROJECT.md*
Kết quả ra CSV + summary console; vẽ biểu đồ bằng công cụ ngoài. **Why:** Giữ core Fortran đơn
giản, để người dùng vẽ ở Excel/Python/gnuplot.

**D-07 — Mô hình vật lý: heat-index + offset UHI cộng tính** · *PROJECT.md*
Dùng nhiệt độ cảm nhận (apparent temp) cộng một offset UHI. **Why:** Tham số hoá chuẩn, minh
bạch, khớp các yếu tố đầu vào người dùng nêu.

**D-08 — Build bằng fpm** · *PROJECT.md*
Dùng fpm thay vì Makefile thủ công. **Why:** fpm tự giải thứ tự biên dịch module và cho
`fpm run`/`fpm test` miễn phí.

**D-09 — Fortran hiện đại: free-form, `implicit none`, `real64`, gfortran** · *PROJECT.md*
Ngôn ngữ Fortran hiện đại, idiom hiện đại thay legacy F77. **Why:** Lựa chọn ngôn ngữ của người
dùng cho dự án tính toán khoa học.

**D-10 — Hệ số/dữ liệu nằm trong file config sửa được** · *PROJECT.md*
Tham số district và hệ số mô hình nạp từ file, không hard-code. **Why:** Giữ mô hình quen thuộc,
sửa kịch bản không cần biên dịch lại.

**D-11 — Độ trung thực: minh hoạ, không dự báo** · *PROJECT.md*
Ưu tiên đơn giản + hành vi định tính đúng hơn độ chính xác khí tượng. **Why:** Giá trị của
công cụ là dạy cấu trúc UHI, không phải dự báo.

**D-12 — Nền tảng macOS / Apple Silicon** · *PROJECT.md*
Phát triển/chạy trên macOS Apple Silicon (terminal + VS Code). **Why:** Môi trường người dùng;
chi phối lựa chọn cờ compiler (`-mcpu` thay `-march`).

---

## Stage 1 — Requirements v1 (`REQUIREMENTS.md`)

**D-13 — `GRID-01` Lưới nạp từ file dữ liệu sửa được** · *GRID-01* — reaffirms D-03/D-10.
**Why:** Sửa kịch bản không cần rebuild.

**D-14 — `GRID-02` Bộ thuộc tính ô** · *GRID-02*
Mỗi ô mang: nhiệt độ không khí, độ ẩm tương đối, khoảng cách sông/biển, mật độ xây dựng, mật độ
cây, phân loại đô thị/nông thôn. **Why:** Các driver này map vào tham số hoá UHI chuẩn.

**D-15 — `GRID-03` Archetype HCMC thực tế trong seed** · *GRID-03*
Ship các archetype (District 1 core, khu công nghiệp, công viên, ven biển Can Gio, rìa nông
thôn). **Why:** Cho các "đối chứng" nóng/mát tự nhiên, pattern kiểm tra được.

**D-16 — `GRID-04` Toàn bộ hệ số nằm trong config** · *GRID-04* — reaffirms D-10.
**Why:** Minh bạch như một tính năng; mô hình tune được.

**D-17 — `HEAT-01` Nhiệt độ cảm nhận theo từng ô** · *HEAT-01*
Tính apparent temp từ nhiệt độ không khí + độ ẩm. **Why:** HCMC nóng ẩm nên feels ≠ air temp;
bỏ độ ẩm là sai khí tượng.

**D-18 — `HEAT-02` Guard miền hợp lệ heat-index (Steadman ↔ Rothfusz)** · *HEAT-02*
Steadman trung bình dưới ~26.7 °C (80 °F), Rothfusz tại/trên ngưỡng → ô đêm mát không cho feels
thấp hơn air temp. **Why:** Rothfusz vô hiệu dưới ngưỡng và đêm HCMC nằm sát mép dưới.

**D-19 — `UHI-01` Cấu trúc dấu của offset UHI cộng tính** · *UHI-01*
Mật độ xây dựng/lớp đô thị **nâng** feels; mật độ cây/gần nước **hạ** feels. **Why:** Chính là
pattern không gian mà mô hình tồn tại để thể hiện.

**D-20 — `UHI-02` Thứ tự đơn điệu là test chủ đạo** · *UHI-02*
Cùng nền thời tiết, ô đô thị dày đặc ít cây phải xếp nóng hơn ô xanh/ven sông/nông thôn, có test
tự động. **Why:** Kiểm tra đúng-sai chủ đạo cho core value.

**D-21 — `TIME-01` Đánh giá đa thời điểm trong ngày** · *TIME-01* — reaffirms D-04.
**Why:** Một snapshot giấu mất kết quả gap khuếch đại ban đêm.

**D-22 — `TIME-02` Invariant gap đêm > trưa + test tự động** · *TIME-02*
Gap đô thị–nông thôn ban đêm phải lớn hơn giữa trưa, kiểm bằng assertion `gap_night >
gap_afternoon`. **Why:** Tái hiện đỉnh gap ban đêm là payoff khoa học; đảo nó là phá core value.

**D-23 — `SCEN-01` Kịch bản với baseline bất biến** · *SCEN-01*
Chạy baseline + ≥1 "thêm cây" + ≥1 "thêm bê tông" mà không sửa lưới baseline. **Why:** So sánh
apples-to-apples cần baseline nguyên vẹn.

**D-24 — `SCEN-02` Delta theo ô và trung bình thành phố** · *SCEN-02*
Báo cáo thay đổi nhiệt theo từng ô và trung bình thành phố so với baseline. **Why:** Định lượng
"+X cây → −Y °C".

**D-25 — `OUT-01` Schema CSV deterministic** · *OUT-01*
Một dòng / ô × timestep × scenario, thứ tự cột cố định. **Why:** Hợp đồng đầu ra ổn định,
máy-đọc-được cho vẽ ngoài.

**D-26 — `OUT-02` Nội dung tóm tắt console** · *OUT-02*
In ô nóng/mát nhất, feels trung bình thành phố, gap đô thị–nông thôn theo từng timestep. **Why:**
Yêu cầu nêu rõ; đồng thời là smoke test.

**D-27 — Hoãn `REFN-01..05` sang v2** · *REFN-01..05*
Hoãn: humidex toggle, suy giảm liên tục theo khoảng cách nước, đường cong diurnal cosine, thêm
district/archetype, runs theo mùa. **Why:** Chưa cần cho v1; chỉ thêm sau khi mô hình 5-archetype
được kiểm chứng.

**D-28 — Anti-feature (ngoài phạm vi)** · *REQUIREMENTS.md / PROJECT.md (Out of Scope)*
Loại trừ: CFD/3D đầy đủ, dự báo thời tiết, nạp API thời tiết real-time, độ phân giải dưới-quận,
GUI/web/đồ hoạ tích hợp, trường gió-mưa advection, hiệu chỉnh chính xác theo trạm đo. **Why:** Mỗi
cái mâu thuẫn mục tiêu minh hoạ/minh bạch/tự-chứa hoặc ngụ ý độ chính xác dự báo mà mô hình từ
chối; gió biển được xấp xỉ qua số hạng gần-nước.

---

## Stage 2 — Research: Stack (`research/STACK.md`)

**D-29 — Compiler gfortran GCC 16.1.0** · *STACK.md*
**Why:** Đã cài/kiểm chứng; compiler Fortran free de-facto, runtime check mạnh, diagnostics tốt.

**D-30 — Chuẩn ngôn ngữ F2018 (`-std=f2018`)** · *STACK.md*
Không phụ thuộc tính năng F2023. **Why:** GCC 16 hỗ trợ đầy đủ; F2023 còn lệch giữa các compiler.

**D-31 — fpm là driver build/test/run (Makefile fallback, tránh CMake)** · *STACK.md* — refines D-08.
**Why:** fpm tự suy thứ tự biên dịch module; CMake thừa ở quy mô này.

**D-32 — Kind di động qua `iso_fortran_env` (`real64`)** · *STACK.md*
Một module kind (`wp = real64`), không dùng `kind=8` magic. **Why:** Một "núm" độ chính xác,
tự-mô-tả, khớp ràng buộc real64.

**D-33 — Input hai tầng: namelist (config) + bảng delimited (lưới), không thư viện parse** ·
*STACK.md* **Why:** Có sẵn trong ngôn ngữ, sửa tay được, zero code parse, thoả "sửa không rebuild".

**D-34 — CSV bằng formatted `write` width-free, không thư viện** · *STACK.md* (= A9)
`F0.x`/`g0`, dấu `.`, có header. **Why:** Viết CSV là một câu lệnh; width-free tránh `*****`;
thư viện chỉ là gánh nặng.

**D-35 — Không thư viện ngoài cho v1 (chỉ intrinsics)** · *STACK.md*
Dùng `sum`/`maxval`/`maxloc`/`minloc`/`count`; bỏ fortran-stdlib. **Why:** Intrinsics đủ dùng;
dependency thêm chi phí build/CI vô ích ở quy mô này.

**D-36 — Testing: test-drive 0.6.0 (dưới fpm dev-deps; tránh veggies)** · *STACK.md*
**Why:** Standard-Fortran-only, ít ma sát; veggies nặng nề thừa thãi.

**D-37 — Bộ cờ gfortran dev/debug nghiêm ngặt** · *STACK.md*
`-g -O0 -std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace
-ffpe-trap=invalid,zero,overflow -finit-real=snan`. **Why:** Bắt lỗi biên/shape, NaN/Inf tại
nguồn, biến chưa khởi tạo — correctness-first cho người học.

**D-38 — Bộ cờ release `-O2` (không `-O3`/`-ffast-math`; `-mcpu` không `-march`)** · *STACK.md*
**Why:** `-O2` quá đủ cho lưới nhỏ; `-O3`/`-ffast-math` hại tái lập FP; `-march` là idiom x86 sai
trên aarch64.

**D-39 — Không OpenMP trong v1** · *STACK.md*
**Why:** Lưới cỡ quận chỉ vài micro-giây; song song thêm rủi ro race + output không tất định, lợi
ích bằng 0.

---

## Stage 3 — Research: Architecture (`research/ARCHITECTURE.md`)

**D-40 — Kiến trúc batch-pipeline: driver mỏng trên stack module phân tầng acyclic** ·
*ARCHITECTURE.md* (read once → sweep kernels → write → exit). **Why:** Hình dạng idiom của
pipeline khoa học batch trong Fortran hiện đại; rõ và test được.

**D-41 — Phân tầng module acyclic, foundation-first (thứ tự build)** · *ARCHITECTURE.md*
`kinds → constants → grid → physics → orchestration → io → main`, `use` chỉ hướng xuống. **Why:**
Compiler cần `.mod` của module trước user của nó; đồ thị acyclic đảm bảo thứ tự build hợp lệ.

**D-42 — Một module một file (mười module có tên)** · *ARCHITECTURE.md*
**Why:** Ánh xạ file↔module là chỉ dẫn điều hướng; giữ đồ thị phụ thuộc dễ đọc, rebuild tối thiểu.

**D-43 — Kernel vật lý `elemental pure`, không I/O / không state** · *ARCHITECTURE.md*
**Why:** Broadcast trên array thành phần của lưới, vectorize, test đơn vị dễ; I/O chỉ ở io_mod +
driver.

**D-44 — `type(cell)` + lưới allocatable (AoS), cấp phát một lần** · *ARCHITECTURE.md* (= A8)
Sized lúc chạy từ file. **Why:** AoS khớp input một-dòng-một-ô và rõ ràng; penalty cache không
đáng ở quy mô quận; cấp phát-một-lần tránh rò rỉ/double-free.

**D-45 — Scenario/timestep là vòng lặp ngoài, copy-then-mutate** · *ARCHITECTURE.md*
Áp mỗi scenario lên bản sao của baseline bất biến. **Why:** Tách "cái ta thay đổi" khỏi "vật lý",
giữ baseline nguyên vẹn, scenario độc lập.

**D-46 — Xử lý lỗi bằng status-flag trong io_mod (chỉ driver abort)** · *ARCHITECTURE.md*
Routine I/O/parse trả `iostat`/`iomsg`, không `stop`. **Why:** I/O test được; chính sách abort
nằm một chỗ.

**D-47 — Không state toàn cục mutable (thread qua `intent`)** · *ARCHITECTURE.md*
**Why:** Giữ chương trình tham chiếu-trong-suốt và test được.

**D-48 — Layout thư mục src/test/data; gitignore build/output** · *ARCHITECTURE.md*
**Why:** Tách input vs sinh ra, giữ cây nguồn sạch, thoả "sửa data không rebuild".

**D-49 — Phong cách whole-array/intrinsic thay vòng lặp thủ công** · *ARCHITECTURE.md*
VD gap = `sum(...,mask)/count(...)`. **Why:** Ít code, ít bug, compiler tối ưu.

---

## Stage 4 — Research: Physics & Features (`research/FEATURES.md`, `SUMMARY.md`)

**D-50 — Feels-like chính = NWS Steadman→Rothfusz heat index** · *FEATURES.md*
Humidex để dành như config toggle (REFN-01). **Why:** "Feels-like" được công nhận nhất; humidex
(vật lý nhiệt đới tốt hơn) hoãn lại.

**D-51 — Tính trong °F (hệ số canonical), trình bày °C** · *FEATURES.md / SUMMARY.md*
Hồi quy Rothfusz chạy °F với hệ số công bố, đổi °C↔°F ở biên. **Why:** Trộn hệ °C/°F là lỗi kinh
điển; giữ hệ số canonical °F.

**D-52 — Offset UHI cộng tính (không nhân), một ngân sách °C** · *FEATURES.md* (= B3)
`ΔT = m(t)·(w_build·B + w_urban·U − w_tree·V − w_water·Wprox)`, rồi `feels =
HeatIndex(T_base+ΔT, RH)`. **Why:** Mỗi driver đóng góp °C diễn giải được — minh bạch hơn chính
xác cho công cụ dạy học.

**D-53 — Số hạng làm mát theo khoảng cách nước `Wprox = exp(−d/d0)`** · *FEATURES.md*
`d0` tunable (~2–3 km). **Why:** Làm ô ven sông/biển mát rõ rệt, xấp xỉ ngầm hiệu ứng gió biển.

**D-54 — Hệ số nhân diurnal `m(t)` gánh cái gap** · *FEATURES.md* (= B2)
Nhỏ giữa trưa (~0.3), cực đại pre-dawn (~1.0); qua lookup table (cosine để sau). **Why:** Air
temp đỉnh buổi chiều nhưng gap phải đỉnh ban đêm; offset gánh cái gap.

**D-55 — Trọng số khởi tạo minh hoạ (chưa hiệu chỉnh), target gap đêm 3–8 °C** · *FEATURES.md*
~`w_build 3.0, w_urban 1.0, w_tree 2.5, w_water 2.0`. **Why:** Trọng số là chọn/minh hoạ, không
fit; hiệu chỉnh định tính (ranking + biên độ gap).

**D-56 — Năm archetype HCMC; LST chỉ để ranking, air-temp từ climate normals** · *FEATURES.md*
**Why:** Surface UHI đỉnh ban ngày và ≠ air UHI 2 m; lẫn lộn hai cái sẽ đảo chữ ký diurnal.

---

## Stage 5 — Research: Pitfalls đã thành quy tắc thiết kế (`research/PITFALLS.md`)

> Các pitfall B1/B2/B3 đã hoá thành D-18/D-50, D-22/D-54, D-52; A3→D-31, A4→D-09, A8→D-44,
> A9→D-34. Dưới đây là các quy tắc còn lại được áp dụng làm quyết định.

**D-57 — `A1` Hậu tố `_wp` cho mọi real literal** · *PITFALLS A1*
**Why:** Literal không hậu tố là single precision, mất chính xác âm thầm trong hồi quy Rothfusz
nhiều số hạng triệt tiêu.

**D-58 — `A2` Lưu thuộc tính ô dạng `real(wp)`, không integer division** · *PITFALLS A2*
**Why:** Chia số nguyên (vd `density/100`) làm các số hạng UHI âm thầm về 0.

**D-59 — `A5` Khởi tạo accumulator trong thân hàm + `-finit-real=snan`** · *PITFALLS A5*
Không init trong khai báo (ngụ ý `save`). **Why:** Fortran không zero-init biến cục bộ; đọc biến
chưa khởi tạo cho trung bình/cực trị sai-mà-hợp-lý.

**D-60 — `A6` Kỷ luật vòng lặp 1-based, column-major + `-fcheck=all`** · *PITFALLS A6*
Index đầu trong cùng. **Why:** Fortran 1-based và column-major; lặp sai gây hỏng dữ liệu/thrash
cache.

**D-61 — `A7` Module-everything để có interface tường minh** · *PITFALLS A7*
Không truyền assumed-shape array vào external procedure trần. **Why:** Dummy assumed-shape cần
explicit interface, nếu không descriptor mảng hỏng.

**D-62 — `A10` Input delimited có validate, fail-loud kèm số dòng** · *PITFALLS A10* — reaffirms
D-33. **Why:** Parse namelist/ad-hoc âm thầm lệch cột khi delimiter sai → nạp sai giá trị vào sai
ô (lỗi I/O gây lỗi khoa học).

**D-63 — `B6` Đặt tên đại lượng rõ ràng (air vs surface vs feels-like)** · *PITFALLS B6*
Dùng `t_air`/`feels_like`, không `temp` chung chung, trong code/CSV/summary. **Why:** Surface UHI
đỉnh ban ngày và hành xử ngược; đặt tên nhầm/borrow độ lớn LST gây lỗi B2.

---

## Stage 6 — Roadmap (`ROADMAP.md`, `SUMMARY.md`)

**D-64 — Gộp 7 phase nghiên cứu → 4 phase roadmap (1→2→3→4)** · *SUMMARY.md / ROADMAP.md*
1 Scaffold & Grid · 2 Feels-Like Physics · 3 Day-Night & Scenarios · 4 CSV & Summary; mỗi phase
kết thúc bằng artifact `fpm run`-được. **Why:** Theo thứ tự build acyclic của research mà vẫn giữ
mỗi phase là increment ship được.

**D-65 — Quy ước đánh số phase (integer vs decimal INSERTED)** · *ROADMAP.md*
**Why:** Cho phép chèn việc gấp mà không đánh số lại.

**D-66 — Ghim 2 invariant khoa học làm success criteria có test** · *ROADMAP.md*
"Đô thị nóng hơn xanh/ven sông" (P2) và "gap đêm > trưa" (P3). **Why:** Là bảo đảm đúng-sai
make-or-break cho core value.

---

## Stage 7 — Phase 1 · Build Scaffold & Grid Loader

**D-67 — Định dạng dữ liệu hai tầng: grid CSV + coeffs namelist** · *P1 D-01* — refines D-33.
**Why:** Sửa grid trong Excel; hệ số là scalar hợp với namelist Fortran-native không cần parser.

**D-68 — Hình học lưới = danh sách district kèm `(i,j)`** · *P1 D-03*
Không phải raster nội suy dày, cũng không phải list 1D không toạ độ. **Why:** Cho heat-map 2D
thật (ô có vị trí) mà vẫn quen thuộc theo tên quận.

**D-69 — Quy mô seed ~12–16 district (5 archetype)** · *P1 D-05*
Triển khai 14 quận HCMC dễ nhận biết thay vì chỉ 5 archetype. **Why:** Map phong phú, dễ nhận
ra đáng công nhập liệu thêm.

**D-70 — `nx`/`ny` trong namelist là extent lưới có thẩm quyền** · *P1*
Validate `(i,j)` mỗi dòng so với nó. **Why:** Cho bound cấp phát raster sạch + lỗi "ngoài extent"
chính xác, đơn giản hơn quét max hai lượt.

**D-71 — Parse comma-split thủ công + iostat từng field (không list-directed)** · *P1 RESEARCH*
— refines D-33. Field 1 lấy nguyên làm name nhiều-từ; mỗi field còn lại internal-`read` riêng có
`iostat`. **Why:** List-directed `read(u,*)` vỡ với tên nhiều-từ ("Can Gio", "Thu Duc") và không
cho lỗi từng-field, làm hỏng fail-loud.

**D-72 — Khoá schema dòng CSV 9-field** · *P1 02-PLAN*
`name,i,j,t_air,rh,water_km,building,tree,urban` (urban = 1/0), dòng 1 là header bị tiêu thụ,
dòng `#`/trống bỏ qua. **Why:** Khoá hợp đồng để seed file + consumer Phase 2 đồng thuận thứ tự cột.

**D-73 — `type(coeffs_t)` gói hệ số** · *P1 02-PLAN*
Mang trọng số UHI, multiplier diurnal, base weather, extent `nx/ny`; đọc vào biến cục bộ rồi gán.
**Why:** Namelist không tham chiếu component derived-type di động được; cho Phase 2 một gói hệ số
có kiểu duy nhất.

**D-74 — `type(cell)` có cờ `occupied` + `allocate_grid` một lần** · *P1 01-PLAN* — reaffirms D-44.
**Why:** AoS rõ ở quy mô quận; cờ `occupied` dung nạp raster thưa; cấp phát một lần giữ loader
đơn giản.

**D-75 — Bound validation thuộc về `constants_mod`** · *P1 RESEARCH*
`T_MIN=10, T_MAX=50, RH_MIN=0, RH_MAX=100, DEN_MIN=0, DEN_MAX=1` là `parameter`. **Why:** Một
nguồn chân lý; tách ngưỡng validate khỏi tầng I/O.

**D-76 — Validation fail-loud kèm số dòng (không skip/clamp âm thầm)** · *P1 D-07* — reaffirms
D-62. Cũng **từ chối ô `(i,j)` trùng** loud. **Why:** Công cụ dạy/debug; chặn lỗi lệch-cột giả
dạng lỗi khoa học, chặn district này âm thầm đè district khác.

**D-77 — Driver trong `app/main.f90`, `src/` chỉ là library** · *P1 RESEARCH*
Lệch so với ARCHITECTURE.md (vốn để main trong src/). **Why:** Layout mặc định fpm coi `src/` là
library và `app/` là executable auto-discover.

**D-78 — In ASCII map markers `#`/`*`/`.`** · *P1 03-PLAN/SUMMARY*
`#` đô thị occupied, `*` nông thôn occupied, `.` trống; descriptor width-free. **Why:** Làm round
-trip file→terminal quan sát được như bản đồ hình HCMC; tránh tràn `*****` (A9).

**D-79 — File namelist đặt tên `coeffs.nml`** · *P1 02/03-PLAN*
Thay tên `model_coeffs.nml` trong sơ đồ research. **Why:** Khớp tên group `&coeffs`, ngắn gọn.

**D-80 — Gộp 4 sub-plan roadmap (01-01..01-04) → 3 plan thực thi** · *P1 (deviation)*
Test config round-trip gập vào suite test-drive 01-02 + e2e test 01-03. **Why:** Tránh một plan
riêng cho một test.

**D-81 — Reassign Tao Dan Park sang `(5,5)`** · *P1 03-PLAN (data fix)*
Bảng research để `(4,5)` đụng District 1. **Why:** io_mod từ chối ô trùng nên seed round-trip sẽ
fail; đảm bảo 14 cặp `(i,j)` đều duy nhất.

**D-82 — ⚠ fpm 0.13.0 từ chối `[profiles.*.gfortran]` → cờ qua `--flag`** · *P1 01-SUMMARY
(deviation)* — **landmine dự án.** Áp cờ dev/release nghiêm ngặt qua `fpm build/run/test --flag
"..."`, ghi trong README. **Why:** Phiên bản fpm cài không nhận key manifest profile; `--flag` là
fallback di động đã định trước. *(Ảnh hưởng mọi phase sau.)*

**D-83 — Cấp phát `testsuite` array thủ công (bug gfortran)** · *P1 02-SUMMARY (deviation)*
`allocate(testsuite(N))` + gán từng phần tử thay vì array constructor. **Why:** Dạng array
-constructor gây SIGABRT với gfortran trên Apple Silicon (bug procedure-pointer assignment).

---

## Stage 8 — Phase 2 · Feels-Like Physics (Heat Index + UHI Offset)

**D-84 — Baseline lai: T đồng nhất, RH theo từng ô** · *P2 D-01*
`feels = HeatIndex(t_base + ΔT_UHI, rh_cell)` — nhiệt độ nền là `coeffs%t_base` chung, RH lấy
theo ô. **Why:** Giữ "cùng nền thời tiết" (UHI-02) trung thực sư phạm — khác biệt nhiệt chỉ do
land cover — mà vẫn cho độ ẩm thực theo quận.

**D-85 — Nước chỉ tác động lên nhiệt độ (không nước→RH)** · *P2 D-02*
`w_water` tác động qua offset nhiệt; RH dùng nguyên từ file. **Why:** Tránh double-count B3 (nước
vừa hạ T vừa nâng heat index).

**D-86 — Suy giảm nước liên tục `Wprox = exp(−water_km/d0)` (kéo REFN-02 vào v1)** · *P2 D-04*
— thay đổi phạm vi: REFN-02 (vốn hoãn v2) được đưa vào v1. **Why:** Vật lý tốt nhất — gradient
không gian mượt; người dùng chấp nhận promote.

**D-87 — `d0` tunable trong namelist, default 2.5 km** · *P2 D-05* — reaffirms D-53.
**Why:** GRID-04 sửa-không-rebuild; người học tune `d0` và xem bản đồ phản hồi.

**D-88 — Phase 2 không scale diurnal (`m = 1`)** · *P2 D-06*
`m(t)` và các hệ số `m_*` để dormant, không tiêu thụ. **Why:** Chu kỳ diurnal thuộc Phase 3
(TIME-01/02); Phase 2 chỉ cần thứ tự đúng ở offset đầy đủ.

**D-89 — Heat index NWS hai nhánh đầy đủ + cả hai hiệu chỉnh RH** · *P2 D-07* — refines D-18/D-50.
Steadman (trung bình) <80 °F, Rothfusz ≥80 °F, cộng `((RH−85)/10)·((87−T)/5)` khi RH>85% & T
80–87, trừ `((13−RH)/4)·sqrt((17−|T−95|)/17)` khi RH<13% & T 80–112. **Why:** Guard hai nhánh là
pitfall khoa học chủ đạo (B1); số hạng RH>85% giữ cho đêm HCMC ẩm thực tế.

**D-90 — Tính nội bộ °F + kỷ luật literal `_wp`** · *P2 D-08* — reaffirms D-51/D-57.
Đổi °C↔°F chỉ ở biên (`F = C·9/5+32`); không trộn biến hệ số °C/°F. **Why:** Trộn hệ số là bug
heat-index kinh điển; số hạng đối nhau lớn của Rothfusz làm rounding single-precision lộ rõ.

**D-91 — Sàn feels-like đảm bảo HEAT-02** · *P2 D-09*
`feels = max(HeatIndex(...), t_adj)` (sàn theo `t_adj` = nhiệt đã hiệu chỉnh offset, không phải
`t_air` thô). **Why:** Kernel trần có thể tụt dưới input ở góc mát/khô; sàn là load-bearing cho
HEAT-02.

**D-92 — Ngân sách nhiệt duy nhất, áp một lần** · *P2 D-03* — reaffirms D-52.
`ΔT_UHI` cộng một lần vào input heat-index, KHÔNG offset post-hoc lần hai. **Why:** Giữ mỗi
driver single-digit °C (UHI-01), tránh double-count B3.

**D-93 — Ba module mới + mở rộng `constants_mod`** · *P2 PLAN*
`heat_index_mod` (NWS °F), `uhi_mod` (offset cộng tính), `feels_mod` (wrapper `feels_like_c`); +
`c_to_f`/`f_to_c` và 9 hằng `ROTH_C1..C9` trong constants. **Why:** Theo style private-module
Phase 1; hệ số có tên đảm bảo `kind` + dễ đọc; wrapper giữ cả công thức một chỗ test được.

**D-94 — Kernel elemental nhận arg scalar (không derived type)** · *P2 PLAN*
**Why:** Test đơn vị đơn giản hơn, khớp chữ ký mẫu ARCHITECTURE; truyền derived type hợp lệ nhưng
vô ích.

**D-95 — Tính feels trong driver, không lưu trên `type(cell)`** · *P2 PLAN*
**Why:** Một field scalar không chứa được nhiều timestep của Phase 3 — lưu bây giờ sẽ phải sửa lại.

**D-96 — `is_urban` → {0,1} bằng `merge`, không branch/nhân** · *P2 PLAN*
`U = merge(1.0_wp, 0.0_wp, is_urban)`. **Why:** One-liner elemental branchless; không nhân logical
hay dựa vào ép kiểu ngầm (A2).

**D-97 — Guard fail-loud `d0 > 0`** · *P2 PLAN*
Thêm fixture `coeffs_bad_d0.nml` + test `test_bad_d0`. **Why:** Tránh chia-cho-0 / Inf-NaN từ
`exp(−water_km/d0)` (DoS); theo convention fail-loud Phase 1.

**D-98 — Test biên 80 °F assert giá trị tính được, branch trên giá trị averaged** · *P2 PLAN*
Assert `79.79 °F` (tại 80 °F/40%), không phải ô bảng NWS làm tròn 80; branch xét trên giá trị
Steadman bước-2. **Why:** Điều kiện branch NWS tinh tế (B1); test giá trị làm tròn sẽ sai và giấu
mất kết quả dưới-air-temp.

**D-99 — Archetype tổng hợp dựng trong-test (rank/sign, không °C tuyệt đối)** · *P2 D-10/D-11*
Test UHI-02 dựng ô archetype trong-test; thêm monotonicity (↑building→↑feels, ↑tree→↓feels,
↑Wprox→↓feels, urban>rural) kiểm bằng rank/sign. **Why:** Bền với sửa seed data — test mô hình
chứ không test file; mô hình minh hoạ nên rank/sign mới là invariant có nghĩa.

**D-100 — (Flag P2) `t_air` từng-ô chưa dùng trong math feels** · *P2 VERIFICATION*
Verification nêu: model lai dùng `t_base` đồng nhất và bỏ qua `cell%t_air`, nhưng driver vẫn hiện
`T=` từng ô → ô mát hiện `FEELS < T` (optics). **Why:** Quan sát non-blocking để Phase 4 / D-01
quyết (→ dẫn tới D-110/D-115).

---

## Stage 9 — Phase 3 · Day-Night Cycle & Scenario Comparison

**D-101 — Hai núm diurnal mỗi timestep: `base(t)` + `m(t)`** · *P3 D-01*
`t_adj = base(t) + m(t)·ΔT_UHI`, rồi sàn feels. **Why:** Buổi chiều nóng tuyệt đối nhất nhưng gap
đỉnh ban đêm; chọn trên "chỉ m(t), base phẳng" (vốn làm pre-dawn nóng tuyệt đối hơn chiều — phản
trực giác).

**D-102 — `base(t)` đồng nhất triệt tiêu trong gap; offset gánh gap** · *P3 D-02* — insight cốt lõi.
`(base+m·off_u)−(base+m·off_r) = m·(off_u−off_r)`. **Why:** Giữ test `gap_night>gap_afternoon`
độc lập với đường cong base; base swing chỉ để hiện thực absolute + guard HEAT-02 ban đêm.

**D-103 — Bốn timestep (morning/afternoon/evening/predawn)** · *P3 D-03*
Tái dùng `m_*` (0.5/0.3/0.8/1.0); thêm lookup `base_*` (chiều nóng nhất, pre-dawn mát nhất).
**Why:** Khớp field `m_*` dormant của Phase 2 + dải nhiệt ngày HCMC.

**D-104 — Lookup table diurnal trong config, không phải đường cong** · *P3 D-04*
`base_*` cạnh `m_*` trong `coeffs.nml`, 4 điểm, sửa-không-rebuild. **Why:** Đơn giản nhất, tune
được; cosine (REFN-03) hoãn v2.

**D-105 — Định nghĩa scenario lai (struct trong code, delta trong config)** · *P3 D-05*
`type(scenario_t)` + 2 scenario trong `scenario_mod`; magnitude (`add_trees_delta`,
`concrete_delta`) trong `coeffs.nml`. **Why:** Cân bằng đơn giản + tune được; danh sách scenario
tuỳ ý hoàn toàn config-driven hoãn v2.

**D-106 — Đúng một driver mỗi scenario, toàn lưới, clamp [0,1], không flip `is_urban`** · *P3 D-06*
"add trees" `tree += delta`; "more concrete" `building += delta`. **Why:** Apples-to-apples (B5 —
một driver); ô đã xanh clamp ít đổi, lõi đô thị ít cây đổi nhiều — kể câu chuyện không cần
special-case `is_urban`.

**D-107 — Baseline bất biến qua copy-then-mutate (deep copy khi gán)** · *P3 D-07* — reaffirms D-45.
`work = baseline` (Fortran deep-copy `cells(:,:)` + mỗi `name`), chỉ mutate bản sao. **Why:** Đảm
bảo SCEN-01 miễn phí; tránh pitfall vòng đời allocatable (A8) và save-init (A4).

**D-108 — Delta apples-to-apples cùng timestep** · *P3 D-08*
`feels_scenario − feels_baseline` cùng timestep cùng nền; báo cáo theo ô + city-average. **Why:**
SCEN-02 / B5 — so khác timestep/thời tiết làm số "+cây → −Y °C" vô nghĩa.

**D-109 — Gap = mean-urban − mean-rural** · *P3 D-09* — reaffirms D-49.
Mỗi timestep. **Why:** Ổn định, kháng outlier, metric UHI canopy-layer kinh điển; tái dùng được
cho summary Phase 4 (→ D-118).

**D-110 — Hard direction, soft magnitude** · *P3 D-10* — refines D-66.
HARD-assert `gap_predawn > gap_afternoon` + night-sanity (HEAT-02); biên độ ~3–8 °C là check
SOFT cảnh báo, không fail build. **Why:** Khoá hướng make-or-break (B2) mà vẫn tôn trọng "verify
bằng rank/sign" (D-99) vì trọng số minh hoạ chứ không fit.

**D-111 — `m` là tham số positional thứ 2 bắt buộc của `feels_like_c`** · *P3 RESEARCH*
Thread vào kernel ngay sau `t_base`, giữ `elemental pure`; 2 call site đổi (driver + test_ordering
truyền `1.0_wp`). **Why:** Chọn trên `optional`+default 1.0 (phức tạp `present()`/snan) và trên hàm
riêng (lặp logic); caller phải đổi đằng nào.

**D-112 — Default `base_*` = 29/33/30/25 °C, delta = 0.2; validate khi load** · *P3 RESEARCH/PLAN*
Reject `base_*` ngoài [10,50] và delta ngoài (0,1]. **Why:** Trong dải HCMC, cho gap chiều ≈ +0.7
vs pre-dawn ≈ +7.1 °C; config-tunable nên giá trị sai chỉ dịch biên độ, không đảo hướng.

**D-113 — Chỉ assert invariant theo cặp, không assert pre-dawn là max toàn cục** · *P3 RESEARCH*
**Why:** Với default đã chọn, base evening ấm hơn kích hoạt thêm khuếch đại heat-index (base
không triệt tiêu hoàn toàn qua HI phi tuyến) nên gap evening có thể nhỉnh hơn pre-dawn — over
-constrain sẽ tạo fail giả.

**D-114 — `auto-tests` thay vì block `[[test]]`; cờ qua `--flag`** · *P3 PLAN* — reaffirms D-82.
File test mới auto-discover; tính feels mọi ô trước khi mask để snan không bắt đọc chưa-init.
**Why:** Khớp cấu hình `fpm.toml` thật.

**D-115 — `WR-01` `t_air` từng-ô là reference-only; base đồng nhất là cố ý** · *P3 REVIEW* (giải
quyết D-100). Không wire `cell%t_air` vào feels; giữ base diurnal đồng nhất. **Why:** Core value
là gap "cùng nền thời tiết"; nạp `t_air` từng-ô (đô thị vốn nóng hơn) sẽ double-count chính hiệu
ứng UHI mô hình đang tách ra. *(→ Phase 4 dùng `t_air` làm cột tham chiếu CSV, D-110/D-117.)*

**D-116 — Củng cố validation từ review Phase 3** · *P3 REVIEW WR-02..WR-06, IN-01..IN-04*
Gồm: test gap trên lưới thật cả 4 timestep (`WR-02`); validate `m_* ≥ 0` (`WR-03`); validate
`nx/ny ≥ 1` (`WR-04`); reject grid rỗng/chỉ-header (`WR-05`); lấy baseline theo định-nghĩa
zero-delta không theo index `iscen==1` (`WR-06`); gọi `city_average` thay logic trùng (`IN-01`);
xử lý `t_base`/`rh_base` dead-config (`IN-02`); sentinel pure-safe NaN cho timestep ngoài miền
(`IN-03`); `int2str` trả allocatable không padding (`IN-04`). **Why:** Bịt các đường config/parse
có thể âm thầm đảo invariant hoặc no-op giả-thành-công. **Đã REJECT `WR-07`** ("đổi sang remove
buildings") — sai spec, ROADMAP/CONTEXT yêu cầu "more concrete".

---

## Stage 10 — Phase 4 · CSV Export & Console Summary (gồm review + khắc phục)

**D-117 — Air temp thành HAI cột (`t_air` + `base_t`)** · *P4 D-03* — giải quyết D-100/D-115.
CSV mang cả `t_air` (tham chiếu) lẫn `base_t` (nền mô hình thực dùng). **Why:** Cho `t_air` một
consumer thật, làm minh bạch dẫn xuất feels, tránh nhầm "feels < air_temp" — nhưng `t_air` KHÔNG
được đưa vào feels (double-count UHI).

**D-118 — `results.csv` cố định, ghi đè mỗi lần chạy, không thư viện** · *P4 D-05* — reaffirms D-34.
Formatted `write` thuần; knob `output_path` hoãn v2. **Why:** Giữ vòng tune-`coeffs.nml` → `fpm
run` → re-plot là một lệnh; deterministic, không xử lý ngày tháng.

**D-119 — Phạm vi dòng CSV = occupied × scenario × timestep (168+1)** · *P4 D-01* — refines D-25.
14 quận × 3 scenario × 4 timestep; ô trống loại trừ, cột `(i,j)` để plotter đặt district. **Why:**
File chỉ-dữ-liệu-thật sạch; raster đầy-lưới (~960 dòng) hoãn v2.

**D-120 — CSV deterministic, độc lập locale** · *P4 D-02* — reaffirms D-34.
Header, dấu `.` (không bao giờ `,` locale), thứ tự cột + thứ tự lặp `scenario→timestep→i→j` cố
định → byte-reproducible. **Why:** Parse sạch Excel/Python/gnuplot, tái lập y hệt mỗi lần chạy.

**D-121 — Schema 9 cột; `uhi_offset_c` = offset đã áp** · *P4 D-04* — refines D-25.
`i,j,name,time_label,scenario,t_air,base_t,feels_c,uhi_offset_c`, với `uhi_offset_c = m(t)·ΔT_UHI`
(giá trị thực dịch chuyển feels). **Why:** Superset OUT-01 + `name` để vẽ dễ; offset đã-áp cho
người đọc thấy vì sao gap lớn dần về pre-dawn.

**D-122 — Console = bảng baseline mỗi timestep + recap delta scenario** · *P4 D-06* — refines D-26.
Bảng baseline (nóng/mát name+°C, feels city-avg, gap đô thị–nông thôn) + recap ΔT city-avg cho
add_trees/more_concrete; thay các dòng tối thiểu Phase 3. **Why:** Đọc như một report nhỏ con người
lướt được; bảng 12-tổ-hợp đầy đủ hoãn lại.

**D-123 — Console chỉ báo feels-like** · *P4 D-08* — giải quyết D-100.
Không in `t_air` từng-ô cạnh feels; quan hệ `t_air`/`base_t` chỉ ở CSV. **Why:** Xoá nhầm lẫn
optics "FEELS < T" của Phase 2.

**D-124 — `hottest`/`coolest` qua `maxloc`/`minloc` trên mask occupied** · *P4 D-07*
Thêm vào `summary_mod`, trả index ô + giá trị feels, báo theo name + value. **Why:** Tái dùng
idiom reduction mask-occupied sẵn có cạnh `urban_rural_gap`/`city_average`.

**D-125 — Pipeline end-to-end một `fpm run`** · *P4 D-09* — refines D-64.
load → physics → diurnal (4) → scenarios (3) → ghi CSV + summary; giữ feels qua mọi
scenario×timestep×cell. **Why:** Đạt success criterion 4 mà không đụng kernel Phase 2-3 khoá (D-12
Phase 3 đã giữ feels reachable).

**D-126 — Mở rộng `io_mod`, không tạo `output_mod` mới** · *P4 01-PLAN*
`write_results_csv` thêm vào `io_mod` (nghịch đảo `read_grid_csv`). **Why:** Giải Claude's
-discretion về module-placement theo analog gần nhất trong repo.

**D-127 — Collect-then-write qua mảng 4D** · *P4 02-PLAN*
Driver tích `feels_all(nx,ny,NT,3)` + `uhi_all(...)` trong vòng lặp, rồi một lời gọi
`write_results_csv`. **Why:** Một lần ghi sau-vòng-lặp, deterministic.

**D-128 — `hottest`/`coolest` là `pure subroutine` + sentinel mask rỗng** · *P4 01-PLAN*
Guard `count(occupied)==0` → trả `ih=jh=0, val=0`. **Why:** Function không trả gọn cặp index +
value; sentinel tránh index ngoài-biên từ maxloc/minloc trên mask toàn-false.

**D-129 — `results.csv` được gitignore** · *P4 02-PLAN*
**Why:** Là artifact tái sinh ghi đè mỗi lần chạy, không phải source.

**D-130 — Khắc phục review Phase 4 — đã FIX** · *P4 REVIEW (Resolution)*
`WR-01` guard sentinel trước khi deref `cells(ih,jh)%name`; `WR-02` assert conformance shape của
`feels_all`/`uhi_all` đầu `write_results_csv`; `WR-04` copy mask vào logical contiguous trước
`maxloc`/`minloc` (hết array-temporary, console in sạch); `WR-05` thêm `pure function real2str`
(ép số 0 đứng đầu, vẫn width-free A9) cho CSV + console; `IN-01` hoist `base_t` ra ngoài vòng i/j.
**Why:** Bịt các hợp đồng OOB/robustness và khôi phục định dạng chuẩn mà vẫn A9-safe.

**D-131 — Khắc phục review Phase 4 — ACCEPTED / N-A (không đổi code)** · *P4 REVIEW (Resolution)*
`WR-03` giữ `F7.2`/`F8.2` console (an toàn nhờ validation bound; width-free sẽ phá canh cột);
`IN-02` `name` CSV không quote (by design, seed data không dấu phẩy); `IN-03` `uhi_offset_c =
m·offset` đúng theo D-121 — header không đổi. **Why:** Fix sẽ làm xấu/sai locked decision; chấp
nhận có lý do.

**D-132 — Artifact mới: `real2str` trong `io_mod`** · *P4 REVIEW (Resolution)*
`public pure function real2str(x)` — format `F0.2` rồi ép leading zero, dùng chung CSV + console.
**Why:** Format real width-free, an-toàn-leading-zero, `.`-decimal cho cả hai đường output.

---

*Tổng: D-01 … D-132. Cập nhật: 2026-06-30. Nguồn: toàn bộ `.planning/` (PROJECT, REQUIREMENTS,
research/*, ROADMAP, và CONTEXT/DISCUSSION-LOG/PLAN/SUMMARY/REVIEW/VERIFICATION của Phase 1–4).*
