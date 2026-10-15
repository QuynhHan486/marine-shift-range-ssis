# Bộ MDX đã kiểm chứng trên SSAS

Đã chạy **15/15 câu thành công**, đối chiếu **36.864 ô kết quả** với phép tính độc lập từ snapshot đọc từ 6 bảng dbo. Server `localhost`; database `MARINE_SHIFT_RANGE_SSAS`; cube `[MARINE SHIFT RANGE DW]`.

| Câu | Nội dung | Dòng | Cột | Ô đã đối chiếu |
|---:|---|---:|---:|---:|
| 1 | [Chất lượng theo thập kỷ](../mdx/01_Kiem_dinh_chat_luong_du_lieu_theo_thap_ky.mdx) | 5 | 14 | 70 |
| 2 | [Mùa được lấy mẫu nhiều nhất theo giới](../mdx/02_Mua_duoc_lay_mau_nhieu_nhat_cua_moi_gioi.mdx) | 7 | 2 | 14 |
| 3 | [Số loài theo quốc gia và thập kỷ](../mdx/03_So_loai_theo_quoc_gia_va_thap_ky.mdx) | 44 | 2 | 88 |
| 4 | [Top 3 lớp Animalia trong lát cắt](../mdx/04_Top_3_lop_Animalia_theo_vi_do_va_do_sau.mdx) | 8 | 2 | 16 |
| 5 | [Số loài theo độ sâu và vĩ độ](../mdx/05_So_loai_theo_do_sau_va_dai_vi_do.mdx) | 23 | 2 | 46 |
| 6 | [Nhóm môi trường theo thập kỷ](../mdx/06_Nhom_moi_truong_SST_SSS_va_khoang_cach_bo_theo_thap_ky.mdx) | 86 | 3 | 258 |
| 7 | [Top 5 ô lưới mỗi thập kỷ](../mdx/07_Top_5_o_luoi_giau_loai_nhat_moi_thap_ky.mdx) | 25 | 3 | 75 |
| 8 | [Trọng tâm vĩ độ theo lớp Animalia](../mdx/08_Trong_tam_vi_do_theo_lop_Animalia_va_thap_ky.mdx) | 149 | 3 | 447 |
| 9 | [Biên độ vĩ độ theo loài và thập kỷ](../mdx/09_Bien_do_vi_do_cua_tung_loai_theo_thap_ky.mdx) | 6967 | 5 | 34835 |
| 10 | [Biến động số loài phía bắc 15°N](../mdx/10_Bien_dong_so_loai_phia_bac_15N_qua_cac_thap_ky.mdx) | 5 | 5 | 25 |
| 11 | [Loài mới ghi nhận phía bắc 20°N](../mdx/11_Loai_lan_dau_ghi_nhan_phia_bac_20N_theo_nam.mdx) | 47 | 4 | 188 |
| 12 | [Top 15 khoảng SST ghi nhận](../mdx/12_Top_15_loai_co_bien_do_SST_ghi_nhan_rong_nhat.mdx) | 15 | 5 | 75 |
| 13 | [Tỷ trọng bản ghi Animalia tầng sâu](../mdx/13_Ty_le_ban_ghi_Animalia_tang_sau_theo_vi_do_va_thap_ky.mdx) | 25 | 5 | 125 |
| 14 | [Kiểm toán chất lượng theo quốc gia](../mdx/14_Kiem_toan_chat_luong_du_lieu_theo_quoc_gia.mdx) | 10 | 5 | 50 |
| 15 | [Lấy mẫu và số cá thể được báo cáo](../mdx/15_So_ban_ghi_so_loai_va_ty_trong_theo_quoc_gia_va_vi_do.mdx) | 92 | 6 | 552 |

## Cách chạy

1. SSMS 22 → Connect → Analysis Services → localhost, Windows Authentication.
2. Chuột phải database MARINE_SHIFT_RANGE_SSAS → New Query → MDX, mở/dán một file `.mdx`.
3. Reload hoặc đóng tab cũ rồi mở lại file để lấy nội dung mới. Chạy toàn bộ một câu từ WITH đến SELECT/FROM/WHERE bằng F5.
4. Các file có tiền tố 01–15, tên theo nội dung câu hỏi. Mỗi file chứa đúng một truy vấn; xem [danh sách](../mdx/README.md).
5. Ctrl+S lưu query, không tự lưu bảng kết quả. SELECT không yêu cầu Deploy hoặc Process lại.

