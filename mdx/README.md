# 15 câu truy vấn MDX

Tên file dùng tiếng Việt không dấu và số thứ tự 01–15. Mỗi file chứa một truy vấn.

Trong SSMS, kết nối **Analysis Services → localhost → MARINE_SHIFT_RANGE_SSAS**, mở file và nhấn **F5**. Tên cube là `[MARINE SHIFT RANGE DW]`.

| Câu | Nội dung / file |
|---:|---|
| 1 | [Kiểm định chất lượng dữ liệu theo thập kỷ](01_Kiem_dinh_chat_luong_du_lieu_theo_thap_ky.mdx) |
| 2 | [Mùa được lấy mẫu nhiều nhất của mỗi giới](02_Mua_duoc_lay_mau_nhieu_nhat_cua_moi_gioi.mdx) |
| 3 | [Số loài theo quốc gia và thập kỷ](03_So_loai_theo_quoc_gia_va_thap_ky.mdx) |
| 4 | [Top 3 lớp Animalia theo vĩ độ và độ sâu](04_Top_3_lop_Animalia_theo_vi_do_va_do_sau.mdx) |
| 5 | [Số loài theo độ sâu và dải vĩ độ](05_So_loai_theo_do_sau_va_dai_vi_do.mdx) |
| 6 | [Nhóm môi trường SST, SSS và khoảng cách bờ theo thập kỷ](06_Nhom_moi_truong_SST_SSS_va_khoang_cach_bo_theo_thap_ky.mdx) |
| 7 | [Top 5 ô lưới giàu loài nhất mỗi thập kỷ](07_Top_5_o_luoi_giau_loai_nhat_moi_thap_ky.mdx) |
| 8 | [Trọng tâm vĩ độ theo lớp Animalia và thập kỷ](08_Trong_tam_vi_do_theo_lop_Animalia_va_thap_ky.mdx) |
| 9 | [Biên độ vĩ độ của từng loài theo thập kỷ](09_Bien_do_vi_do_cua_tung_loai_theo_thap_ky.mdx) |
| 10 | [Biến động số loài phía bắc 15°N qua các thập kỷ](10_Bien_dong_so_loai_phia_bac_15N_qua_cac_thap_ky.mdx) |
| 11 | [Loài lần đầu ghi nhận phía bắc 20°N theo năm](11_Loai_lan_dau_ghi_nhan_phia_bac_20N_theo_nam.mdx) |
| 12 | [Top 15 loài có biên độ SST ghi nhận rộng nhất](12_Top_15_loai_co_bien_do_SST_ghi_nhan_rong_nhat.mdx) |
| 13 | [Tỷ lệ bản ghi Animalia tầng sâu theo vĩ độ và thập kỷ](13_Ty_le_ban_ghi_Animalia_tang_sau_theo_vi_do_va_thap_ky.mdx) |
| 14 | [Kiểm toán chất lượng dữ liệu theo quốc gia](14_Kiem_toan_chat_luong_du_lieu_theo_quoc_gia.mdx) |
| 15 | [Số bản ghi, số loài và tỷ trọng theo quốc gia và vĩ độ](15_So_ban_ghi_so_loai_va_ty_trong_theo_quoc_gia_va_vi_do.mdx) |

Câu 6 hiện thực hiện so sánh nhóm môi trường; câu 15 có thêm số cá thể được báo cáo. Chi tiết bộ lọc, giới hạn diễn giải và bằng chứng kiểm tra: [hướng dẫn](../docs/MDX_GUIDE.md), [kiểm chứng](../docs/MDX_VALIDATED.md).
