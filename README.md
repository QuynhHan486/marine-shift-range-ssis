# Marine Shift Range — SSIS và SSAS

Đồ án Kho dữ liệu và OLAP: phân tích sự thay đổi phạm vi phân bố của sinh vật biển tại Biển Đông trong bối cảnh biến đổi khí hậu.

Nguồn đầu vào duy nhất là `data/occurrence_clean.csv`: **108.680 bản ghi, 23 cột**. Không cần `calendar.csv` hoặc `taxon_dimension.csv` riêng.

## Mở project

Mở `MARINE_SHIFT_RANGE.slnx` trong Visual Studio để xem cả SSIS và SSAS. Có thể mở từng project bằng solution trong thư mục tương ứng.

| Đường dẫn | Nội dung |
|---|---|
| `ssis/` | Project SSIS và `Package.dtsx` |
| `ssas/` | Project SSAS Multidimensional, dimensions, cube và Data Source View |
| `mdx/` | 15 câu truy vấn; xem [danh sách](mdx/README.md) |
| `data/` | CSV nguồn, mô tả nguồn và fingerprint kiểm tra |
| `sql/` | Schema, views, procedures và truy vấn kiểm tra của package |
| `sql/demo/` | SQL tạo bảng, khởi tạo nhóm độ sâu và đặt lại dữ liệu cho demo thao tác thủ công |
| `ssis_demo/` | Biểu thức Derived Column dùng trong demo thủ công |
| `docs/` | Báo cáo Word, hướng dẫn SSIS và MDX |
| `scripts/` | Công cụ build, chạy ETL và đối chiếu kết quả |
| `tests/`, `evidence/` | Kiểm tra và bằng chứng kiểm chứng đã lưu |
| `MARINE_SHIFT_RANGE_SSIS.ispac` | Bản build SSIS đã kiểm chứng, dùng để triển khai |

## Tài liệu SSIS và báo cáo

- [Báo cáo Word có Chương 2 SSIS](docs/BT_OLAP_A1.1_Chuong_2_SSIS.docx): các bước, hình trích video, ánh xạ cột và kết quả nạp đã xác nhận.
- [Hướng dẫn dựng demo SSIS](docs/SSIS_DEMONSTRATION_GUIDE.docx): thực hành với Flat File Source, Derived Column, Sort, Aggregate, Merge Join, Lookup và OLE DB Destination.
- `ssis_demo/derived_column_expressions.txt`: biểu thức để sao chép khi dựng demo.

Hướng dẫn và video mô tả demo thủ công gồm năm Data Flow Task; `Dim_Depth_Band` được khởi tạo bằng SQL. Project `ssis/Package.dtsx` đi kèm là một triển khai khác dùng staging và biến đổi bằng SQL, gồm 11 tác vụ và 7 Data Flow. Chọn đúng hướng dẫn cho quy trình đang trình bày.

| Bảng | Số dòng đã đối chiếu |
|---|---:|
| Dim_Date | 2.314 |
| Dim_Taxon | 7.737 |
| Dim_Location | 3.067 |
| Dim_Depth_Band | 5 |
| Dim_Quality | 26 |
| Fact_Occurrence | 108.680 |

## Chạy package trong `ssis/`

Yêu cầu: Windows, SQL Server 2025 với Integration Services runtime, Microsoft OLE DB Driver for SQL Server (`MSOLEDBSQL`), `sqlcmd` và Windows Authentication. Mở/build project bằng Visual Studio có extension SSIS Projects hỗ trợ SQL Server 2025.

Từ thư mục gốc repository:

```powershell
.\scripts\initialize.ps1 -ServerName '.' -DatabaseName 'MARINE_SHIFT_RANGE_DW'
.\scripts\run-etl.ps1 -ServerName '.' -DatabaseName 'MARINE_SHIFT_RANGE_DW'
sqlcmd -S . -E -d MARINE_SHIFT_RANGE_DW -b -f 65001 -i .\sql\04_verify.sql
```

Thay `.` bằng tên instance của máy thực hiện. Có thể truyền `-DataFile 'D:\OLAP\occurrence_clean.csv'` cho `run-etl.ps1`.

