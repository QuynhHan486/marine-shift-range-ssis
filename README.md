# Marine Shift Range — SSIS và SSAS

Đồ án Kho dữ liệu và OLAP: phân tích sự thay đổi phạm vi phân bố của sinh vật biển tại Biển Đông trong bối cảnh biến đổi khí hậu.

Nguồn đầu vào duy nhất: `data/occurrence_clean.csv` — **108.680 bản ghi, 23 cột**.

## Mở project

Mở `MARINE_SHIFT_RANGE.slnx` trong Visual Studio để thấy cả **SSIS từ laptop** và SSAS. Source SSIS được nhập từ `New SSIS.zip`; triển khai SSIS cũ dùng staging và SQL đã được gỡ bỏ.

Có thể mở riêng:

- [Solution SSIS](ssis_demo/marineRangeShift_SSIS_demo.slnx)
- [Project SSIS](ssis_demo/marineRangeShift_SSIS_demo.dtproj)
- [Package MarineOccurrenceETL](ssis_demo/MarineOccurrenceETL.dtsx)
- [Solution SSAS](ssas/MARINE_SHIFT_RANGE_SSAS.slnx)

| Đường dẫn | Nội dung |
|---|---|
| `ssis_demo/` | Project, package, connection manager và bản build `.ispac` từ laptop; kèm các biểu thức hướng dẫn |
| `database/` | Hai file `.mdf`/`.ldf` gốc được nén trong một ZIP; có SHA-256 để đối chiếu |
| `sql/demo/` | Script tạo database/bảng, khởi tạo nhóm độ sâu và đặt lại dữ liệu demo |
| `data/` | Một CSV nguồn, mô tả và fingerprint kiểm tra |
| `docs/` | Báo cáo Word, hướng dẫn SSIS và tài liệu MDX |
| `ssas/` | Project SSAS Multidimensional, dimensions, cube và Data Source View |
| `mdx/` | [15 câu MDX](mdx/README.md) theo các mục tiêu phân tích đã sửa |
| `scripts/` | Công cụ chạy MDX và đối chiếu với snapshot warehouse |
| `tests/`, `evidence/` | Kiểm tra source, bằng chứng nhập project và kiểm chứng MDX lịch sử |

## Chuẩn bị và chạy SSIS

Dùng Visual Studio có extension SSIS Projects hỗ trợ SQL Server 2025. Project triển khai theo Project Deployment Model, target SQL Server 2025.

1. Giải nén và Attach database được cung cấp theo [hướng dẫn database](database/README.md), hoặc tạo database trống `marineRangeShift_demo` bằng `sql/demo/00_create_demo_database.sql`, chạy `01_create_warehouse_tables.sql` rồi `03_seed_depth_bands.sql` trong cùng database.
2. Mở solution SSIS hoặc solution chung. Mở `MarineOccurrenceETL.dtsx`.
3. Trong Connection Managers của package, mở **OBIS**, Browse đến `data/occurrence_clean.csv` ở bản repo đang sử dụng. Source gốc giữ đường dẫn CSV trên laptop nên cần chọn lại khi chuyển máy/thư mục.
4. Mở project connection manager `marineRangeShift_warehouse_demo.conmgr` (tên hiển thị `__SQLSERVER2025DEV`). Kiểm tra server, database và Test Connection. Mặc định của laptop là `.\SQLSERVER2025DEV`, database `marineRangeShift_demo`, Windows Authentication, OLE DB Driver 19.
5. Nếu database đã có dữ liệu, chỉ đặt lại bằng `sql/demo/04_clear_loaded_data.sql` khi muốn trình diễn nạp lại. Script xóa Fact và bốn chiều được nạp từ CSV, giữ năm nhóm độ sâu. Không chạy package nạp toàn bộ vào các bảng đang có dữ liệu.
6. Lưu kết nối rồi nhấn F5. Kiểm tra kết quả theo [hướng dẫn SSIS](docs/SSIS_DEMONSTRATION_GUIDE.docx) và [báo cáo Word](docs/BT_OLAP_A1.1_Chuong_2_SSIS.docx).

Tên database, project và connection trong source được cung cấp ở trên là các tên đang dùng cho project laptop. Áp dụng các bước trong tài liệu hướng dẫn với các tên này.

Control Flow gồm năm tác vụ, nối bằng bốn điều kiện Success:

