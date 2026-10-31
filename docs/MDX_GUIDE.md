# Hướng dẫn chạy 15 câu MDX trên cube hiện tại

Bộ trước khi sửa đã chạy thành công 15/15 câu và đối chiếu 36.864 ô. Theo danh sách câu hỏi cập nhật, **Q4 và Q6 đã thay đổi phạm vi và chưa được chạy lại trên SSAS**; 13 câu còn lại giữ nguyên mã MDX. Xem [danh sách mục tiêu hiện tại](../mdx/README.md) và [phạm vi kiểm chứng](MDX_VALIDATED.md). Máy chỉnh sửa hiện tại chưa có catalog SSAS để thực thi bộ câu mới.

## Mở và chạy

SSMS 22 → Connect → Analysis Services → localhost → database MARINE_SHIFT_RANGE_SSAS → New Query → MDX. Mở/dán một file .mdx, chạy toàn bộ một câu bằng F5. Reload/mở lại file nếu tab hiện tại còn nội dung cũ.

```mdx
SELECT {[Measures].[Occurrence Count]} ON COLUMNS
FROM [MARINE SHIFT RANGE DW];
```

Câu kiểm tra trả **108680**. Database name và cube name khác nhau. Thư mục `mdx/` gồm 15 file riêng, đặt tên tiếng Việt không dấu theo nội dung câu truy vấn, có tiền tố 01–15. Mở từng file và chạy toàn bộ câu trong file; xem [danh sách file](../mdx/README.md).

## Tên và key thực tế

| Đối tượng | Tên/key |
|---|---|
| Cube | [MARINE SHIFT RANGE DW] |
| Dimensions | [Dim Date], [Dim Taxon], [Dim Location], [Dim Depth Band], [Dim Quality] |
| Native record measure | [Measures].[Occurrence Count] |
| Alias trong query | [Measures].[Record Count] qua WITH MEMBER |
| Decade keys | 1980s, 1990s, 2000s, 2010s, 2020s |
| Year keys | số 1980–2026, đủ 47 năm |
| Season keys | Winter, Spring, Summer, Autumn |
| Latitude Band keys | 0-5°N, 5-10°N, 10-15°N, 15-20°N, 20-23°N |
| Depth Id | 0 Unknown; 1 [0,50); 2 [50,200); 3 [200,1000); 4 >=1000 m |
| Depth label hierarchy | [Dim Depth Band].[Depth Band] |
| Coordinates | key ghép decimalLatitude/decimalLongitude |
| Country thiếu | key rỗng, caption Unknown country; giữ trong Q3/Q14/Q15 |
| Species thiếu | key rỗng, loại khỏi Known Species |

## Measure và nhóm môi trường

| Native measure bổ sung | Nguồn theo occurrence | Tổng hợp |
|---|---|---|
| Latitude Sum | latitude_for_measure | Sum |
| Latitude Minimum/Maximum | latitude_for_measure | Min/Max |
| SST Minimum/Maximum | sst_for_measure, giữ NULL | Min/Max |
| Individual Count Records | 1 khi có individualCount, ngược lại 0 | Sum |

Individual Count giữ NULL ở nguồn. Q15 phân biệt tổng thật bằng 0 và không có số cá thể được báo cáo. WITH MEMBER/SET chỉ có hiệu lực trong query; Browser/Excel không tự có các calculated members này.

SST Group giữ key chuỗi: rỗng/Unknown SST, <25°C, 25-27°C, 27-29°C, >=29°C. SSS Group keys: -1 Unknown, 0 <30, 1 [30,32), 2 >=32. Shore Distance Group keys: -1 Unknown, -2 inland, 0 [0,10000 m), 1 [10000,50000 m), 2 >=50000 m. Q6 so sánh tất cả các nhóm khoảng cách, gồm Inland và Unknown, đồng thời giữ SST/SSS thiếu. Không áp dụng thêm bộ lọc cờ chất lượng; Inland được giữ riêng để nhận biết các ghi nhận cần kiểm tra tọa độ. Đây là ngưỡng quy ước của đồ án.

Các nguồn bổ sung là named query trong DSV, không thay bảng SQL. Fact vẫn một dòng một occurrence. Dùng NullProcessing=Preserve cho measure nullable và UnknownMember cho key Sst/Sss thiếu.

## Kết quả lịch sử và trạng thái hiện tại

