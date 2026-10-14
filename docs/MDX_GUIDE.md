# Dự thảo MDX cho 15 câu hỏi phân tích

Đây là bản thiết kế cho SSAS **Multidimensional**, chưa phải truy vấn đã chạy trên một cube đang tồn tại. Cube chưa được tạo. Tên cube, dimension, hierarchy, level, member key và measure dưới đây là thỏa thuận đề xuất để người làm SSAS và người viết MDX phối hợp.

Có 15 file riêng trong thư mục `mdx`, và file gộp `mdx/15_analysis_queries.mdx`. Mỗi file riêng có một câu truy vấn đầy đủ, gồm `WITH` khi cần. Chọn một câu hoàn chỉnh để chạy; không chạy cả file gộp như một câu duy nhất. Đây không phải T-SQL và không chạy trong cửa sổ Database Engine.

## 1. Từ T-SQL sang MDX

| T-SQL quen thuộc | Cách hiểu MDX |
|---|---|
| SELECT danh sách cột | Chọn tập measure/member trên COLUMNS |
| GROUP BY | Chọn các thành viên dimension trên ROWS |
| WHERE dòng nguồn | Slicer/subselect thu hẹp dữ liệu dùng để tính các ô |
| HAVING | FILTER lọc tập member/tuple theo một điều kiện |
| TOP N ORDER BY | TOPCOUNT(set, N, measure) |
| GROUP BY hai cột | Crossjoin hai tập member bằng `*` |
| LAG(value) OVER (...) | Lấy member trước bằng `.LAG(1)`, rồi lấy measure tại member đó |
| Cột biểu thức AS alias | `WITH MEMBER [Measures].[Tên] AS biểu_thức` |

Ví dụ Q3:

```mdx
WITH
SET [Known Species] AS
    EXCEPT([Taxon].[Species].[Species].MEMBERS,
           {[Taxon].[Species].&[__UNKNOWN__]})
MEMBER [Measures].[Recorded Species] AS
    COUNT(NONEMPTY(EXISTING [Known Species], {[Measures].[Record Count]}))
SELECT
    {[Measures].[Recorded Species], [Measures].[Record Count]} ON COLUMNS,
    NONEMPTY([Location].[Country].[Country].MEMBERS
             * [Date].[Decade].[Decade].MEMBERS,
             {[Measures].[Record Count]}) ON ROWS
FROM [Marine Range Shift];
```

`[Location].[Country].[Country].MEMBERS` lấy member ở level Country, không lấy All member. `&[Vietnam]` tham chiếu **key**, không phải chỉ caption hiển thị. `([Measures].[Record Count], một_member)` là tuple chỉ định ô dữ liệu. `{...}` là set. `WITH MEMBER` chỉ định nghĩa phép tính trong câu hiện tại; không thêm cột vào bảng FACT.

## 2. Tên cube và các dimension đề xuất

Cube: **[Marine Range Shift]**. Measure group: **Occurrence**.

| Dimension | Bảng nguồn | Attribute hierarchy cần bật |
|---|---|---|
| [Date] | Dim_Date hoặc calendar view đầy đủ | [Decade], [Year], [Season]; Date/Month/Quarter có thể thêm để drill-down |
| [Taxon] | Dim_Taxon | [Kingdom], [Phylum], [Class], [Order], [Family], [Genus], [Species], [Scientific Name], [Taxonomy Complete] |
| [Location] | Dim_Location | [Country], [Latitude Band], [Grid Cell], [Coordinates], [SST Group], [SSS Group], [Shore Distance Group] |
| [Depth Band] | Dim_Depth_Band | [Band] |
| [Quality] | Dim_Quality | [On Land], [Occurrence Status], [Flags], [Flag Consistency], [Depth Issue], [Accepted Name Issue] |

Một attribute hierarchy tên Country có level tên Country, nên đường dẫn level là `[Location].[Country].[Country]`. Hierarchy mặc định phải là All, trừ khi người dùng cố ý chọn bộ lọc. Không đổi default member sang một nước, một năm hay một nhóm độ sâu cụ thể: mẫu tỷ lệ đang giả định default member là All.

