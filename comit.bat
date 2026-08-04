@echo off
echo ====================================================
echo Bat dau qua trinh commit len GitHub...
echo ====================================================

:: Bước 1: Thêm tất cả file thay đổi vào staging area
echo [1/4] Dang them file vao staging area...
git add .

:: Bước 2: Tạo commit với thông điệp thời gian
:: Lấy ngày giờ hiện tại để tự động tạo tên commit (Ví dụ: Update 2026-08-04 22-15)
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set date_str=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set time_str=%%a-%%b
set commit_msg=Update %date_str% %time_str%

echo [2/4] Dang tao commit voi message: %commit_msg%
git commit -m "%commit_msg%"

:: Bước 3: Push code lên GitHub
echo [3/4] Dang day code len GitHub...
:: Lưu ý: main là tên nhánh chính. Nếu nhánh của bạn là master, hãy đổi thành master
git push origin main

:: Kết thúc
echo ====================================================
echo Hoan thanh!
echo ====================================================
pause