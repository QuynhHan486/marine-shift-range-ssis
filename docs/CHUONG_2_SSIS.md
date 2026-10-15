# CHƯƠNG 2 TÍCH HỢP DỮ LIỆU VÀO KHO BẰNG SSIS

Phần tích hợp sử dụng file `occurrence_clean.csv` gồm 108.680 dòng và 24 thuộc tính, đã được làm sạch ở chương 1. Mục tiêu là nạp dữ liệu quan sát sinh vật biển vào lược đồ hình sao gồm 5 bảng chiều và `Fact_Occurrence`, bảo toàn giá trị thiếu và thông tin chất lượng, đồng thời kiểm chứng khả năng chạy lại. Package đã chạy trực tiếp bằng SSIS runtime 2025; kết quả sau nạp có 108.680 fact, không có reject và không có khóa ngoại mồ côi.

## 2.1 Chuẩn bị database

Máy thực nghiệm sử dụng SQL Server 2025 Standard Developer Edition, SSIS runtime 17.0.1000.7, Visual Studio 18.10.3 và Microsoft OLE DB Driver for SQL Server. Kết nối Windows Authentication với Database Engine tại `.`. Kho được tạo riêng với tên `MARINE_SHIFT_RANGE_DW`.

Database `MARINE_SHIFT_RANGE` đang có trên máy là Management Data Warehouse của Data Collector. Chức năng Data Collection trong báo cáo mẫu phục vụ theo dõi hoạt động SQL Server; không phải điều kiện bắt buộc để tạo kho nghiệp vụ hình sao. Vì vậy phần SSIS này sử dụng database riêng cho dữ liệu sinh vật biển.

**Bước 1.** Mở SSMS, kết nối Database Engine bằng Windows Authentication. Mở PowerShell tại thư mục repository và chạy:

```powershell
.\scripts\initialize.ps1 -ServerName '.' -DatabaseName 'MARINE_SHIFT_RANGE_DW'
```

**Bước 2.** Script tạo database nếu chưa có rồi thực thi `01_schema.sql`, `02_views.sql`, `03_procedures.sql`. Ba nhóm đối tượng được tổ chức như sau:

| Schema | Đối tượng và vai trò |
|---|---|
| `etl` | Raw staging, staging đã kiểm tra, views biến đổi, batch, reject, taxon conflict, trạng thái snapshot |
| `load` | 5 bảng chiều và fact đang chuẩn bị cho lần chạy hiện tại |
| `dbo` | 5 bảng chiều và fact hoàn chỉnh dùng cho SSAS/OLAP |

**Bước 3.** Kiểm tra 5 quan hệ khóa ngoại của `dbo.Fact_Occurrence`: `date_id`, `taxon_id`, `location_id`, `depth_band_id`, `quality_id`. Các bảng có khóa chính; fact có ràng buộc `occurrence_count=1`. Không cần cấp quyền cho dịch vụ Data Collector; tài khoản chạy ETL cần quyền thao tác trên các schema của kho đồ án.

## 2.2 Hoàn thiện project SSIS

Project kế thừa tên `MARINE_SHIFT_RANGE_SSIS` của bản làm dở. File package `Package.dtsx` được hoàn thiện thành `MarineShiftETL`; Deployment Model là Project, TargetServerVersion là SQLServer2025, ProtectionLevel là DontSaveSensitive. Project không lưu mật khẩu đăng nhập.

**Bước 1.** Mở `ssis/MARINE_SHIFT_RANGE_SSIS.sln` hoặc `.slnx` trong Visual Studio có extension SSIS Projects. Chọn configuration Development rồi mở `Package.dtsx`.

**Bước 2.** Mở Variables và cấu hình:

| Biến | Kiểu | Giá trị mặc định hoặc quy tắc |
|---|---|---|
| `User::ServerName` | String | `.` hoặc tên server/instance |
| `User::DatabaseName` | String | `MARINE_SHIFT_RANGE_DW` |
| `User::DataFile` | String | Đặt đường dẫn tuyệt đối đến CSV khi chạy trong Visual Studio |
| `User::MaxRejects` | Int32 | `0`, chặn publish khi có dòng không hợp lệ |
| `User::BatchId` | Int64 | Nhận batch_id từ task đầu tiên, không nhập thủ công |

Đây là **biến package**, không phải project parameters. Script chạy dùng `dtexec /SET` để truyền giá trị. Khi chạy từ thư mục repo, giá trị tương đối `data\occurrence_clean.csv` cũng hợp lệ.

**Bước 3.** Kiểm tra Connection Managers:

- `Warehouse`: OLE DB, provider MSOLEDBSQL, Windows Authentication; connection string suy ra từ các biến server và database.
- `AuditSession`: cùng kiểu kết nối, `RetainSameConnection=True`, giữ khóa phiên để ngăn hai lần ETL chạy đồng thời.
- `OBIS Clean CSV`: Flat File, delimiter dấu phẩy, text qualifier dấu nháy kép, UTF-8 code page 65001, header hàng đầu, kết thúc dòng CRLF. 24 trường nguồn được đọc dạng Unicode DT_WSTR với chiều dài tối đa 512 rồi nạp vào raw staging.

## 2.3 Control Flow và chuẩn bị bảng

Package có 11 task, nối bằng 10 Success precedence constraints. Các DDL tạo bảng, views và stored procedures được thực thi ở bước khởi tạo database. Mỗi lần ETL chỉ xóa dữ liệu làm việc trong `etl` và `load`; cập nhật các bảng `dbo` ở cuối bằng transaction.

| Thứ tự | Task | Chức năng |
|---:|---|---|
| 1 | SQL Begin Batch | Lấy application lock, tạo batch RUNNING, trả batch_id |
| 2 | SQL Clear Working Tables | Làm rỗng raw staging, typed staging và 6 bảng load |
| 3 | DFT CSV to Raw Staging | Flat File Source sang OLE DB Destination |
| 4 | SQL Validate and Transform | TRY_CONVERT, kiểm tra dữ liệu, ghi reject, tạo typed staging |
| 5 | DFT Load Dim_Date | Nạp ngày và các thuộc tính thời gian |
| 6 | DFT Load Dim_Taxon | Nạp bộ phân loại được chọn cho từng tên khoa học |
| 7 | DFT Load Dim_Location | Nạp vị trí và thuộc tính môi trường |
| 8 | DFT Load Dim_Depth_Band | Nạp 4 dải độ sâu và Unknown |
| 9 | DFT Load Dim_Quality | Nạp nhóm cờ lỗi và trạng thái quan sát |
| 10 | DFT Load Fact_Occurrence | Join 5 chiều trong SQL Source rồi nạp fact |
| 11 | SQL Reconcile and Publish | Đối soát, thay snapshot trong transaction, kết thúc batch |

Event Handler `OnError` chạy task `SQL Record Failure`, gọi `etl.usp_FailBatch`, ghi thông báo và giải phóng khóa phiên. Cơ chế này giúp phân biệt lỗi đọc file, lỗi chuyển đổi, lỗi khóa chiều và lỗi publish. Package không sử dụng Python hoặc Script Task để nạp dữ liệu.

## 2.4 Data Flow nguồn và các phép chuyển đổi

Data Flow đầu tiên nối Flat File Source với OLE DB Destination tại `etl.Stg_OccurrenceRaw`. Đích dùng Fast Load với `TABLOCK,CHECK_CONSTRAINTS`, commit toàn bộ rowset của task. Cột identity `source_row` bắt đầu từ 2 để đối chiếu với số dòng CSV, sau dòng header.

Raw staging giữ nguyên chuỗi nhận từ nguồn. Views `v_Parsed`, `v_Checked`, `v_Accepted` thực hiện chuyển đổi trong SQL, sau đó procedure materialize vào `etl.Stg_Occurrence`. Các Data Flow nạp chiều đọc typed staging qua SQL views để tránh phân tích CSV nhiều lần.

| Thuộc tính | Cách xử lý |
|---|---|
| `eventDate` | Chuyển ngày DD/MM/YYYY bằng TRY_CONVERT(date, ..., 103); chỉ nhận từ 01/01/1980 đến ngày chạy theo múi giờ Việt Nam |
| Vĩ độ và kinh độ | decimal(14,10), kiểm tra 0-23°N và 99-121°E; bảo toàn độ chính xác của nguồn |
| `depth` | decimal(20,10); nguồn sạch đã lấy trị tuyệt đối; giá trị âm mới được coi là lỗi |
| `individualCount` | decimal(18,4), giữ số thập phân nguồn, không ép về int |
| `sst`, `sss` | decimal(8,4); giữ NULL khi thiếu |
| `shoredistance` | decimal(14,4); giữ giá trị âm vì nguồn đánh dấu điểm trên đất liền |
| Phân loại | TRIM; chuỗi trống trở thành NULL; scientificName bắt buộc |
| `flags` và boolean | Giữ flags, chuyển TRUE/FALSE sang bit, kiểm tra khớp cờ ON_LAND |
| `occurrenceStatus` | Chỉ nhận present, absent hoặc NULL; không suy diễn trạng thái thiếu |
| Dải vĩ độ/độ sâu | Tính lại từ giá trị số thay vì tin nhãn nguồn |

