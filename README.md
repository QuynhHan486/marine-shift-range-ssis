# Marine Shift Range — SSIS và SSAS

Đồ án Kho dữ liệu và OLAP: phân tích sự thay đổi phạm vi phân bố của sinh vật biển tại Biển Đông trong bối cảnh biến đổi khí hậu.

Nguồn đầu vào duy nhất: `data/occurrence_clean.csv` — **108.680 bản ghi, 23 cột**.

## Nội dung repository

| Đường dẫn | Nội dung |
|---|---|
| `data/` | CSV nguồn, mô tả và fingerprint kiểm tra |
| `sql/demo/` | SQL tạo sáu bảng, khởi tạo nhóm độ sâu và đặt lại dữ liệu demo |
| `ssis_demo/derived_column_expressions.txt` | Biểu thức Derived Column của quy trình SSIS mới |
| `docs/SSIS_DEMONSTRATION_GUIDE.docx` | Hướng dẫn dựng và chạy SSIS mới |
| `docs/BT_OLAP_A1.1_Chuong_2_SSIS.docx` | Báo cáo Word, gồm chương SSIS từ video và kết quả đã xác nhận |
| `ssas/` | Project SSAS Multidimensional, dimensions, cube và Data Source View |
| `mdx/` | 15 câu MDX; xem [mục tiêu và danh sách file](mdx/README.md) |
| `scripts/` | Chạy MDX và đối chiếu kết quả với snapshot warehouse |
| `tests/` | Kiểm tra dataset và phạm vi đối chiếu MDX |
| `evidence/` | Bằng chứng kiểm chứng MDX lịch sử và trạng thái cần kiểm chứng lại |

## SSIS mới

Dùng [hướng dẫn SSIS](docs/SSIS_DEMONSTRATION_GUIDE.docx), các script trong `sql/demo/` và biểu thức trong `ssis_demo/`. Quy trình gồm năm Data Flow Task: Date → Taxon → Location → Quality → Fact. `Dim_Depth_Band` được khởi tạo bằng SQL.

Chỉ dùng `occurrence_clean.csv`; không cần file calendar hoặc taxon riêng. Các bước nạp sử dụng Flat File Source, Derived Column, Sort, Aggregate, Merge Join, Lookup và OLE DB Destination.

**Trạng thái source package:** nhánh `main` hiện chứa hướng dẫn, SQL, biểu thức và báo cáo của SSIS mới. Chưa có file `.dtsx`/`.dtproj` riêng của project mới trong nhánh này. Project và `.ispac` của triển khai SSIS cũ đã được gỡ bỏ. Khi bổ sung source mới, đưa project đã thực hiện vào `ssis_demo/` cùng các biểu thức hiện có.

| Bảng | Số dòng được xác nhận sau demo mới |
|---|---:|
| Dim_Date | 2.314 |
| Dim_Taxon | 7.737 |
| Dim_Location | 3.067 |
| Dim_Depth_Band | 5 |
| Dim_Quality | 26 |
| Fact_Occurrence | 108.680 |

Kết quả và ảnh kiểm tra nằm trong [báo cáo Word](docs/BT_OLAP_A1.1_Chuong_2_SSIS.docx). Những số liệu này là kết quả demo đã được xác nhận, không phải một lần chạy package trong môi trường kiểm tra tự động.

## SSAS và MDX

Mở `MARINE_SHIFT_RANGE.slnx` hoặc `ssas/MARINE_SHIFT_RANGE_SSAS.slnx` trong Visual Studio để mở project SSAS được giữ lại.

Trước khi Deploy/Process, cấu hình Data Source đến đúng server và cơ sở dữ liệu được SSIS mới nạp. Không sử dụng tên database của triển khai cũ chỉ vì nó còn trong cấu hình mẫu. Đối chiếu sáu bảng `dbo`, khóa liên kết, kiểu dữ liệu và các nhóm môi trường với mô hình SSAS trước khi xử lý cube.

Trong SSMS, kết nối **Analysis Services**, chọn database đã triển khai và mở từng file `.mdx`. Tên cube trong nguồn hiện tại là `[MARINE SHIFT RANGE DW]`; measure đếm bản ghi là `[Measures].[Occurrence Count]`.

```mdx
SELECT {[Measures].[Occurrence Count]} ON COLUMNS
FROM [MARINE SHIFT RANGE DW];
```

Với toàn bộ snapshot được cung cấp, số bản ghi kỳ vọng là **108.680**.

- [Danh sách 15 câu hỏi hiện tại](mdx/README.md)
- [Hướng dẫn chạy MDX](docs/MDX_GUIDE.md)
- [Phạm vi và trạng thái kiểm chứng](docs/MDX_VALIDATED.md)
- [Số tham chiếu từ CSV](docs/MDX_DATA_BASELINES.md)

Lần kiểm chứng MDX lịch sử đối chiếu 36.864 ô trên warehouse trước đó. Q4 và Q6 đã thay đổi phạm vi. Sau khi chuyển cube sang kho từ SSIS mới, cần chạy và đối chiếu lại **toàn bộ 15 câu**, đồng thời cập nhật baseline warehouse. Không cần Deploy/Process chỉ vì sửa câu SELECT; cần Process sau khi thay nguồn dữ liệu.

## Kiểm tra cục bộ

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
```

Các kiểm tra xác nhận fingerprint và các thống kê của CSV, cùng phạm vi đối chiếu Q4/Q6. GitHub Actions chạy các kiểm tra này; không thực thi SSIS hoặc SSAS. Công cụ chạy/đối chiếu MDX nằm trong `scripts/` và cần môi trường SSAS cùng snapshot warehouse phù hợp.

Số bản ghi, số loài phân biệt và số cá thể được báo cáo có ý nghĩa khác nhau. SST/SSS đi kèm vị trí không tự chứng minh điều kiện tại ngày quan sát hoặc quan hệ nhân quả với biến đổi khí hậu. Giữ NULL khi nguồn thiếu thông tin. Chi tiết nguồn: [data/README.md](data/README.md).

Cache Visual Studio, thiết lập cá nhân và đầu ra build trong `bin/`, `obj/` được Git bỏ qua.