Cả năm dimension nối many-to-one từ fact qua FK tương ứng. Không dùng join sinh thêm nhiều dòng từ một occurrence. Không đưa aggregate/source lookup có nhiều dòng cho mỗi location vào nguồn fact.

### Key và caption

| Attribute | Key cần dùng trong bản MDX | Caption |
|---|---|---|
| Date.Decade | integer 1980, 1990, 2000, 2010, 2020 | 1980s, 1990s... |
| Date.Year | integer 1980...2026 | 1980...2026 |
| Date.Season | integer 1, 2, 3, 4 | Winter, Spring, Summer, Autumn |
| Taxon.Kingdom/Class/Species | chính chuỗi tên; chuỗi thiếu thay bằng __UNKNOWN__ | tên hoặc Unknown |
| Location.Country | chuỗi country; thiếu thành __UNKNOWN__ | tên quốc gia hoặc Unknown country |
| Location.Latitude Band | integer 0, 5, 10, 15, 20 | 0-5, 5-10, 10-15, 15-20, 20-23 độ Bắc |
| Location.Grid Cell | chuỗi FLOOR(latitude) + N_ + FLOOR(longitude) + E | ví dụ 20N_114E |
| Location.Coordinates | key ghép **cặp tọa độ**, không dùng location_id | latitude,longitude |
| Depth Band.Band | 0 Unknown; 1 [0,50); 2 [50,200); 3 [200,1000); 4 >=1000 m | tên dải độ sâu |
| Quality.On Land | integer/bit 0,1 | FALSE,TRUE |
| Quality.Occurrence Status | present, absent, __UNKNOWN__ | present, absent, Unknown |
| Quality.Flags | nguyên chuỗi flags như [] hoặc [NO_DEPTH] | chính chuỗi flags |

Latitude band [20,23] bao gồm đúng 23; các dải trước có biên trên mở. Với vùng nghiên cứu hiện tại, band 20 tương ứng latitude >=20, và bands 15+20 tương ứng >=15. Nếu mở rộng vùng nghiên cứu, phải cập nhật hai điều kiện này.

`__UNKNOWN__` là **member bình thường**, tạo qua COALESCE/NULLIF trong nguồn dimension, không phải SSAS system UnknownMember. Như vậy country thiếu luôn xuất hiện trong Q3/Q14/Q15; species thiếu được loại khỏi tập [Known Species]. Không thay species thiếu bằng scientificName vì scientificName có thể là genus, family hoặc bậc khác.

Đặt `OrderBy=Key` cho Year/Decade. Bổ sung calendar đầy đủ 1980-01-01 đến 2026-12-31 để không thiếu năm/thập kỷ khi dùng LAG và tích lũy. FACT vẫn chỉ chứa ngày có quan sát. Repo hiện tại chỉ nạp ngày có quan sát: đây là điểm cần người làm SSAS/SSIS sửa hoặc bổ sung calendar view. Không thêm occurrence giả cho ngày không có dữ liệu.

### Nhóm môi trường và khoảng cách đến bờ

Đây là quy ước của đồ án, không phải ranh giới sinh thái được xác nhận:

| Attribute | Key | Điều kiện |
|---|---:|---|
| SST Group | -1 | SST thiếu |
| SST Group | 0 | SST <25 |
| SST Group | 1 | 25 <= SST <27 |
| SST Group | 2 | 27 <= SST <29 |
| SST Group | 3 | SST >=29 |
| SSS Group | -1 | SSS thiếu |
| SSS Group | 0 | SSS <30 |
| SSS Group | 1 | 30 <= SSS <32 |
| SSS Group | 2 | SSS >=32 |
| Shore Distance Group | -1 | khoảng cách thiếu |
| Shore Distance Group | -2 | khoảng cách âm: inland |
| Shore Distance Group | 0 | 0 <= khoảng cách <10,000 m |
| Shore Distance Group | 1 | 10,000 <= khoảng cách <50,000 m |
| Shore Distance Group | 2 | khoảng cách >=50,000 m |

Giữ cả giá trị gốc lẫn group. Q6 giữ Unknown SST/SSS để không giấu thiếu dữ liệu, nhưng chỉ đưa ba nhóm khoảng cách không âm vào so sánh môi trường biển. Muốn phân tích riêng Unknown SST/SSS thì dùng Q1 hoặc lọc output Q6. Có thể đổi ngưỡng; phải đổi nguồn group và hướng dẫn nhất quán. SST/SSS hiện là ngữ cảnh vị trí, không mặc định là phép đo cùng ngày occurrence.