Mô hình hiện tại đã được triển khai và Process. Câu 9 trả 6.967 dòng và câu 11 tính tập loài tích lũy; lần chạy đầu đã mất khoảng 36 và 22 giây. Thời gian phụ thuộc máy và bộ nhớ đệm.

## Cấu hình đã bổ sung

- Fact named query nối Location qua PK id, giữ đúng một dòng mỗi occurrence: 108.680 dòng. Bổ sung latitude_for_measure, sst_for_measure và individual_count_available; không thêm cột vào bảng SQL.
- Native measures: Latitude Sum/Minimum/Maximum, SST Minimum/Maximum, Individual Count Records. Dùng đúng Sum/Min/Max và NullProcessing=Preserve cho nguồn số nullable.
- Coordinates có key ghép latitude/longitude; SSS Group và Shore Distance Group phục vụ Q6. Caption Country thiếu là Unknown country, SST group thiếu là Unknown SST.
- Sst/Sss attribute keys dùng UnknownMember khi thiếu. Kiểm tra 690 bản ghi thiếu SST trả SST Minimum=NULL, SST Maximum=NULL, không phải số 0.
- Alias Record Count trong WITH MEMBER trỏ tới native Occurrence Count; không thay tên measure vật lý. Browser/Excel vẫn dùng Occurrence Count.

Các thay đổi ở metadata SSAS và MDX. Không sửa CSV, không thay cấu trúc/số liệu bảng dbo, không chạy lại SSIS.

## Định nghĩa kết quả

- Recorded Species đếm distinct species không rỗng trong context; không phải COUNT(taxon_id). Sampled Sites đếm cặp tọa độ, không phải location_id.
- Taxonomy lấy từ Dim_Taxon đã chuẩn hóa. Tài liệu MDX_DATA_BASELINES.md giữ số tham chiếu CSV trước chuẩn hóa; kingdom/class có thể khác vì ETL chọn bộ phân loại đại diện cho scientificName có nhiều phương án. Baseline kiểm chứng mới tính từ warehouse.
- Q2 trả một mùa thắng cho mỗi giới có tên sau chuẩn hóa (7 giới); nhóm thiếu kingdom không phải một giới riêng.
- Q4 chọn Top 3 theo số loài trong lát cắt gộp Animalia, 2000s–2010s, vĩ độ [10,15) hoặc [20,23], độ sâu [0,200). Cùng ba lớp được hiển thị theo từng decade/band.
- Q7/Q12 dùng TOPCOUNT, không trả thêm toàn bộ các trường hợp đồng hạng. Kiểm chứng cho phép chọn member bằng điểm tại ngưỡng.
- Q10 dùng LAG, thập kỷ đầu trả NULL. Q11 tính hợp tập species qua các năm; không cộng annual richness. Có đủ 47 member Year 1980–2026 trên snapshot này.
- Q12 là khoảng SST ghi nhận, không chứng minh khả năng chịu nhiệt sinh lý hoặc thích nghi. Record/site counts của loài vẫn bao gồm bản ghi thiếu SST.
- Q13 mẫu số là bản ghi có độ sâu; có thêm coverage thể hiện dữ liệu thiếu.
- Q14 phản ánh nguồn sạch trong warehouse. ON_LAND là cờ cảnh báo; trạng thái thiếu không phải absent.
- Q15 tỷ trọng country giữ nguyên ngữ cảnh latitude band/decade và gồm Unknown country trong mẫu số. Không có individualCount được báo cáo thì total=NULL; tổng này không phải kích thước quần thể.

## Bằng chứng

- evidence/mdx-suite-validation.json: trạng thái, số dòng/cột, số ô đối chiếu và checksum.
- .backups/mdx-suite-20261015/: bản trước sửa, snapshot dbo và kết quả runtime đầy đủ.
- scripts/validate-mdx.ps1: chạy MDX bằng ADOMD của SSMS 22; hỗ trợ -QueryNumbers 2,3 để chạy một phần.
- scripts/reconcile-mdx.py: đối chiếu kết quả JSON với snapshot warehouse, không sửa dữ liệu.

Build SSAS thành công, 0 lỗi. Các cảnh báo thiết kế đã có trước vẫn có thể xuất hiện. Deploy trực tiếp từ extension VS 4.0.0 còn lỗi client StandardDeveloper64; dùng Deployment Wizard/thư viện SSMS 22 với bản build khi triển khai.