ID trống/trùng, ngày sai, tọa độ ngoài phạm vi, số không hợp lệ, thiếu tên khoa học, chuỗi quá dài, boolean/trạng thái sai và cờ không khớp được ghi vào `etl.Reject`, gồm batch, dòng nguồn, ID, nguyên nhân và bản ghi JSON. Nguồn phải có ít nhất một bản ghi hợp lệ. Với `MaxRejects=0`, bất kỳ reject nào cũng làm task fail trước khi cập nhật kho chính.

## 2.5 Nạp các bảng chiều và fact

### 2.5.1 Dim_Date

Khóa ngày là số YYYYMMDD. Chiều chứa event_date, year, decade, quarter, month và season. Chỉ nạp 2.314 ngày thực tế có quan sát. Decade có dạng 1980s; quarter là Q1-Q4. Season là nhóm tháng quy ước: Spring tháng 3-5, Summer 6-8, Autumn 9-11, Winter 12/1/2; không diễn giải thành mùa gió mùa đặc thù của từng địa điểm.

### 2.5.2 Dim_Taxon

Natural key là scientificName với so sánh binary, tạo 7.737 đơn vị phân loại. Giữ kingdom, phylum, class, order, family, genus, species, scientificName và taxon_rank. Rank được suy ra khi tên khoa học khớp tên bậc tương ứng; trường hợp còn lại là unknown.

Dữ liệu có 7.747 tổ hợp phân loại cho 7.737 tên khoa học, trong đó 10 tên có nhiều phương án. Quy tắc chọn: bộ có nhiều trường được điền nhất, sau đó tần suất bản ghi lớn nhất, sau đó dòng nguồn xuất hiện sớm nhất. Tất cả phương án được ghi tại `etl.TaxonConflict`. Quy tắc bảo đảm nạp được một dòng mỗi tên; không thay thế việc chuyên gia xác minh các bất đồng như Azadinium hoặc Beggiatoa.

### 2.5.3 Dim_Location

Chiều có 3.067 dòng, định danh bởi tổ hợp latitude, longitude, country, shoredistance, sst, sss. Có 3.051 cặp tọa độ duy nhất; khác biệt thông tin quốc gia/môi trường làm tăng số dòng chiều. Khóa kỹ thuật SHA-256 tạo từ JSON có giá trị NULL tường minh, giúp join không làm mất các bản ghi thiếu country/SST/SSS.

grid_cell là ô 1° theo FLOOR tọa độ. Dải vĩ độ chia tại 5°, 10°, 15°, 20°. SST chia `<25°C`, `[25,27)`, `[27,29)`, `>=29°C`. country không được điền bằng suy luận không gian. SST/SSS được xem là thuộc tính môi trường có trong nguồn; chưa xác nhận đó là số đo đồng thời với eventDate.

### 2.5.4 Dim_Depth_Band

| ID | Dải độ sâu | Biên dưới | Biên trên |
|---:|---|---:|---:|
| 0 | Unknown | NULL | NULL |
| 1 | Coastal/surface | 0 | 50, không bao gồm |
| 2 | Continental shelf | 50 | 200, không bao gồm |
| 3 | Continental slope | 200 | 1.000, không bao gồm |
| 4 | Deep sea | 1.000, bao gồm | Không giới hạn |

46.440 quan sát thiếu độ sâu được liên kết ID 0, đồng thời depth vẫn NULL. Nhãn nhóm cuối dùng `>=1000 m` để khớp quy tắc `depth<1000` của mã làm sạch trong báo cáo hiện tại.

### 2.5.5 Dim_Quality

Natural key gồm flag_on_land, flags, occurrenceStatus. Có 26 nhóm thực tế, không phải 17. Giữ NULL của trạng thái quan sát để phân biệt thiếu thông tin với vắng mặt. Mọi bản ghi ON_LAND vẫn được nạp có cờ, cho phép người phân tích lọc rõ ràng; không bỏ thêm dữ liệu đã được chương 1 chấp nhận.

### 2.5.6 Fact_Occurrence

Grain là một ID quan sát OBIS. SQL Source join typed staging với 5 chiều trong schema load; OLE DB Destination nạp `load.Fact_Occurrence`. Fact chứa 5 khóa ngoại, depth, individualCount và occurrence_count=1. Không dùng scientificName có species thiếu làm bằng chứng một loài đã được định danh ở bậc species; truy vấn số loài cần lọc rank phù hợp.