## 3. Measures: cột FACT, measure cube và calculated member khác nhau

Ba cột đo lường vật lý đã thiết kế vẫn là `occurrence_count`, `individualCount`, `depth`. Không cần thêm 15 cột kết quả truy vấn vào FACT.

Để MDX viết ngắn và đúng, người làm cube nên expose các native measure sau:

| Tên measure chính xác | Nguồn ở grain một occurrence | AggregateFunction |
|---|---|---|
| [Record Count] | occurrence_count=1 | Sum |
| [Individual Count] | individualCount, giữ NULL | Sum |
| [Individual Count Records] | 1 nếu individualCount không NULL, ngược lại 0 | Sum |
| [Latitude Sum] | decimalLatitude của location của từng fact | Sum |
| [Latitude Minimum] | cùng giá trị latitude ở grain fact | Min |
| [Latitude Maximum] | cùng giá trị latitude ở grain fact | Max |
| [SST Minimum] | SST của location của từng fact, giữ NULL | Min |
| [SST Maximum] | cùng SST ở grain fact, giữ NULL | Max |

Những nguồn bổ sung có thể là cột của **Data Source View named query**, không bắt buộc là cột lưu thêm trong FACT. Đây là cách tạo nguồn cube khi sst và latitude nằm trong dimension.

Ví dụ named query dự kiến cho nguồn measure group, chạy trong Database Engine khi thiết kế nguồn, không phải MDX:

```sql
SELECT f.*,
       l.decimalLatitude AS latitude_for_measure,
       l.sst AS sst_for_measure,
       CASE WHEN f.individualCount IS NULL THEN 0 ELSE 1 END
           AS individual_count_available
FROM dbo.Fact_Occurrence AS f
JOIN dbo.Dim_Location AS l ON l.id = f.location_id;
```

Dùng latitude_for_measure cho ba latitude measures, sst_for_measure cho hai SST measures và individual_count_available cho [Individual Count Records]. Named query không INSERT, DELETE hay UPDATE dữ liệu. FK location phải hợp lệ, và Dim_Location.id phải duy nhất.

Đặt **Source.NullProcessing = Preserve** cho nguồn numeric nullable, đặc biệt SST Min/Max và Individual Count. Nếu NULL biến thành 0, SST Minimum có thể thành 0 và Q12 sai. Không giữ default Sum của Cube Wizard cho Min/Max measures. Với dữ liệu đã kiểm tra hiện tại, latitude luôn có giá trị nên centroid dùng Record Count; nếu nguồn sau này cho phép thiếu latitude, thêm Known Latitude Count vào nguồn cube và dùng nó làm mẫu số.

### Helpers cho Q1 ở nguồn dimension

Các attribute 0/1 sau có thể tạo trong DSV named query, không yêu cầu thêm cột vật lý:

- Taxon.Taxonomy Complete: 1 khi kingdom, phylum, class, order, family, genus, species đều không NULL/trống; ngược lại 0.
- Quality.Flag Consistency: 1 khi bit flag_on_land khớp việc token ON_LAND xuất hiện trong flags; ngược lại 0.
- Quality.Depth Issue: 1 khi flags chứa DEPTH_EXCEEDS_BATH, DEPTH_OUT_OF_RANGE hoặc MIN_DEPTH_EXCEEDS_MAX; ngược lại 0.
- Quality.Accepted Name Issue: 1 khi flags chứa NO_ACCEPTED_NAME; ngược lại 0.

Q1 chỉ đánh giá tính đầy đủ của **taxonomy đã chuẩn hóa ở Dim_Taxon**. Khi ETL chọn một taxonomy đại diện cho scientificName có nhiều bộ phân loại, thông tin thiếu của từng dòng nguồn có thể bị che. Muốn kiểm toán đúng dữ liệu trước chuẩn hóa, dùng staging/audit hoặc lưu chỉ báo nguồn theo occurrence; không gọi output Q1 là chất lượng phân loại gốc đã được kiểm chứng chuyên gia.

