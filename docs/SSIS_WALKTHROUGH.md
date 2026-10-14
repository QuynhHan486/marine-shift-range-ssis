# Hướng dẫn xây dựng và trình bày SSIS cho đồ án sinh vật biển

Tài liệu để học và tự dựng lại package. Chưa chạy lại package, chưa thay đổi database và chưa triển khai SSAS trong lần soạn này. Các ví dụ SQL phải thực hiện trong database thực hành riêng khi bạn bắt đầu làm.

## 1. Những điều cần sửa trước khi quay video

Chương 2 của báo cáo mới, trang 67–79, thể hiện kết nối SSMS, cấu hình Management Data Warehouse/Data Collection và tạo project Visual Studio. Trang 79 mới tới tiêu đề "Drop All Tables"; chưa có Data Flow nạp nguồn, dimensions, fact, xử lý lỗi hay kết quả đối soát. Vì vậy, phần này chưa đủ để xác nhận SSIS của đồng đội đã hoàn chỉnh hoặc tối ưu.

Trang 68–77 cấu hình Management Data Warehouse và System Data Collection Sets, là hệ thống thu thập dữ liệu quản trị SQL Server. Bạn không cần thực hiện các wizard này để nạp CSV OBIS vào star schema. Hãy tạo database nghiệp vụ riêng, chẳng hạn MARINE_SHIFT_RANGE_DEMO. [Microsoft: Data collection](https://learn.microsoft.com/en-us/sql/relational-databases/data-collection/data-collection?view=sql-server-ver17)

Workspace hiện có triển khai chi tiết hơn ở ssis/Package.dtsx, sql/01_schema.sql, sql/02_views.sql, sql/03_procedures.sql và docs/CHUONG_2_SSIS.md. Đây là mã/tài liệu trong workspace, không phải kết quả đã được chứng minh bởi ảnh trong Chương 2 mới. Kiến trúc staging, reject, đối soát và transaction publish của mã này là nền tảng hợp lý; tuy nhiên, nó chưa khớp quyết định mới của nhóm.

| Điểm kiểm tra | Hiện tại | Cách xử lý khi dựng lại |
|---|---|---|
| CSV | 108.680 dòng, 23 cột; đã bỏ flag_marine_unsure | Dựng metadata đúng 23 cột |
| Package và SQL cũ | Vẫn dùng 24 cột, bắt buộc flag_marine_unsure | Bỏ cột khỏi connection/source/mappings, staging, validation, quality key, SELECT/INSERT |
| species | Có trong CSV và SQL; thiếu trong bảng mô tả Dim_Taxon trang 60 | Bổ sung trong mô tả và giữ để đếm loài |
| occurrence_count | Có trong SQL; bảng fact trang 64 chưa thể hiện | Bổ sung int, giá trị 1, vào thiết kế mới |
| Dim_Quality | Trang 63 ghi 17 dòng | CSV có 26 tổ hợp on-land/flags/status; 17 là số chuỗi flags khác nhau |
| Nhóm SSS/khoảng cách bờ | Chưa có trong Dim_Location | Tạo helpers trong SQL/SSIS hoặc DSV |
| Dim_Date | Chỉ có 2.314 ngày xuất hiện trong nguồn | Tạo lịch liên tục để giữ các kỳ không có dữ liệu |
| Số đo | Báo cáo dùng float/int; SQL dùng decimal | Chọn precision/scale đủ; giữ NULL |
| Vị trí | 3.067 ngữ cảnh vị trí, 3.051 cặp tọa độ | #7 đếm cặp tọa độ, không đếm location ID |

Không phục hồi flag_marine_unsure đã xóa. Đừng chạy nguyên package cũ với CSV 23 cột: việc mất một trường ở giữa có thể làm lệch metadata phía sau.

Nếu dùng mã cũ làm mẫu, lưu bản sao vào project thực hành rồi sửa SQL/package đồng bộ. Script cũ dùng IF OBJECT_ID ... IS NULL chỉ tạo bảng chưa tồn tại, không tự sửa bảng đã có. Dựng database demo mới giúp tránh hiểu nhầm rằng chạy lại script là đã sửa schema.

## 2. SSIS liên hệ với SQL như thế nào?

T-SQL là phương ngữ của SQL Server; PL/SQL là ngôn ngữ thủ tục của Oracle. Ở đây, SSIS điều phối các công việc đọc/biến đổi/ghi, còn SQL trong các tasks chạy ở SQL Server.

| Thành phần | Chức năng | Liên hệ kiến thức SQL |
|---|---|---|
| Package .dtsx | Một quy trình tích hợp | Toàn bộ quy trình nhiều bước |
| Control Flow | Thứ tự và điều kiện chạy | Thứ tự gọi procedure |
| Execute SQL Task | Chạy SQL/procedure | EXEC etl.usp_ValidateStage |
| Data Flow Task | Đọc, xử lý và ghi nhiều dòng | Đường xử lý một tập dữ liệu |
| Flat File Source | Đọc CSV | Nguồn ngoài database |
| OLE DB Source | Đọc bảng/view/SELECT | SELECT ... FROM ... |
| Derived Column | Tạo/sửa giá trị từng dòng | Biểu thức SELECT, 1 AS occurrence_count |
| Conditional Split | Chia dòng ra nhánh | Điều kiện tương tự CASE/WHERE |
| Lookup | Tìm surrogate key | JOIN theo natural key |
| OLE DB Destination | Nạp nhiều dòng | Bulk insert |
| Connection Manager | Truy cập nguồn/đích | Kết nối server hoặc file |

Mũi tên giữa Control Flow tasks là điều kiện chạy bước tiếp theo. Đường nối trong Data Flow là các dòng dữ liệu đi giữa components. Đây là hai tầng khác nhau.

Bạn không cần biến tất cả SQL thành components SSIS. Với nguồn này, có thể đọc vào raw staging, chuyển đổi bằng T-SQL rồi dùng SSIS nạp dimensions/fact. Đây là ELT có staging: SSIS vẫn đọc, ghi và điều phối; SQL xử lý biến đổi. Kiến thức T-SQL giúp bạn kiểm tra logic trực tiếp.

## 3. Kiến trúc nên dựng

~~~mermaid
flowchart TD
  A[Bắt đầu batch] --> B[Làm rỗng bảng làm việc]
  B --> C[CSV vào raw staging]
  C --> D[Chuyển kiểu và kiểm tra; ghi reject]
  D --> E[Nạp Dim_Date]
  E --> F[Nạp Dim_Taxon]
  F --> G[Nạp Dim_Location]
  G --> H[Nạp Dim_Depth_Band]
  H --> I[Nạp Dim_Quality]
  I --> J[Giải khóa và nạp Fact_Occurrence]
  J --> K[Đối soát và publish bằng transaction]
  D -. Lỗi .-> L[Ghi batch FAILED]
~~~

| Schema | Nội dung | Mục đích |
|---|---|---|
| etl | Raw/typed staging, batch, reject | Giữ đầu vào, giải thích lỗi |
| load | Dimensions/fact cho lần chạy hiện tại | Chuẩn bị snapshot mới |
| dbo | Dimensions/fact đã publish | SSAS đọc bản đã đối soát |

Raw staging giữ chuỗi nguồn; typed staging giữ dữ liệu đã chuyển kiểu, NULL và helper keys. Không cần đọc CSV năm lần để tạo năm dimensions.

Đây là full snapshot load: lần thành công thay toàn bộ snapshot. Incremental load, SCD Type 2 và parallel load là mở rộng sau. Với 108.680 dòng, ưu tiên quy trình rõ ràng, có thể chạy lại và kiểm tra đúng trước khi tối ưu tốc độ.

## 4. Chuẩn bị database và kiểu dữ liệu

1. Xác định instance trong SSMS. Dấu chấm chỉ đúng với default instance trên máy hiện tại; named instance dùng TENMAY\INSTANCE.
2. Kiểm tra Visual Studio có template Integration Services Project. Nếu thiếu, kiểm tra extension SQL Server Integration Services Projects.
3. TargetServerVersion phải phù hợp runtime sẽ chạy package. Workspace đang target SQL Server 2025; máy khác có thể khác.
4. Kiểm tra Microsoft OLE DB Driver for SQL Server đã cài.
5. Tạo database demo, rồi tạo schemas, bảng, views và procedures theo thiết kế đã cập nhật. DDL là bước khởi tạo, không cần Drop All Tables mỗi lần chạy.
6. Tạo PK, unique natural-key constraints và năm FK ở dbo.Fact_Occurrence.

| Thuộc tính | Kiểu SQL gợi ý | Quy tắc |
|---|---|---|
| Occurrence ID | nvarchar(64) | Bắt buộc, duy nhất |
| Taxonomy text | nvarchar(256) | scientificName bắt buộc; cấp khác có thể NULL |
| Ngày | date | DD/MM/YYYY, conversion style 103 |
| Vĩ độ/kinh độ | decimal(14,10) | Giữ chữ số nguồn |
| Độ sâu | decimal(20,10) | NULL không thay thành 0 |
| Individual count | decimal(18,4) | Có số lẻ, không ép int |
| SST/SSS | decimal(8,4) | Giữ NULL |
| Shore distance | decimal(14,4) | Giữ số âm để audit |
| On-land flag | bit | Tách khỏi flags text |
| Occurrence count | int | Luôn 1 |

Precision/scale trên theo triển khai hiện có và nguồn đã kiểm tra trước đó. Với nguồn mới phải kiểm tra lại chữ số/range. Các keys và số nhóm cố định của file hiện tại không phải quy tắc cho mọi lần nạp.

## 5. Project, variables và connections

### 5.1 Project

1. Visual Studio → Create a new project → Integration Services Project.
2. Đặt tên MarineOccurrenceDemo, lưu thư mục thực hành.
3. Mở Package.dtsx, tên hiển thị MarineOccurrenceETL.
4. Mở Variables, scope package:

| Variable | Type | Giá trị |
|---|---|---|
| User::ServerName | String | Instance dùng trong SSMS |
| User::DatabaseName | String | MARINE_SHIFT_RANGE_DEMO |
| User::DataFile | String | Đường dẫn tuyệt đối CSV |
| User::MaxRejects | Int32 | 0 nếu yêu cầu nạp đủ nguồn sạch |
| User::BatchId | Int64 | Nhận từ SQL Begin Batch |

Variables đủ để học trong Visual Studio. Khi deploy SSISDB, có thể chuyển cấu hình sang project parameters/environment references. Package variables và project parameters là hai cơ chế khác nhau.

### 5.2 OLE DB connection

1. Connection Managers → New OLE DB Connection → New.
2. Chọn driver SQL Server đã cài, server, Windows Authentication và database demo.
3. Test Connection; tên Warehouse.
4. Nếu dùng application lock kiểu Session của procedure cũ, tạo AuditSession với RetainSameConnection=True. Begin/Validate/Publish/Fail cần cùng phiên để giải phóng đúng khóa.
5. Có thể đặt Properties → Expressions → ConnectionString từ variables. Lần học đầu kết nối cố định dễ kiểm tra hơn.
6. ProtectionLevel=DontSaveSensitive khi không lưu mật khẩu. Cấu hình encryption/certificate theo instance thực tế.

### 5.3 Flat File connection

1. New Flat File Connection, tên OBIS CSV.
2. General: chọn file, Delimited, Text qualifier là dấu nháy kép, chọn Column names in the first data row, code page 65001 cho UTF-8.
3. Không đánh dấu file UTF-16 chỉ vì muốn output Unicode: file UTF-8 được đọc qua code page, columns có thể dùng DT_WSTR.
4. Columns: dấu phẩy là delimiter; file hiện tại dùng CRLF. Preview phải giữ flags có dấu phẩy bên trong nháy kép trong một ô.
5. Advanced: đúng 23 columns, đúng thứ tự header; đọc ban đầu dạng DT_WSTR chiều dài 512 vào raw staging nvarchar(512).
6. Preview tên loài, ký tự °, ngày, cột cuối; đừng chỉ nhìn dòng đầu.
7. Properties → Expressions → ConnectionString có thể là @[User::DataFile].

Header hiện tại:

~~~text
id,country,decimalLatitude,decimalLongitude,latitude_band,shoredistance,eventDate,depth,depth_band,sst,sss,flags,flag_on_land,kingdom,phylum,class,order,family,genus,species,scientificName,occurrenceStatus,individualCount
~~~

Cấu hình delimiter/metadata theo [Microsoft Flat File tutorial](https://learn.microsoft.com/en-us/sql/integration-services/lesson-1-2-adding-and-configuring-a-flat-file-connection-manager?view=sql-server-2017), nhưng dùng encoding và kiểu dữ liệu của CSV này, không sao chép code page từ file mẫu khác.

## 6. Control Flow: bắt đầu, đọc và kiểm tra

### 6.1 Begin Batch

Kéo Execute SQL Task, tên SQL Begin Batch. Nếu dùng procedures của mẫu hiện có sau khi chỉnh schema:

~~~sql
EXEC etl.usp_BeginBatch ?;
~~~

Connection AuditSession, ResultSet Single row. Parameter Mapping: User::DataFile, Input, NVARCHAR, Parameter Name 0, size đủ đường dẫn (2048). Result Set: Result Name 0 → User::BatchId.

OLE DB dùng marker ? và parameter ordinal bắt đầu từ 0; ADO.NET dùng cách đặt tên khác. [Microsoft Execute SQL Task](https://learn.microsoft.com/en-us/sql/integration-services/control-flow/execute-sql-task?view=sql-server-ver17)

Batch ID ghi lần chạy, file, thời gian, accepted/rejected, kết quả publish. Application lock giúp hai lần chạy không dùng chung bảng làm việc cùng lúc.

### 6.2 Clear Working Tables

Execute SQL Task tiếp theo, nối bằng Success:

~~~sql
EXEC etl.usp_ClearWorking;
~~~

ResultSet None. Chỉ clear raw/typed staging và load tables; snapshot dbo giữ tới lúc publish thành công. Không Drop All Tables mỗi lần. Bảng được FK tham chiếu không thể tùy ý TRUNCATE; mẫu dùng load tables không có các FK đó.

### 6.3 CSV to Raw Staging

1. Kéo Data Flow Task, tên DFT CSV to Raw Staging; double-click.
2. Kéo Flat File Source, chọn OBIS CSV.
3. Kéo OLE DB Destination, nối data path.
4. Warehouse; Table or view - fast load; etl.Stg_OccurrenceRaw.
5. Mappings: map 23 columns theo tên; không map identity source_row.
6. Kiểm tra giữ NULL, constraints/table lock. Không Keep identity khi nguồn không cung cấp identity.
7. Error Output không Ignore failure. Parser/truncation errors phải fail hoặc có nhánh lưu lỗi; validation nghiệp vụ ở bước sau.

Fast Load ghi hàng loạt. Maximum insert commit size=0 là commit toàn rowset của task; không thay transaction publish toàn kho. [Microsoft OLE DB properties](https://learn.microsoft.com/en-us/sql/integration-services/data-flow/ole-db-custom-properties?view=sql-server-ver17)

Có thể bật Data Viewer trên path để nhìn vài dòng trong video; nó tạm dừng pipeline, nên tắt khi đo tốc độ. Số dòng trên path là một bằng chứng nạp đúng.

### 6.4 Validate and Transform

Execute SQL Task, ResultSet None:

~~~sql
EXEC etl.usp_ValidateStage ?, ?;
~~~

Parameter 0: BatchId, BIGINT. Parameter 1: MaxRejects, LONG. Procedures/views phải đã bỏ marine-unsure field.

Ví dụ chuyển kiểu:

~~~sql
SELECT source_row,
       NULLIF(TRIM(id), N'') AS id,
       TRY_CONVERT(date, NULLIF(TRIM(eventDate), N''), 103) AS event_date,
       TRY_CONVERT(decimal(14,10), NULLIF(TRIM(decimalLatitude), N'')) AS latitude,
       TRY_CONVERT(decimal(20,10), NULLIF(TRIM(depth), N'')) AS depth_m,
       TRY_CONVERT(decimal(18,4), NULLIF(TRIM(individualCount), N'')) AS reported_count
FROM etl.Stg_OccurrenceRaw;
~~~

NULLIF chuyển trống thành NULL. TRY_CONVERT cho NULL khi chuỗi không hợp lệ; phải kiểm tra cả raw string để phân biệt trống và dữ liệu sai. Chỉ dùng TRY_CONVERT rồi chấp nhận mọi NULL sẽ che mất lỗi.

| Nhóm | Kiểm tra | Hành động |
|---|---|---|
| ID | Trống/trùng/quá dài | Reject và ghi lý do |
| Ngày | Sai hoặc ngoài phạm vi đã chấp nhận | Reject; upper bound là ngày chạy |
| Coordinates | Không phải số; ngoài 0–23°N/99–121°E | Reject theo phạm vi nguồn |
| Taxonomy | Thiếu scientificName/xung đột | Thiếu tên bắt buộc reject; xung đột log |
| Số đo tùy chọn | Trống hoặc chuyển số thất bại | Trống giữ NULL; sai số reject |
| Depth/count | Âm không hợp lệ | Reject; không lấy trị tuyệt đối lần nữa |
| Shore distance | Âm | Giữ để audit |
| Boolean/status | TRUE/FALSE; present/absent/NULL | bit; thiếu status không đổi thành absent |
| Flags | Bit ON_LAND khớp token ON_LAND? | Kiểm tra/log hoặc reject theo policy đã nêu |

Flagged records không nhất thiết là lỗi kỹ thuật nạp. ON_LAND vẫn có thể cần cho #1/#14; không loại tất cả flags ngay ở SSIS.

Đối soát: source_rows = accepted_rows + rejected_rows. MaxRejects=0 chặn publish nếu có bất kỳ reject. Nếu cho phép chỉ nạp phần hợp lệ phải nêu quy tắc trong báo cáo.

## 7. Dimensions: nạp trước fact

Mỗi chiều có Data Flow: OLE DB Source → OLE DB Destination. Source đọc view/query biến đổi; destination load.Dim_...; fast load, mappings rõ ràng. Đừng tạo dimension bằng cách đọc lại toàn CSV nhiều lần nếu typed staging đã có.

### 7.1 Dim_Date

Key gợi ý YYYYMMDD, ví dụ 20150721. Các thuộc tính: event_date, year, decade, quarter, month, season. Seasons theo lịch: Spring tháng 3–5, Summer 6–8, Autumn 9–11, Winter 12/1/2.

Nên tạo lịch đầy đủ từ 1980-01-01 tới ngày 31/12 của năm cuối trong nguồn (hiện tại 2026-12-31), thay vì DISTINCT ngày quan sát. Số ngày mới không còn đúng 2.314. Ngày không có fact vẫn tồn tại trong dimension; điều đó không có nghĩa đã có khảo sát mà không thấy loài.

Ví dụ source query, kiểm tra output metadata và điều chỉnh tên/độ dài text đúng bảng:

~~~sql
DECLARE @last_date date = (SELECT DATEFROMPARTS(YEAR(MAX(eventDate)),12,31) FROM etl.Stg_Occurrence);

WITH calendar AS (
    SELECT CONVERT(date, '19800101') AS event_date
    UNION ALL
    SELECT DATEADD(day, 1, event_date)
    FROM calendar
    WHERE event_date < @last_date
)
SELECT CONVERT(int, CONVERT(char(8), event_date, 112)) AS id,
       event_date,
       YEAR(event_date) AS [year],
       CONVERT(nvarchar(10), CONCAT(YEAR(event_date)/10*10, N's')) AS decade,
       CONVERT(nvarchar(2), CONCAT(N'Q', DATEPART(quarter, event_date))) AS [quarter],
       MONTH(event_date) AS [month],
       CONVERT(nvarchar(10), CASE
          WHEN MONTH(event_date) IN (12,1,2) THEN N'Winter'
          WHEN MONTH(event_date) IN (3,4,5) THEN N'Spring'
          WHEN MONTH(event_date) IN (6,7,8) THEN N'Summer'
          ELSE N'Autumn'
       END) AS season
FROM calendar
OPTION (MAXRECURSION 0);
~~~

Validate stage phải đảm bảo có accepted rows trước query này. Nếu tạo lịch độc lập với nguồn, chọn last_date theo mục đích. Trong contract MDX, Decade dùng numeric key 1980/1990/... với caption 1980s/1990s/...; Season dùng keys 1 Winter, 2 Spring, 3 Summer, 4 Autumn. Tạo helper keys trong SQL/DSV hoặc thêm vào dimension; không dùng caption text làm key nếu bản MDX tham chiếu numeric key. MDX Lag/PrevMember cần Year/Decade có thứ tự thời gian và đầy đủ kỳ muốn phân tích. Năm/tháng/quý trong natural hierarchy cần keys đúng; tháng 1 của năm 2000 khác tháng 1 năm 2001 nếu dùng hierarchy Year→Month.

### 7.2 Dim_Taxon

Natural key scientificName; surrogate ID của dimension. Giữ kingdom, phylum, class, order, family, genus, species, scientificName và taxon_rank.

Nguồn có 7.737 scientific names nhưng 7.747 tổ hợp taxonomy. SELECT DISTINCT mọi thuộc tính không đảm bảo một dòng mỗi scientificName. Cần quy tắc chọn và conflict log. Quy tắc mẫu: bộ đầy đủ nhất, tiếp theo tần suất cao nhất, cuối cùng source_row sớm nhất. Đây là quy tắc kỹ thuật lặp lại được, không phải xác nhận sinh học.

COUNT(DISTINCT taxon_id) là số đơn vị taxonomy, không phải số loài. Cube cần Species attribute key tên species; những taxon cùng species chỉ đếm một lần. Thiếu species thành member Unknown và loại khỏi phép đếm loài.

Completeness từ dimension là completeness sau khi chọn taxonomy đại diện. Nếu #1 cần thiếu trên từng occurrence đầu vào, tạo helper từ typed staging trước bước này, giữ theo occurrence ID hoặc audit view. Không suy ra đầu vào đầy đủ từ dimension đã chuẩn hóa.

### 7.3 Dim_Location

Một row location hiện tại đại diện ngữ cảnh latitude, longitude, country, shoredistance, SST và SSS. Có 3.067 context rows nhưng 3.051 cặp tọa độ. #7 cần Coordinates attribute key theo cặp lat/lon; không đếm location_id và gọi là sampled locations.

| Helper | Quy tắc |
|---|---|
| Latitude band | [0,5), [5,10), [10,15), [15,20), [20,23]; numeric keys 0/5/10/15/20 |
| Grid | FLOOR(latitude), FLOOR(longitude); key cặp chỉ số |
| SST group | Mẫu hiện có <25, [25,27), [27,29), ≥29; thêm Unknown |
| SSS group | Keys: -1 Unknown; 0 khi <30; 1 khi [30,32); 2 khi ≥32; đơn vị theo nguồn, cần xác nhận provenance |
| Shore-distance group | Inland <0; [0,10000), [10000,50000), ≥50000 mét; thêm Unknown |

Ngưỡng là lựa chọn mô tả của đồ án, không phải các ranh giới sinh thái đã được xác nhận. #6 xem SST × SSS rồi slice decade/shore distance để tránh bảng nhiều tổ hợp rỗng.

Country NULL thành Unknown trong cube; giữ NULL trong warehouse nếu muốn và tạo COALESCE helper ở DSV. Không suy luận country từ coordinates khi chưa có ranh giới/quy tắc riêng.

Location key phải xử lý NULL nhất quán. SQL điều kiện l.country=s.country không match hai NULL. Mã hiện có hash SHA-256 từ JSON có NULL tường minh. Nếu tự dùng multi-column JOIN, phải null-safe ở tất cả cột tùy chọn, không thay NULL số đo bằng 0, và mỗi staging row phải match đúng một dimension row.

### 7.4 Dim_Depth_Band

Năm dòng cố định: Unknown ID 0; [0,50) ID 1; [50,200) ID 2; [200,1000) ID 3; ≥1000 ID 4. Giữ depth số ở fact, band ở dimension.

Depth đúng 200 thuộc tầng sâu; đúng 50 thuộc ID2; đúng 1000 thuộc ID4. NULL map ID0, không map surface ID1. #13 dùng Animalia IDs3/4 chia cho Animalia IDs1/2/3/4.

### 7.5 Dim_Quality

Sau xóa marineflag, natural key là tổ hợp flag_on_land, flags, occurrence_status. Cùng flags có thể có status khác; không dùng chỉ flags làm key. Nguồn hiện vẫn có 26 tổ hợp.

DSV có thể tạo helpers: On Land bit, Occurrence Status có Unknown, Flag Consistency, Depth Issue, Accepted Name Issue. Không gộp NULL status với absent. Nhận diện quality flags theo token; quy tắc Depth Issue phải thống nhất danh sách flags được xem là vấn đề độ sâu trong contract MDX.

Ví dụ chuỗi [NO_DEPTH, ON_LAND] cần hai tokens. Có thể bỏ ngoặc và split theo comma; chuẩn hóa trim/case trước so khớp. Không phục hồi deleted flag_marine_unsure.

## 8. Fact: giải keys và tạo measures

Grain: một row cho một occurrence ID nguồn. Five FKs trỏ Date, Taxon, Location, Depth Band, Quality. Measures lưu vật lý: depth, individualCount và occurrence_count=1.

Hai cách giải keys:

1. Cách SQL: OLE DB Source SELECT JOIN typed staging với dimensions load. Phù hợp khi bạn biết T-SQL và có location/quality keys phức tạp.
2. Cách component: OLE DB Source typed staging → các Lookup lấy surrogate IDs → Derived Column → OLE DB Destination. No-match phải log/fail, không bỏ dòng im lặng.

Chỉ cần chọn một cách; không JOIN rồi Lookup lại cùng các keys. Full Cache hữu ích với dimension nhỏ nhưng kiểu số, text và comparison semantics phải thống nhất; không có Lookup nào thay được uniqueness của dimension. [Microsoft Lookup transformation](https://learn.microsoft.com/sql/integration-services/data-flow/transformations/lookup-transformation)

Ví dụ JOIN:

~~~sql
SELECT s.id,
       d.id AS date_id, t.id AS taxon_id, l.id AS location_id,
       s.depth_band_id, q.id AS quality_id,
       s.depth, s.individualCount
FROM etl.Stg_Occurrence AS s
JOIN load.Dim_Date AS d ON d.event_date=s.eventDate
JOIN load.Dim_Taxon AS t ON t.scientificName=s.scientificName
JOIN load.Dim_Location AS l ON l.location_key=s.location_key
JOIN load.Dim_Quality AS q ON q.quality_key=s.quality_key;
~~~

Nếu dùng mẫu SQL hiện có, giữ binary collation đã chọn cho scientificName trong cả tạo keys/JOIN. Kiểm tra count trước/sau JOIN: missing dimension keys làm mất dòng; dimension natural key trùng làm nhân dòng.

Để minh họa Derived Column:

1. Source query chưa có occurrence_count.
2. Kéo Derived Column giữa Source và Destination.
3. Name occurrence_count, Add as new column, Expression (DT_I4)1.
4. Map output vào load.Fact_Occurrence.occurrence_count.

Giải thích: CSV không có count measure; grain một observation nên ETL tạo 1 mỗi fact. SUM(occurrence_count) là số records; SUM(individualCount) là tổng reported count. Không gọi tổng đó là population.

Nếu Source view đã có 1 AS occurrence_count, không thêm lại cùng tên. Cả SQL expression và SSIS Derived Column đều hợp lệ; component giúp video thể hiện thao tác rõ.

## 9. Đối soát và publish

Trước publish:

~~~text
raw count = accepted count + rejected count
load fact count = accepted count
load fact IDs = accepted IDs
mỗi FK giải đúng một dimension row
SUM(occurrence_count) = COUNT(*)
~~~

Execute SQL Task SQL Reconcile and Publish:

~~~sql
EXEC etl.usp_Publish ?;
~~~

Parameter 0 BatchId BIGINT, ResultSet None. Transaction của procedure thay snapshot: xóa fact cũ trước, xóa dimensions cũ, insert dimensions mới rồi fact, batch SUCCEEDED, commit. Lỗi rollback toàn bộ phần publish.

Đây là publish transaction, không nói rằng toàn bộ CSV-to-staging chạy trong một transaction. Với lỗi đọc/validate nguồn, snapshot dbo trước đó vẫn tồn tại.

Sau publish, SSAS phải process lại; các surrogate IDs của snapshot có thể đổi. Warehouse nạp xong không tự đổi dữ liệu trong cube. Không process cube nếu ETL fail.

## 10. Xử lý lỗi và chạy lại

1. Event Handlers → executable package → OnError.
2. Execute SQL Task gọi FailBatch bằng BatchId và System::ErrorDescription. AuditSession cùng phiên nếu cần release khóa.
3. Success constraints chặn bước tiếp theo khi lỗi.
4. Validation rejects ở etl.Reject; parser/driver errors trước staging ở Progress/Execution Results hoặc error output.
5. Chạy lại sau sửa phải cùng IDs và không append duplicate.

Ví dụ:

~~~sql
EXEC etl.usp_FailBatch ?, ?;
~~~

Parameter 0 BIGINT BatchId; parameter 1 NVARCHAR ErrorDescription, theo độ dài procedure (mẫu 2048). Lỗi trước Begin Batch có thể chưa có BatchId hợp lệ; lưu/read lỗi gốc trong log runtime, đừng để lỗi FailBatch che lỗi đầu tiên.

Tự chứng minh trong database demo:

| Tình huống | Mong đợi |
|---|---|
| Nguồn hợp lệ | SUCCEEDED, đủ facts, zero orphan |
| Chạy lại cùng file | Cùng IDs/count; không nhân đôi |
| Fixture nhỏ ngày 31/02/2020 hoặc SST không phải số | Reject, FAILED; snapshot trước không đổi |

Dùng file lỗi riêng; không sửa file nguồn gốc để minh họa.

## 11. SQL xác nhận kết quả

Các query read-only:

~~~sql
SELECT TOP (5) * FROM etl.Batch ORDER BY batch_id DESC;

SELECT COUNT_BIG(*) AS fact_rows,
       SUM(CONVERT(bigint,occurrence_count)) AS occurrence_sum,
       COUNT(individualCount) AS records_with_count,
       SUM(individualCount) AS reported_count_total
FROM dbo.Fact_Occurrence;

SELECT depth_band_id, COUNT_BIG(*) AS records, COUNT(depth) AS records_with_depth
FROM dbo.Fact_Occurrence
GROUP BY depth_band_id
ORDER BY depth_band_id;

SELECT COUNT_BIG(*) AS orphan_rows
FROM dbo.Fact_Occurrence f
LEFT JOIN dbo.Dim_Date d ON d.id=f.date_id
LEFT JOIN dbo.Dim_Taxon t ON t.id=f.taxon_id
LEFT JOIN dbo.Dim_Location l ON l.id=f.location_id
LEFT JOIN dbo.Dim_Depth_Band b ON b.id=f.depth_band_id
LEFT JOIN dbo.Dim_Quality q ON q.id=f.quality_id
WHERE d.id IS NULL OR t.id IS NULL OR l.id IS NULL
   OR b.id IS NULL OR q.id IS NULL;

SELECT TOP (10) * FROM etl.Reject ORDER BY reject_id DESC;
~~~

Nguồn CSV hiện tại, nếu không lọc thêm:

| Kiểm tra | Giá trị |
|---|---:|
| Occurrence records | 108.680 |
| Missing depth | 46.440 |
| Missing individualCount | 67.044 |
| Records with individualCount | 41.636 |
| Missing species | 55.202 |
| Missing country | 65.538 |
| Missing SST/SSS | 690 mỗi cột |
| Distinct coordinate pairs | 3.051 |
| Current quality combinations | 26 |

Không gắn mọi validator vào counts dimension cố định. Calendar liên tục tăng Dim_Date; thay natural key/chuẩn hóa có thể đổi dimension counts. Helper groups thường không tăng fact count.

sql/04_verify.sql cũ vẫn kiểm tra deleted marineflag, 2.314 dates và schema cũ. Nó không phải validator phù hợp nguyên trạng với thiết kế mới; cập nhật trước khi dùng.

## 12. Handoff sang SSAS

SSIS đưa dữ liệu vào warehouse; SSAS dựng dimensions/relationships/measures từ warehouse; MDX đọc cube. Query draft đang theo tên/contract dự kiến vì chưa có cube model.

Ba numerical columns vật lý của fact vẫn là occurrence_count, individualCount, depth. Để hỗ trợ latitude/SST, đồng đội có thể dùng DSV Named Query JOIN fact với location:

~~~sql
SELECT f.*,
       l.decimalLatitude AS latitude_for_measure,
       l.sst AS sst_for_measure,
       CASE WHEN f.individualCount IS NULL THEN 0 ELSE 1 END AS individual_count_available
FROM dbo.Fact_Occurrence f
JOIN dbo.Dim_Location l ON l.id=f.location_id;
~~~

Dim_Location.id phải unique để JOIN không đổi grain. Các helpers là nguồn cube; không bắt buộc thêm cột fact vật lý.

| Source/helper | Cube dùng |
|---|---|
| occurrence_count | Record Count SUM |
| individualCount | Individual Count SUM |
| individual_count_available | Individual Count Records SUM |
| latitude_for_measure | Latitude Sum, Minimum, Maximum |
| sst_for_measure | SST Minimum, Maximum |
| species | Species text key; Unknown loại khỏi species counts |
| coordinates key | Key cặp latitude/longitude |
| latitude band key | 0/5/10/15/20 và captions |
| sss group, shore distance group | Helpers nhóm cho #6 |

Đặt Source.NullProcessing=Preserve cho nguồn nullable của SST Minimum/Maximum và Individual Count. Không biến SST thiếu thành 0 vì #12 sẽ cho SST_min=0 sai. Giữ NULL của Individual Count; Q15 chỉ trả tổng khi Individual Count Records > 0 và trả NULL nếu không có giá trị được báo cáo.

Quality helpers: On Land bit, Occurrence Status including Unknown, Flag Consistency, Depth Issue, Accepted Name Issue. Taxonomy Complete từ dimension đánh giá taxonomy đã chuẩn hóa; xem hạn chế ở mục 7.2. Đừng tự thêm lại marineflag.

Distinct species, distinct coordinates, percentages, mean latitude, SST range và latitude range là calculated measures; không cộng các distinct counts/ranges/percentages ở nhiều ô để lấy tổng. Cube giúp các measures đáp ứng slice/drill-down, nhưng bạn phải định nghĩa rõ population của từng phép tính.

## 13. Kịch bản quay video

Có thể chia video thành thiết kế, thao tác, kiểm chứng. Thời lượng dưới đây không cố định; ưu tiên hiển thị kết quả và giải thích lý do mỗi bước.

| Thứ tự | Màn hình | Nội dung nói |
|---|---|---|
| 1 | CSV header và vài dòng | 23 columns; ngày text, NULL; marineflag đã bỏ |
| 2 | Star schema | Một occurrence ID mỗi fact; five FKs; numerical columns |
| 3 | Database/schemas | etl lưu đầu vào và lỗi; load chuẩn bị; dbo dùng phân tích |
| 4 | Variables/Connections | Server/database/file; UTF-8, qualifier, Preview |
| 5 | Control Flow | CSV→validate→dimensions→fact→publish |
| 6 | Raw staging DFT | Source/Destination, fast load, mappings |
| 7 | Transformation views | TRY_CONVERT, NULLIF; optional NULL giữ row |
| 8 | Một dimension Data Flow | Query/view source và mapping; các chiều khác tương tự |
| 9 | Fact Data Flow | JOIN/Lookup keys; Derived Column occurrence_count=1 |
| 10 | Package execution | Progress/Execution Results và dòng qua paths |
| 11 | SQL verification | Facts=accepted; SUM count; Unknown depth; zero orphan |
| 12 | Rerun/fixture lỗi | Không nhân đôi; reject có lý do; snapshot trước giữ |
| 13 | Handoff | Process cube sau publish; MDX chạy khi có cube thật |

Các câu giải thích có thể dùng:

- "Một dòng fact tương ứng một lần ghi nhận trong nguồn, không tương ứng một loài hay một cá thể. Vì vậy occurrence_count bằng 1; individualCount giữ count đã báo cáo của observation."
- "Không biết độ sâu khác với độ sâu 0 m. Em giữ NULL và map Unknown. Tỷ lệ tầng sâu chỉ dùng bản ghi có thông tin độ sâu."
- "SSIS đọc file, nạp hàng loạt và điều phối; T-SQL views/procedures thực hiện biến đổi để em kiểm tra logic trực tiếp."
- "Chạy lại an toàn nghĩa là cùng nguồn cho cùng snapshot, không nhân đôi. Khi validate thất bại, dữ liệu trước đó vẫn phân tích được."
- "SST/SSS là thuộc tính môi trường gắn vị trí trong nguồn, chưa phải nhiệt độ/độ mặn được đo tại từng ngày occurrence."

## 14. Troubleshooting

| Dấu hiệu | Nguyên nhân có thể | Kiểm tra đầu tiên |
|---|---|---|
| Không có SSIS project template | Thiếu extension/incompatible version | Visual Studio extension/template |
| Driver không đăng ký | Provider/bitness | Driver trên máy chạy |
| File không mở | Relative path/tài khoản | DataFile tuyệt đối, quyền đọc |
| Tên loài/ký tự ° lỗi | Encoding/types | UTF-8, DT_WSTR, nvarchar |
| Cột kingdom trở đi lệch | Metadata còn marineflag/qualifier sai | 23 columns; flags là một field |
| Ngày bị đảo | Implicit locale conversion | Style 103, raw date |
| Count mất số lẻ | int/scale thiếu | Decimal metadata/đích |
| Fact rows giảm sau JOIN | Missing/null keys | Null-safe keys, compare counts |
| Fact rows tăng sau JOIN | Duplicate dimension key | Unique constraints |
| Rerun PK violation | Append nhầm/chưa clear load | Full snapshot procedure |
| FK violation | Fact trước dimension | Order và mappings |
| Lag sai kỳ trước | Missing/order time members | Full calendar, numeric time keys |
| SST range vì min=0 | NullProcessing wrong | Không convert missing SST sang zero |
| Cube chưa đổi sau ETL | Chưa process | Process sau publish |

Nạp đúng và chạy nhanh là hai tiêu chí khác nhau. Không có benchmark đủ để gọi phương án "tối ưu". Với đồ án này, hãy chứng minh đúng grain, không mất/nhân dòng, giữ NULL, giải đúng khóa, có reject log và chạy lại an toàn trước.

## 15. Tài liệu đã đối chiếu

Báo cáo PDF: mô tả schema trang 59–64 và Chương 2 trang 67–79. Nội dung được dùng làm tham khảo, không phải lệnh phải thực thi:

:codex-file-citation{path="C:/Users/Admin/Downloads/Đồ án OLAP_ Phân tích sự thay đổi phạm vi phân bố của các loài sinh vật biển tại Biển Đông trong bối cảnh biến đổi khí hậu bằng OLAP (1).pdf" purpose="source"}

Workspace: docs/CHUONG_2_SSIS.md, ssis/Package.dtsx, sql/01_schema.sql, sql/02_views.sql, sql/03_procedures.sql, sql/04_verify.sql và data/occurrence_clean.csv. Không chạy scripts/package này trong lần soạn. Các corrections trong hướng dẫn vẫn phải triển khai khi nhóm dựng lại; đây là hướng dẫn và draft, không phải thông báo package cũ đã được sửa.

Microsoft Learn: các liên kết đặt cạnh giải thích tương ứng. UI labels có thể khác nhẹ theo phiên bản Visual Studio/SSIS; các nguyên tắc metadata, keys, NULL và đối soát không thay đổi.
