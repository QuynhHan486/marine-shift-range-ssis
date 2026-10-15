# Câu MDX 1 đã kiểm chứng trên cube thực tế

Mở `mdx/01_Kiem_dinh_chat_luong_du_lieu_theo_thap_ky.mdx` trong SSMS 22, kết nối Analysis Services `localhost`, database `MARINE_SHIFT_RANGE_SSAS`, rồi nhấn F5. Chạy toàn bộ câu WITH ... SELECT ... FROM. Mỗi file trong `mdx/` chứa một câu truy vấn.

Cube: `[MARINE SHIFT RANGE DW]`. Query dùng alias `[Measures].[Record Count]` cho measure vật lý `[Measures].[Occurrence Count]`; alias chỉ có hiệu lực trong câu hiện tại.

Đã chạy thành công: 5 dòng thập kỷ, 14 chỉ tiêu; đối chiếu đủ 70 ô với truy vấn SQL độc lập trên các bảng dbo, sai số tuyệt đối tối đa dưới 1e-9. Tổng 108.680 bản ghi.

| Decade | Records | Recorded species | Sampled sites | SST known | SSS known |
|---|---:|---:|---:|---:|---:|
| 1980s | 2224 | 963 | 316 | 98.16% | 98.16% |
| 1990s | 44551 | 1597 | 426 | 99.82% | 99.82% |
| 2000s | 7937 | 1928 | 530 | 98.32% | 98.32% |
| 2010s | 50444 | 1608 | 870 | 99.50% | 99.50% |
| 2020s | 3524 | 871 | 975 | 94.69% | 94.69% |

Số loài đếm các member species không rỗng; không đếm taxon_id. Sampled Sites đếm cặp latitude/longitude phân biệt, không đếm location_id. Taxonomy Complete dùng bộ phân loại đã chuẩn hóa trong Dim_Taxon. Kết quả kiểm toán phản ánh kho dữ liệu hiện tại, không phải dữ liệu OBIS thô ban đầu.

Các tập Quality được suy ra từ các thuộc tính sẵn có của Id qua member properties. Flag Consistency so sánh bit flag_on_land với token ON_LAND trong flags; các token được sử dụng là token chuẩn đã có trong snapshot ETL. Không thêm flag_marine_unsure.

Để không nhầm NULL thành 0, Dim Location đã đặt UnknownMember=Visible và KeyColumns.NullProcessing=UnknownMember cho Sst/Sss, đồng bộ file dimension nguồn và Process Full trên máy chủ. Số 0 thực nếu có trong nguồn vẫn là một giá trị đã biết. Không thay đổi bảng SQL hoặc CSV.

Bản gốc câu 1 và file tổng hợp được lưu trong thư mục sao lưu local. Trong bước sửa Q01, chỉ đoạn Q01 được cập nhật. Sau đó Q02-Q15 đã được sửa và kiểm chứng; xem docs/MDX_VALIDATED.md cho trạng thái mới nhất.

Bằng chứng đầy đủ: `evidence/mdx-q01-validation.json`.