| Câu | Nội dung | Dòng | Cột | Ô đã đối chiếu |
|---:|---|---:|---:|---:|
| 1 | [Chất lượng theo thập kỷ](../mdx/01_Kiem_dinh_chat_luong_du_lieu_theo_thap_ky.mdx) | 5 | 14 | 70 |
| 2 | [Mùa được lấy mẫu nhiều nhất theo giới](../mdx/02_Mua_duoc_lay_mau_nhieu_nhat_cua_moi_gioi.mdx) | 7 | 2 | 14 |
| 3 | [Số loài theo quốc gia và thập kỷ](../mdx/03_So_loai_theo_quoc_gia_va_thap_ky.mdx) | 44 | 2 | 88 |
| 4 | [Top 3 lớp Animalia gộp 2000–2019, <200 m](../mdx/04_Top_3_lop_Animalia_2000s_2010s_duoi_200m.mdx) | Chưa chạy lại | 2 | — |
| 5 | [Số loài theo độ sâu và vĩ độ](../mdx/05_So_loai_theo_do_sau_va_dai_vi_do.mdx) | 23 | 2 | 46 |
| 6 | [Nhóm môi trường theo thập kỷ](../mdx/06_Nhom_moi_truong_SST_SSS_va_khoang_cach_bo_theo_thap_ky.mdx) | Chưa chạy lại | 3 | — |
| 7 | [Top 5 ô lưới mỗi thập kỷ](../mdx/07_Top_5_o_luoi_giau_loai_nhat_moi_thap_ky.mdx) | 25 | 3 | 75 |
| 8 | [Trọng tâm vĩ độ theo lớp Animalia](../mdx/08_Trong_tam_vi_do_theo_lop_Animalia_va_thap_ky.mdx) | 149 | 3 | 447 |
| 9 | [Biên độ vĩ độ theo loài và thập kỷ](../mdx/09_Bien_do_vi_do_cua_tung_loai_theo_thap_ky.mdx) | 6967 | 5 | 34835 |
| 10 | [Biến động số loài phía bắc 15°N](../mdx/10_Bien_dong_so_loai_phia_bac_15N_qua_cac_thap_ky.mdx) | 5 | 5 | 25 |
| 11 | [Loài mới ghi nhận phía bắc 20°N](../mdx/11_Loai_lan_dau_ghi_nhan_phia_bac_20N_theo_nam.mdx) | 47 | 4 | 188 |
| 12 | [Top 15 khoảng SST ghi nhận](../mdx/12_Top_15_loai_co_bien_do_SST_ghi_nhan_rong_nhat.mdx) | 15 | 5 | 75 |
| 13 | [Tỷ trọng bản ghi Animalia tầng sâu](../mdx/13_Ty_le_ban_ghi_Animalia_tang_sau_theo_vi_do_va_thap_ky.mdx) | 25 | 5 | 125 |
| 14 | [Kiểm toán chất lượng theo quốc gia](../mdx/14_Kiem_toan_chat_luong_du_lieu_theo_quoc_gia.mdx) | 10 | 5 | 50 |
| 15 | [Lấy mẫu và số cá thể được báo cáo](../mdx/15_So_ban_ghi_so_loai_va_ty_trong_theo_quoc_gia_va_vi_do.mdx) | 92 | 6 | 552 |

Q4 trả ba dòng lớp, xếp hạng theo số loài phân biệt trong toàn bộ 2000–2019 ở độ sâu [0,200) m; không giới hạn vĩ độ. Q6 giữ toàn bộ nhóm khoảng cách. Số dòng/cột của các câu khác bên trên là kết quả của lần chạy lịch sử, không phải lần chạy mới.

Chi tiết định nghĩa: [MDX_VALIDATED.md](MDX_VALIDATED.md). Số CSV trong [MDX_DATA_BASELINES.md](MDX_DATA_BASELINES.md) vẫn là đối chiếu nguồn, không thay baseline warehouse đã chuẩn hóa.

## Quay video

Nêu câu hỏi → mở file → giới thiệu bộ lọc và measure → F5 → giải thích kết quả và mức thiếu dữ liệu. Ctrl+S lưu query; lưu/chụp kết quả riêng. Câu 9/11 có thể mất vài chục giây ở lần đầu. SELECT không yêu cầu Deploy/Process lại. Sau thay cấu trúc hoặc dữ liệu nguồn, cần triển khai/Process và kiểm tra lại.

## Tài liệu Microsoft

- [Named queries](https://learn.microsoft.com/en-us/analysis-services/multidimensional-models/define-named-queries-in-a-data-source-view-analysis-services)
- [Aggregate functions](https://learn.microsoft.com/en-us/analysis-services/multidimensional-models/use-aggregate-functions)
- [NONEMPTY](https://learn.microsoft.com/en-us/sql/mdx/nonempty-mdx)
- [LAG](https://learn.microsoft.com/en-us/sql/mdx/lag-mdx)

## Chạy lại sau khi cập nhật phạm vi

Khi cube đã được Deploy và Process trên máy thực hiện:

```powershell
.\scripts\validate-mdx.ps1 -ServerName "TENMAY\INSTANCE" -DatabaseName "MARINE_SHIFT_RANGE_SSAS" -QueryNumbers 4,6 -ClientDirectory "THU_MUC_CHUA_ADOMDCLIENT"
```

Bỏ `-QueryNumbers 4,6` để chạy đủ 15 câu. Chọn ClientDirectory có Microsoft.AnalysisServices.AdomdClient.dll của SSMS trên máy. Cập nhật snapshot warehouse và chạy scripts/reconcile-mdx.py với bộ kết quả đủ 15 câu để thay bằng chứng cũ. Không cần Deploy/Process lại chỉ vì sửa nội dung SELECT.