Không có measure/attribute nào trong bản dự thảo phụ thuộc flag_marine_unsure đã xóa.

## 4. Đọc từng truy vấn

| # | File | Ý chính |
|---:|---|---|
| 1 | 01_quality_by_decade.mdx | Records, richness, sites và tỷ lệ đầy đủ/cờ theo decade |
| 2 | 02_top_season_per_kingdom.mdx | GENERATE mỗi kingdom, TOPCOUNT một season, tỷ trọng trong kingdom |
| 3 | 03_species_country_decade.mdx | Richness theo country x decade, gồm Unknown country |
| 4 | 04_top_three_animal_classes.mdx | Subselect gộp 2000s/2010s, hai latitude bands, depth<200; chọn ba class một lần |
| 5 | 05_species_depth_latitude.mdx | Richness theo depth band x latitude band, gồm Unknown depth |
| 6 | 06_environmental_groups.mdx | Richness, records, sites theo SST/SSS/shore groups x decade |
| 7 | 07_top_five_grids_per_decade.mdx | GENERATE decade+grid tuples, xếp top năm riêng cho mỗi decade |
| 8 | 08_latitude_centroid_animal_classes.mdx | SUM(latitude tại grain fact)/record count cho từng class Animalia |
| 9 | 09_latitude_range_species_decade.mdx | Native latitude Max-Min theo species x decade |
| 10 | 10_northern_species_change.mdx | Northern richness, prior decade, delta và %delta bằng .LAG(1) |
| 11 | 11_first_northern_species_by_year.mdx | Cumulative distinct set phía bắc >=20; new = cumulative hiện tại - trước |
| 12 | 12_top_fifteen_observed_sst_ranges.mdx | TOPCOUNT 15 loài theo native SST Max-Min |
| 13 | 13_deep_animalia_record_share.mdx | Deep bands3+4 / known bands1..4; slice Animalia |
| 14 | 14_country_quality_audit.mdx | Record count, on-land flag %, explicit present % theo country |
| 15 | 15_country_sampling_and_reported_counts.mdx | Country/band/decade records, richness, share, reported counts và coverage |

[Recorded Species] là COUNT của tập species có record trong context, không phải COUNT(taxon_id). [Sampled Sites] là số cặp tọa độ có record; một cặp tọa độ có nhiều location_id do metadata khác vẫn là một vị trí.

`NONEMPTY(row_set, {[Measures].[Record Count]})` dùng record measure để bỏ các tổ hợp không có FACT. Chỉ dùng `NON EMPTY` trên các cột có COUNT(...)=0 có thể giữ lại cả tổ hợp không có dữ liệu.

Tỷ lệ được lưu trong calculated member ở dạng 0..1 và FORMAT_STRING="0.00%". Ví dụ 0.25 hiển thị 25%; không nhân thêm 100 nếu dùng format này. Q2 mẫu số xóa riêng season, Q15 xóa riêng country, vẫn giữ latitude band/decade. Không lấy AVG của các tỷ lệ để ra tổng.

Q4 chọn cùng ba class trong lát cắt gộp, không chọn ba class khác nhau trong từng decade. Q7 giữ tuple decade+grid để không mất decade khi GENERATE union các set. TOPCOUNT lấy tối đa đúng N; không tự trả tất cả trường hợp bằng điểm. Nếu cần tie policy cố định, người làm báo cáo thống nhất quy tắc phụ.

Q10 không biến giai đoạn không lấy mẫu thành số loài bằng 0 để tính mức giảm. Nếu hiện tại hoặc trước đó không có records, delta trả NULL. Q11 vẫn trả năm không có records; cumulative có thể giữ nguyên và new=0 nghĩa là không có loài mới được ghi nhận trong dataset, không phải chứng minh không có loài mới ngoài tự nhiên. Cumulative đếm union species qua năm, không cộng annual distinct species.

Q9/Q12 giữ phiên bản cơ bản theo yêu cầu. Span=0 ở loài chỉ có một vị trí không chứng minh phạm vi hẹp/chịu nhiệt hẹp. Q12 nói khoảng SST ghi nhận, không nói physiological tolerance. Q13 chỉ biết tỷ trọng bản ghi sâu thay đổi, không chứng minh cá thể di chuyển xuống sâu.

