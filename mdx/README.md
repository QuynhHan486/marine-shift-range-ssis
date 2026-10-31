# 15 câu truy vấn MDX

Các câu hỏi và phạm vi dưới đây được cập nhật theo danh sách đã sửa. Tên cube là `[MARINE SHIFT RANGE DW]`; database là `MARINE_SHIFT_RANGE_SSAS`. Mỗi file chứa một câu truy vấn.

| Câu | Mục tiêu và phạm vi | File |
|---:|---|---|
| 1 | Đánh giá độ đầy đủ, tính nhất quán và các cờ chất lượng theo từng thập kỷ để xác định khả năng so sánh và hạn chế khi phân tích. | [01](01_Kiem_dinh_chat_luong_du_lieu_theo_thap_ky.mdx) |
| 2 | Tìm mùa theo lịch có tỷ trọng bản ghi lớn nhất của mỗi giới sinh vật; không diễn giải là mùa khí hậu riêng của khu vực. | [02](02_Mua_duoc_lay_mau_nhieu_nhat_cua_moi_gioi.mdx) |
| 3 | Thống kê số loài được ghi nhận theo quốc gia và thập kỷ, gồm quốc gia không xác định. | [03](03_So_loai_theo_quoc_gia_va_thap_ky.mdx) |
| 4 | Liệt kê 3 lớp Animalia có số loài được ghi nhận nhiều nhất trong toàn bộ giai đoạn 2000–2019, ở độ sâu dưới 200 m, trên toàn vùng nghiên cứu. | [04](04_Top_3_lop_Animalia_2000s_2010s_duoi_200m.mdx) |
| 5 | Đếm số loài được ghi nhận theo dải độ sâu × dải vĩ độ, giữ nhóm độ sâu không xác định. | [05](05_So_loai_theo_do_sau_va_dai_vi_do.mdx) |
| 6 | So sánh số loài và số bản ghi theo nhóm SST, SSS, khoảng cách đến bờ và thập kỷ, giữ các nhóm Unknown và Inland để mô tả đầy đủ các bối cảnh ghi nhận. | [06](06_Nhom_moi_truong_SST_SSS_va_khoang_cach_bo_theo_thap_ky.mdx) |
| 7 | Xác định 5 ô lưới 1° × 1° có số loài được ghi nhận nhiều nhất mỗi thập kỷ, kèm số bản ghi và số cặp tọa độ được lấy mẫu. | [07](07_Top_5_o_luoi_giau_loai_nhat_moi_thap_ky.mdx) |
| 8 | Tính trung bình vĩ độ của các bản ghi theo lớp Animalia và thập kỷ. | [08](08_Trong_tam_vi_do_theo_lop_Animalia_va_thap_ky.mdx) |
| 9 | Tính biên độ vĩ độ được ghi nhận của từng loài theo thập kỷ để mô tả sự mở rộng hoặc thu hẹp của biên độ ghi nhận bắc–nam. | [09](09_Bien_do_vi_do_cua_tung_loai_theo_thap_ky.mdx) |
| 10 | Tính biến động số loài được ghi nhận ở vùng từ 15°N trở lên giữa các thập kỷ bằng LAG. | [10](10_Bien_dong_so_loai_phia_bac_15N_qua_cac_thap_ky.mdx) |
| 11 | Đếm số loài lần đầu được ghi nhận trong bộ dữ liệu ở vùng từ 20°N trở lên theo từng năm, mô tả quá trình bổ sung ghi nhận tại vùng này. | [11](11_Loai_lan_dau_ghi_nhan_phia_bac_20N_theo_nam.mdx) |
| 12 | Tìm 15 loài có biên độ SST tại các vị trí ghi nhận rộng nhất để mô tả nhóm loài được ghi nhận trong khoảng điều kiện nhiệt độ rộng; không kết luận khả năng chịu nhiệt hay thích ứng cao nhất. | [12](12_Top_15_loai_co_bien_do_SST_ghi_nhan_rong_nhat.mdx) |
| 13 | Tính tỷ lệ bản ghi Animalia ở độ sâu ≥200 m trong số bản ghi Animalia biết độ sâu, theo dải vĩ độ và thập kỷ. | [13](13_Ty_le_ban_ghi_Animalia_tang_sau_theo_vi_do_va_thap_ky.mdx) |
| 14 | Thống kê số bản ghi, tỷ lệ được gắn cờ trên đất liền và tỷ lệ trạng thái present theo quốc gia, gồm quốc gia không xác định, để đánh giá đầu vào đã làm sạch. | [14](14_Kiem_toan_chat_luong_du_lieu_theo_quoc_gia.mdx) |
| 15 | Thống kê số bản ghi, số loài và tổng số cá thể được báo cáo theo quốc gia, dải vĩ độ, thập kỷ; kèm tỷ trọng bản ghi của quốc gia và tỷ lệ bản ghi có individualCount để mô tả thiên lệch bao phủ dữ liệu. | [15](15_So_ban_ghi_so_loai_va_ty_trong_theo_quoc_gia_va_vi_do.mdx) |