Sau nạp, `etl.usp_Publish` kiểm tra accepted count bằng fact count, source count bằng accepted cộng reject, và không có khóa chiều không giải được. Các bảng dbo được thay thế trong một transaction, dimension trước rồi fact. Nếu publish lỗi, rollback toàn bộ. Đây là nạp snapshot đầy đủ; không phải incremental load.

## 2.6 Chạy package và kết quả kiểm chứng

**Bước 1.** Chạy package trong Visual Studio hoặc dùng script:

```powershell
.\scripts\run-etl.ps1
sqlcmd -S . -E -d MARINE_SHIFT_RANGE_DW -b -f 65001 -i .\sql\04_verify.sql
```

**Bước 2.** Đọc kết quả trực tiếp trong SSMS:

```sql
SELECT * FROM etl.Batch ORDER BY batch_id;
SELECT TOP (10) * FROM dbo.Fact_Occurrence ORDER BY id;
SELECT * FROM etl.Reject ORDER BY reject_id;
```

**Bước 3.** Build project với configuration Development. Visual Studio báo 1 project succeeded, 0 failed, tạo `MARINE_SHIFT_RANGE_SSIS.ispac`.

| Bảng | Số dòng nguồn suy ra | Số dòng sau nạp |
|---|---:|---:|
| Dim_Date | 2.314 | 2.314 |
| Dim_Taxon | 7.737 tên khoa học | 7.737 |
| Dim_Location | 3.067 ngữ cảnh vị trí | 3.067 |
| Dim_Depth_Band | 4 dải và Unknown | 5 |
| Dim_Quality | 26 nhóm | 26 |
| Fact_Occurrence | 108.680 ID | 108.680 |

Kiểm tra SQL so sánh cả tập ID và các thuộc tính quan sát sau join ngược với staging: ngày, tên khoa học, tọa độ, môi trường, trạng thái, flags, depth và individualCount đều khớp. Kiểm tra số bằng decimal(28,12) xác nhận không làm tròn mất chữ số của nguồn hiện tại. Tổng occurrence_count bằng 108.680; missing depth là 46.440, missing individualCount là 67.044.

Kiểm thử chạy lại cùng file cho cùng SHA-256 của nội dung cả 6 bảng. Fixture 4 dòng gồm 1 dòng hợp lệ và 3 dòng lỗi (ID trùng, ngày 31/02/2020, SST không phải số) tạo batch FAILED với 3 reject; hash 6 bảng đã publish không đổi. Sau thử lỗi, nguồn đầy đủ được nạp lại, kiểm chứng cuối cùng PASS. Cảnh báo performance counters của SSIS do quyền shared memory không ảnh hưởng việc nạp hoặc kết quả đối soát.

Bằng chứng nằm tại `evidence/warehouse-validation.json`, `integration-tests.json`, `final-run.log`, `reject-test.log`, `rerun-test.log`, `sql-validation.txt`, `visual-studio-build.log`. Các đường dẫn máy cá nhân trong bản log công khai được thay bằng `<REPO>`; log runtime nguyên gốc giữ trong thư mục runs cục bộ.

## 2.7 Phạm vi sử dụng kết quả

Kho sẵn sàng làm nguồn cho phần SSAS/OLAP tiếp theo. Cần cập nhật phần mô tả chương 1: Dim_Quality có 26 dòng; Dim_Taxon có species; Dim_Location có thêm khóa kỹ thuật location_key; các measure dùng decimal để giữ đúng nguồn thay vì mô tả individualCount là số nguyên.

Dữ liệu thể hiện quan sát và mức độ lấy mẫu không đồng đều. Chưa thể quy SST của nguồn là chuỗi nhiệt độ theo thời gian hoặc kết luận biến đổi khí hậu gây dịch chuyển chỉ từ kho này. Phân tích cần kiểm soát flags, trạng thái quan sát, bậc định danh và mức độ lấy mẫu; nếu cần quan hệ nhiệt độ theo năm, bổ sung dữ liệu môi trường có thời điểm rõ ràng.

Tài liệu đầu vào: báo cáo đồ án hiện tại, báo cáo mẫu IS217.Q11 và bản ZIP MARINE_SHIFT_RANGE_SSIS của tác giả. Tài liệu kỹ thuật: [Microsoft Learn về Execute SQL Task](https://learn.microsoft.com/en-us/sql/integration-services/control-flow/execute-sql-task?view=sql-server-ver17), [Microsoft Learn về tạo package bằng runtime](https://learn.microsoft.com/en-us/sql/integration-services/building-packages-programmatically/creating-a-package-programmatically?view=sql-server-ver16). File nguồn được ghi fingerprint trong `data/manifest.json`.