Để chạy trong Visual Studio, mở `ssis/MARINE_SHIFT_RANGE_SSIS.sln` hoặc `.slnx`, mở `Package.dtsx` và đặt các biến `User::ServerName`, `User::DatabaseName`, `User::DataFile` (đường dẫn tuyệt đối), `User::MaxRejects=0`. Build configuration Development tạo file `.ispac` trong `ssis/bin/Development/`.

Package đọc CSV vào staging, kiểm tra và chuyển đổi bằng SQL, nạp các bảng chiều và Fact vào schema `load`, sau đó đối soát và publish sang `dbo` trong transaction. Schema `etl` giữ nhật ký batch, rejects và các phương án phân loại mâu thuẫn. Nguồn phải là snapshot đầy đủ; quy trình này thay snapshot khi thành công, không dùng để append dữ liệu delta. Các kiểm tra số dòng cố định chỉ áp dụng cho CSV được cung cấp.

## SSAS và MDX

Mở `ssas/MARINE_SHIFT_RANGE_SSAS.slnx` để cấu hình nguồn và triển khai cube trên máy thực hiện. Cần Deploy và Process trước khi truy vấn mô hình mới hoặc sau khi đổi cấu trúc/dữ liệu nguồn.

Trong SSMS, kết nối **Analysis Services**, chọn database `MARINE_SHIFT_RANGE_SSAS` rồi mở một file trong `mdx/`. Tên cube trong `FROM` là `[MARINE SHIFT RANGE DW]`; measure đếm bản ghi là `[Measures].[Occurrence Count]`.

```mdx
SELECT {[Measures].[Occurrence Count]} ON COLUMNS
FROM [MARINE SHIFT RANGE DW];
```

Với snapshot đã cung cấp, tổng bản ghi là **108.680**. Bộ trước khi cập nhật đã được kiểm chứng trên môi trường trước đó, đối chiếu 36.864 ô kết quả. Q4 và Q6 đã đổi phạm vi theo câu hỏi mới và cần được chạy/đối chiếu lại; xem [mục tiêu hiện tại](mdx/README.md). Việc SELECT không yêu cầu chạy lại ETL hay Process.

- [Hướng dẫn chạy MDX](docs/MDX_GUIDE.md)
- [Định nghĩa và kết quả kiểm chứng](docs/MDX_VALIDATED.md)
- [Số tham chiếu từ CSV](docs/MDX_DATA_BASELINES.md)

Nếu gặp lỗi nhận diện edition `StandardDeveloper64` khi Deploy bằng extension Visual Studio, môi trường đã kiểm chứng sử dụng Deployment Wizard của SSMS 22 với file `.asdatabase` được build trong `ssas/bin/`.

## Kiểm tra và bằng chứng

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
```

Các kiểm tra trên xác nhận fingerprint CSV, schema và cấu trúc XML/ISPAC, không cần kết nối SQL Server. GitHub Actions cũng kiểm tra SQL sinh từ nguồn còn đồng bộ.

Các lệnh sau dành cho môi trường SQL Server/SSIS đã cấu hình; integration test có thao tác nạp dữ liệu:

```powershell
.\tests\integration.ps1
python .\scripts\build_sql.py
.\scripts\build-package.ps1
```

- `evidence/warehouse-validation.json`: số dòng, mẫu dữ liệu, hash và nhật ký batch.
- `evidence/integration-tests.json`: kết quả nạp lại và thử dữ liệu lỗi.
- `evidence/mdx-suite-validation.json`: đối chiếu toàn bộ bộ MDX.
- `evidence/mdx-q01-validation.json`: baseline câu 1, được `scripts/reconcile-mdx.py` sử dụng.
- Các log được giữ trong `evidence/` ghi nhận lần chạy, kiểm tra SQL và build đã thực hiện.

Số bản ghi, số loài phân biệt và số cá thể được báo cáo có ý nghĩa khác nhau. SST/SSS đi kèm vị trí không tự chứng minh điều kiện môi trường tại ngày quan sát hoặc quan hệ nhân quả với biến đổi khí hậu. Giữ NULL khi nguồn thiếu thông tin. Chi tiết nguồn và phạm vi: [data/README.md](data/README.md).

Tệp tạm, cache Visual Studio, thiết lập cá nhân và đầu ra build trong `bin/`, `obj/` được bỏ qua bởi Git.