```text
Load Dim_Date → Load Dim_Taxon → Load Dim_Location → Load Dim_Quality → Load Fact_Occurrence
```

`Dim_Depth_Band` được khởi tạo bằng SQL. Package dùng Flat File Source, Derived Column, Sort, Aggregate, Multicast, Merge Join, Lookup và OLE DB Destination. Không cần file calendar hoặc taxon riêng.

| Bảng | Số dòng tham chiếu đã xác nhận trong demo |
|---|---:|
| Dim_Date | 2.314 |
| Dim_Taxon | 7.737 |
| Dim_Location | 3.067 |
| Dim_Depth_Band | 5 |
| Dim_Quality | 26 |
| Fact_Occurrence | 108.680 |

`ssis_demo/marineRangeShift_SSIS_demo.ispac` là bản build từ archive laptop, đã đối chiếu khớp package, connection manager và project parameters. Khi sửa source/kết nối, Build project để tạo bản triển khai mới trong `bin/Development/`. Build được cung cấp vẫn giữ cấu hình laptop gốc.

## Database và bằng chứng nhập source

[Bundle database](database/marineRangeShift_demo.zip) chứa nguyên file `marineRangeShift_demo.mdf` và `marineRangeShift_demo_log.ldf`. Hai file được nén để giữ bundle dưới giới hạn kích thước file của GitHub; không đưa file `.ldf` lớn trực tiếp vào Git. [Manifest](database/manifest.json) lưu kích thước và SHA-256 của bundle cùng từng file.

`evidence/ssis-laptop-import.json` ghi nguồn archive và hash từng file source được nhập. Package, project, connection manager và parameters giữ nguyên cấu trúc/giá trị XML; chỉ chuẩn hóa xuống dòng LF để lưu bằng Git. Bản build giữ nguyên byte từ archive. Solution riêng đổi đường dẫn project để phù hợp bố cục repo. Bản CSV trùng lặp, cache `.vs/`, thiết lập `.user` và file trung gian `obj/` không được nhập.

Quá trình nhập source không chạy ETL và không Attach hay thay đổi database. Các kiểm tra cục bộ không thay thế việc chạy package trong môi trường SQL Server/SSIS.

## SSAS và MDX

Data Source của SSAS mặc định trỏ đến cùng server/database của package laptop: `.\SQLSERVER2025DEV` / `marineRangeShift_demo`. Đổi server khi làm trên máy khác. Sau khi kết nối kho mới, kiểm tra schema/khóa, Deploy và Process cube, rồi chạy và đối chiếu lại **cả 15 câu MDX**.

Trong SSMS, kết nối **Analysis Services** đến instance đã triển khai, chọn database SSAS và mở từng file `.mdx`. Tên cube trong source là `[MARINE SHIFT RANGE DW]`.

```mdx
SELECT {[Measures].[Occurrence Count]} ON COLUMNS
FROM [MARINE SHIFT RANGE DW];
```

Với toàn bộ dữ liệu đã cung cấp, số bản ghi kỳ vọng là **108.680**. Kết quả MDX lịch sử từ warehouse trước đó không phải bằng chứng thực thi trên database mới; Q4 và Q6 cũng đã được sửa phạm vi.

- [Mục tiêu và danh sách truy vấn](mdx/README.md)
- [Hướng dẫn chạy MDX](docs/MDX_GUIDE.md)
- [Trạng thái kiểm chứng](docs/MDX_VALIDATED.md)
- [Số tham chiếu CSV](docs/MDX_DATA_BASELINES.md)

## Kiểm tra source

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
```

Các kiểm tra xác nhận fingerprint/thống kê CSV, tham chiếu project và solution, bản build khớp source, thứ tự năm Data Flow, cột nguồn và ánh xạ Fact/Lookup. Các kiểm tra MDX kiểm soát phạm vi đối chiếu Q4/Q6. GitHub Actions chạy các kiểm tra này, không thực thi SSIS hoặc SSAS.

Số bản ghi, số loài và số cá thể được báo cáo có ý nghĩa khác nhau. SST/SSS đi kèm vị trí không tự xác nhận điều kiện tại ngày quan sát hoặc quan hệ nhân quả với biến đổi khí hậu. Giữ NULL khi nguồn thiếu thông tin. Chi tiết nguồn: [data/README.md](data/README.md).