## Những điểm cần hiểu khi trình bày

- Q4 xếp hạng một lần trên hai thập kỷ gộp chung, trả ba dòng lớp. Loài xuất hiện ở cả hai thập kỷ được đếm một lần trong mỗi lớp; đã bỏ điều kiện hai dải vĩ độ cũ.
- Q6 giữ các nhóm khoảng cách Inland và Unknown; không tự loại bản ghi theo cờ chất lượng. Inland là nhóm cần xem xét chất lượng tọa độ, không phải môi trường biển để suy luận sinh thái.
- Q7 đếm vị trí bằng cặp tọa độ, không dùng location_id. TOPCOUNT chọn đúng N nếu đủ thành viên; các trường hợp đồng hạng còn lại không được hiển thị.
- Q8 là trung bình có trọng số theo số bản ghi; Q9 là biên độ ghi nhận. Cả hai chịu ảnh hưởng của độ bao phủ và cường độ lấy mẫu.
- Q11 vẫn hiển thị số loài tích lũy, số bản ghi và số vị trí làm thông tin bổ trợ. Lần đầu được ghi nhận trong tập dữ liệu không đồng nghĩa với lần đầu loài xuất hiện trong thực tế.
- Q12 dùng SST_max − SST_min tại các vị trí ghi nhận. Dữ liệu này không đủ để xếp hạng khả năng thích ứng hoặc chịu nhiệt sinh lý.
- Q14: mẫu số của cả hai tỷ lệ là tổng số bản ghi quốc gia, kể cả trạng thái thiếu. Cờ trên đất liền không tự xác nhận bản ghi sai.
- Q15: tỷ trọng quốc gia có mẫu số là tổng bản ghi của tất cả quốc gia, gồm Unknown, trong cùng dải vĩ độ và thập kỷ. Tổng individualCount là số cá thể được báo cáo, không phải kích thước quần thể.
- Q10/Q13 và các so sánh theo thập kỷ là mô tả dữ liệu; thập kỷ 2020s chưa đầy đủ. Không tự kết luận di cư hay tác động nhân quả của biến đổi khí hậu.

## Chạy và kiểm chứng

Trong SSMS, kết nối Analysis Services đến instance của bạn, chọn database, mở một file và nhấn F5. Lần kiểm chứng lịch sử đã chạy đủ 15 câu; Q4 và Q6 đã thay đổi phạm vi nên cần chạy và đối chiếu lại. Máy chỉnh sửa hiện tại có dịch vụ SSAS nhưng chưa có catalog để thực thi bộ truy vấn.

[Hướng dẫn chạy](../docs/MDX_GUIDE.md) · [Phạm vi kiểm chứng](../docs/MDX_VALIDATED.md)
