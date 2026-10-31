# Database từ laptop

`marineRangeShift_demo.zip` chứa nguyên hai file được cung cấp trong `New SSIS.zip`:

- `marineRangeShift_demo.mdf`
- `marineRangeShift_demo_log.ldf`

Hai file được giữ nguyên nội dung và nén để đưa lên GitHub. Kích thước và SHA-256 của từng file, cùng bundle ZIP, nằm trong `manifest.json`. Không có thao tác Attach hoặc thay đổi database trong quá trình nhập source.

Để sử dụng, giải nén cả hai file vào cùng một thư mục mà dịch vụ SQL Server có quyền truy cập. Trong SSMS, chọn **Databases → Attach → Add**, chọn file `.mdf` và kiểm tra đường dẫn file log trước khi hoàn tất. Dùng phiên bản SQL Server tương thích với database của laptop (SQL Server 2025).

Database được cung cấp là kết quả đã nạp. Nếu muốn trình diễn nạp lại, dùng script `sql/demo/04_clear_loaded_data.sql` đúng database rồi chạy package; xem hướng dẫn SSIS trước khi đặt lại dữ liệu. Nếu dựng database trống, chạy các script tạo database/bảng và khởi tạo độ sâu trong `sql/demo/` theo README gốc.
