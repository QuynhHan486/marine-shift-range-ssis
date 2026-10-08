# Nguồn dữ liệu

`occurrence_clean.csv` là file người thực hiện đồ án cung cấp, giữ nguyên byte UTF-8 BOM: 108.680 dòng, 24 cột. Dữ liệu đã được lọc và làm sạch từ `Occurrence.csv` theo mục 1.1.3 của báo cáo hiện tại. Kho SSIS bắt đầu từ file sạch này; không thực hiện lại lọc `marine` vì cột đó không còn trong file sạch.

Thông tin nguồn trong báo cáo: OBIS Marine Species Occurrence Dataset. Bản giao hiện tại không có DOI hoặc mã download OBIS đủ để tái lập tải dữ liệu. Không suy diễn giấy phép cho dữ liệu hoặc thay đổi nguồn gốc bản ghi. Khi trích dẫn học thuật, bổ sung DOI/download citation và giấy phép từng dataset từ lần tải OBIS gốc.

File gốc 435 MB và hai báo cáo tham khảo không nằm trong repository. `manifest.json` ghi SHA-256, schema và thống kê của file sạch thực tế. Bản `clean_data.py` nằm ngoài repo có nội dung xử lý hồ sơ nhân sự, không phải mã làm sạch OBIS, vì vậy không được sử dụng trong ETL này.

Phạm vi kiểm tra SSIS: 0-23°N, 99-121°E; dữ liệu thực tế nằm trong 103,3960299-120,83°E. Mọi tọa độ phản ánh nguồn dữ liệu, không dùng để suy luận chủ quyền hoặc tự gán quốc gia cho 65.538 bản ghi thiếu `country`.
