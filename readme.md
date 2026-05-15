# Check License

## QuickStart

Mở PowerShell và chạy lệnh sau để tải công cụ, cài tạm vào `%TEMP%` và mở giao diện kiểm tra bản quyền:

```powershell
irm https://raw.githubusercontent.com/mson-ssh/check-banquyen/main/install.ps1 | iex
```

## Giới thiệu dự án

Check License là công cụ PowerShell giúp kiểm tra trạng thái bản quyền Windows và Microsoft Office trên Windows 10 21H2 trở lên và Windows 11.

Công cụ tập trung vào kiểm tra tuân thủ bản quyền theo chế độ chỉ đọc: không kích hoạt sản phẩm, không thay đổi key, không tải dữ liệu lên internet và không quét lịch sử Windows Defender.

Ứng dụng có giao diện WPF gọn nhẹ, hỗ trợ tiếng Việt và tiếng Anh, phù hợp để kỹ thuật viên kiểm tra nhanh máy người dùng trước khi xử lý bản quyền hoặc dấu hiệu kích hoạt bất thường.

## Tính năng

- Kiểm tra trạng thái bản quyền Windows.
- Kiểm tra trạng thái bản quyền Office 2016, 2019, 2021, 2024, Microsoft 365 Apps và LTSC.
- Kiểm tra cấu hình KMS của Windows và Office.
- Phát hiện các dấu hiệu thường gặp của công cụ kích hoạt không chính thống.
- Hiển thị tổng quan bằng giao diện WPF với các ô Windows, Office, KMS và Dấu hiệu.
- Hỗ trợ tiếng Việt và tiếng Anh ngay trên giao diện.
- Tạo report JSON/CSV trong `%ProgramData%\CheckLicense\reports`.
- Có trợ lý lập kế hoạch gỡ dấu hiệu kích hoạt bất thường theo hướng an toàn, có backup/quarantine khi áp dụng.

## Mã nguồn sử dụng

Công cụ chỉ đọc dữ liệu từ các nguồn hệ thống và nguồn bản quyền chính thức có sẵn trên Windows/Office:

- `SoftwareLicensingProduct` qua CIM/WMI để kiểm tra bản quyền Windows.
- Registry của Software Protection Platform để đọc cấu hình KMS Windows.
- `OSPP.VBS /dstatus` trong thư mục Office chính thức để kiểm tra Office volume/perpetual.
- `vnextdiag.ps1 -action list` khi có sẵn để kiểm tra Microsoft 365 Apps/vNext licensing.
- Registry Office Click-to-Run và LicensingNext để nhận diện Office retail.
- Registry Office Software Protection Platform để đọc cấu hình KMS Office.
- Windows Services, service path, Scheduled Tasks, Run keys, IFEO debugger hooks và một số đường dẫn file/folder đã định nghĩa trong `src/config/rules.json` để nhận diện dấu hiệu bất thường.

Các nhóm dấu hiệu được nhận diện gồm KMS emulator/client, MAS/HWID/Ohook/TSforge/KMS38, `SppExtComObjHook.dll` và các tên/đường dẫn phổ biến của công cụ kích hoạt không chính thống.

## Tham số dòng lệnh

- `-Gui`: mở giao diện WPF.
- `-Menu`: mở menu tương tác trên console.
- `-Json`: in kết quả JSON ra console.
- `-NoReport`: không ghi file JSON/CSV.
- `-VerboseLog`: bật log chi tiết.
- `-ApplyCleanup`: tạo kế hoạch gỡ và áp dụng khi dùng kèm `-Force`.
- `-Force`: xác nhận áp dụng cleanup trong chế độ dòng lệnh.

## Lưu ý an toàn

- Công cụ không dùng `wmic.exe`.
- Công cụ không kích hoạt Windows hoặc Office.
- Công cụ không đọc full product key; chỉ hiển thị partial key nếu hệ thống cung cấp.
- Điểm rủi ro chỉ là tín hiệu kiểm tra tuân thủ, không phải kết luận pháp lý.
- Nên chạy một lần bằng user thường để kiểm tra và chỉ dùng Administrator khi cần áp dụng cleanup.