Q14 kiểm toán nguồn sạch được đưa vào kho. On-land flag là cảnh báo, không tự động là một lỗi đã xác nhận. Blank status không phải absent. Q15 tổng individualCount là tổng giá trị được báo cáo, không phải quần thể; không có giá trị thì trả NULL, không giả lập 0.

## 5. Khi teammate tạo cube xong

1. Đồng ý tên ở mục 2-3 hoặc sửa các đường dẫn MDX theo tên cube thực tế. Hãy lấy **member unique name/key** trong Cube Browser; caption hiển thị không luôn bằng key.
2. Bật AttributeHierarchyEnabled cho những attribute cần dùng. Xác nhận tên level khớp tên hierarchy trong mẫu.
3. Kiểm tra các quan hệ fact-to-dimension, aggregation và NullProcessing.
4. Process dimensions rồi cube.
5. Trong SSMS chọn Server type Analysis Services, database cube, mở MDX query window.
6. Chạy trước câu đơn giản: SELECT {[Measures].[Record Count]} ON COLUMNS FROM [Marine Range Shift]; Kỳ vọng current CSV có 108,680 records nếu toàn bộ dòng được nạp.
7. Chạy Q3, Q14, Q4 trước; đối chiếu docs/MDX_DATA_BASELINES.md. Sau đó chạy Q7, Q10, Q11, Q12.
8. Nhiều name/key có thể chưa tồn tại trong cube chưa process. Phải xử lý lỗi mapping/processing, không thay kết quả thiếu bằng 0 để giấu lỗi.
9. Chỉ ghi trong báo cáo "đã kiểm thử MDX" sau khi chạy trên cube thật và đối soát kết quả. Các số trong file baselines là tính độc lập từ CSV, không xác nhận cú pháp/runtime SSAS.
10. File source đã giảm còn 23 cột. Các kỳ vọng/schema cũ trong repo có thể cần đồng bộ trước khi chạy lại SSIS; không dùng lại metadata 24 cột một cách tự động.

Không có truy vấn nào đã được chạy trên SSAS trong lần soạn thảo này. Không tạo/deploy cube hoặc chạy lại SSIS/database.

## 6. Tài liệu được dùng

- Tài liệu môn học Introduction to MDX_UIT.pdf: SELECT/COLUMNS/ROWS, slicer, NON EMPTY, FILTER, TOPCOUNT, GENERATE/CURRENTMEMBER.
- Tài liệu dự án mới: Chương 2, các trang PDF 67-79, là nguồn để xem tiến độ mô tả SSIS; không xác nhận một package đã hoàn chỉnh.
- Schema/views trong repository dùng để hiểu tên và grain bảng. Cube names ở đây vẫn là đề xuất.
- [Microsoft Generate](https://learn.microsoft.com/en-us/sql/mdx/generate-mdx): áp dụng ranking theo từng member và giữ tuple thời kỳ.
- [Microsoft NonEmpty](https://learn.microsoft.com/en-us/sql/mdx/nonempty-mdx): lọc set theo cells có dữ liệu.
- [Microsoft EXISTING](https://learn.microsoft.com/en-us/analysis-services/multidimensional-models/mdx/mdx-query-existing-keyword): xét set trong context hiện tại.
- [Microsoft Lag](https://learn.microsoft.com/en-us/sql/mdx/lag-mdx?view=sql-server-ver17): truy cập member trước theo natural order.
- [Microsoft aggregation functions](https://learn.microsoft.com/en-us/analysis-services/multidimensional-models/use-aggregate-functions): chọn Sum/Min/Max và calculated percentages.
- [Microsoft null processing](https://learn.microsoft.com/en-us/dotnet/api/microsoft.analysisservices.nullprocessing): Preserve nguồn nullable.

Đây là tài liệu triển khai và học tập cho nhóm; giữ các định nghĩa "recorded richness", "reported count" và "observed range" khi viết diễn giải khoa học.

Ghi chú Q12: Record Count và Sampled Sites hiển thị mọi bản ghi/vị trí của loài, kể cả bản ghi thiếu SST; chỉ SST Minimum/Maximum và SST Span dùng giá trị SST có dữ liệu.
