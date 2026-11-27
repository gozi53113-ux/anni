# NeKo VPN

<p align="center">
  <img src="assets/neko-icon-1024.png" width="160" alt="NeKo VPN">
</p>

<p align="center">
  <b>VPN client Android dựa trên v2rayNG, dùng Xray-core.</b><br>
  VLESS / VMess / Trojan / Shadowsocks · VLESS + WS · TLS / REALITY
</p>

<p align="center">
  <a href="https://github.com/gozi53113-ux/anni/actions/workflows/build.yml">
    <img src="https://github.com/gozi53113-ux/anni/actions/workflows/build.yml/badge.svg" alt="Build">
  </a>
</p>

## Giới thiệu

**NeKo VPN** là bản fork được đổi tên/icon từ [v2rayNG](https://github.com/2dust/v2rayNG)
(GPL-3.0), giữ nguyên engine và toàn bộ tính năng gốc:

- Package: `com.neko.vpn` (cài song song được với v2rayNG).
- Tên APK: `NeKoVPN_<version>_<abi>.apk`.
- Core: **Xray-core** qua `AndroidLibXrayLite v26.11.26` (bản release mới nhất).
- Hỗ trợ giao thức: VLESS (TCP/WS/gRPC/HTTPUpgrade/XHTTP), VMess, Trojan,
  Shadowsocks, SOCKS, HTTP, WireGuard; TLS, REALITY, XTLS.
- Chế độ: VPN (VpnService), proxy-only, root/TUN.
- Nhập cấu hình từ URL, clipboard, QR code, file; subscription; routing;
  kiểm tra ping; chia sẻ hotspot; widget/Quick Settings tile.
- Android 7.0+ (minSdk 24).

> Đây là ứng dụng client. NeKo VPN không cung cấp server, không thu thập
> lưu lượng hay tài khoản của bạn. Chỉ dùng với server/mạng mà bạn được phép.

## Tải APK

1. Vào tab **Actions** của repo: <https://github.com/gozi53113-ux/anni/actions>
2. Chọn workflow **Build NeKo VPN APK** → **Run workflow**.
3. Chờ build xong, mở run → mục **Artifacts** → tải `NeKoVPN-<số>`.
4. Giải nén, chọn APK theo máy:
   - `NeKoVPN_..._arm64-v8a.apk` — điện thoại Android đời mới (phổ biến nhất).
   - `NeKoVPN_..._armeabi-v7a.apk` — máy 32-bit cũ hơn.

Nếu muốn có mục **Releases**, chạy workflow với `release_tag` (ví dụ `v2.4.2-neko`).
Workflow sẽ tạo GitHub Release (prerelease) và đính kèm APK.

## Build tự động trên GitHub Actions

Workflow nằm ở `.github/workflows/build.yml`:

- Tự chạy khi push lên `main` hoặc `master`.
- Có thể chạy tay bằng `workflow_dispatch`.
- Cài Android SDK 37.1, build-tools 37.0.0, NDK 30.0.16248370.
- Build `libhevtun` cho 4 ABI từ submodule `hev-socks5-tunnel`.
- Tải `libv2ray.aar` (Xray) từ release `AndroidLibXrayLite`.
- Build **release APK** cho `arm64-v8a` + `armeabi-v7a` và ký bằng keystore.
- Upload APK vào Artifacts; tạo Release nếu có `release_tag`.

### Ký APK — nên làm ngay

Mặc định, nếu repo chưa có secret ký APK, workflow sẽ **tự tạo keystore tạm**
và lưu trong GitHub Actions cache. APK vẫn cài được, nhưng nếu cache bị xoá,
bản cập nhật sau sẽ có chữ ký khác và bạn phải gỡ app trước khi cài lại.

Muốn cập nhật ổn định, tạo keystore cố định:

```powershell
powershell -ExecutionPolicy Bypass -File tools/create-keystore.ps1
```

Script tạo trong thư mục `keys/` (đã gitignore):

- `neko-release.jks` — file khóa, **phải backup**.
- `keystore-info.txt` — alias + mật khẩu.
- `keystore.b64` — nội dung để dán vào secret.
- `github-secrets.txt` — 4 giá trị cần thêm.

Sau đó vào **Settings → Secrets and variables → Actions → New repository secret**
và thêm:

| Secret | Giá trị |
|---|---|
| `APP_KEYSTORE_BASE64` | toàn bộ nội dung `keys/keystore.b64` (một dòng) |
| `APP_KEYSTORE_ALIAS` | `neko` |
| `APP_KEYSTORE_PASSWORD` | mật khẩu trong `keys/keystore-info.txt` |
| `APP_KEY_PASSWORD` | cùng mật khẩu trên |

Hoặc dùng `gh` CLI (đã đăng nhập):

```bash
gh secret set APP_KEYSTORE_BASE64   --repo gozi53113-ux/anni < keys/keystore.b64
gh secret set APP_KEYSTORE_ALIAS    --repo gozi53113-ux/anni --body "neko"
gh secret set APP_KEYSTORE_PASSWORD --repo gozi53113-ux/anni --body "<mật-khẩu>"
gh secret set APP_KEY_PASSWORD      --repo gozi53113-ux/anni --body "<mật-khẩu>"
```

## Build trên máy (không bắt buộc)

Yêu cầu:

- JDK 21 (JDK 17 có thể không đủ với AGP 9.5.1).
- Android SDK platform `37.1`, build-tools `37.0.0`.
- NDK `30.0.16248370` (chỉ cần khi build `libhevtun`).
- Git, Python 3 + Pillow (chỉ khi muốn tạo lại icon).

```bash
git submodule update --init --recursive

# 1. Build native TUN (cần NDK_HOME)
export NDK_HOME="$ANDROID_HOME/ndk/30.0.16248370"
bash compile-hevtun.sh
cp -r libs V2rayNG/app

# 2. Tải Xray AAR đúng tag
curl -L -o V2rayNG/app/libs/libv2ray.aar \
  https://github.com/2dust/AndroidLibXrayLite/releases/download/v26.11.26/libv2ray.aar

# 3. Build
cd V2rayNG
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew :app:assemblePlaystoreRelease
```

APK nằm ở `V2rayNG/app/build/outputs/apk/playstore/release/`.
Release build không tự ký nếu không truyền `-Pandroid.injected.signing.*`;
có thể ký bằng `apksigner` hoặc dùng đúng lệnh trong workflow.

> Mẹo Windows: nếu đường dẫn chứa dấu tiếng Việt làm `gradlew.bat` lỗi
> "Unable to access jarfile", hãy `subst` một ổ đĩa ASCII cho thư mục dự án
> rồi build từ ổ đó.

## Nâng cấp Xray core

1. Chọn tag mới ở <https://github.com/2dust/AndroidLibXrayLite/releases>
   (tag phải có asset `libv2ray.aar`).
2. Cập nhật submodule:
   ```bash
   cd AndroidLibXrayLite
   git fetch --tags
   git checkout <tag>
   cd ..
   git add AndroidLibXrayLite
   ```
3. Sửa `ANDROID_LIB_XRAY_TAG` trong `.github/workflows/build.yml` cho khớp.
4. Build lại. Nếu API native thay đổi, cập nhật phần gọi trong
   `V2rayNG/app/src/main/java/com/v2ray/ang/core/`.

## Tạo lại icon

Icon được vẽ bằng Python/Pillow, không cần file thiết kế:

```bash
python -m pip install pillow
python tools/generate_icons.py
```

Sửa `tools/generate_icons.py` nếu muốn đổi màu/hình. Icon master:
`assets/neko-icon-1024.png`.

## Cấu trúc

```
.github/workflows/build.yml   # build + ký + upload APK
AndroidLibXrayLite/           # submodule: wrapper Xray-core (LGPL-3.0)
hev-socks5-tunnel/            # submodule: TUN native (MIT)
V2rayNG/                      # Android app (Kotlin/Compose)
  app/src/main/java/com/v2ray/ang/
tools/generate_icons.py       # tạo icon NeKo VPN
tools/create-keystore.ps1     # tạo keystore + secrets
```

## Ghi công & giấy phép

- [v2rayNG](https://github.com/2dust/v2rayNG) — 2dust, **GPL-3.0**.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) — LGPL-3.0.
- [Xray-core](https://github.com/XTLS/Xray-core) — MPL-2.0.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — MIT.
- Các thư viện AndroidX/Compose/MMKV/OkHttp/ZXing… xem trong
  `V2rayNG/app/src/main/assets/open_source_licenses.html`.

Bản fork này phát hành theo **GPL-3.0** (xem `LICENSE`). Mã nguồn đầy đủ
của APK bạn cài nằm tại repo này. Nếu phân phối lại, giữ nguyên thông tin
ghi công và giấy phép.

## Xử lý sự cố GitHub

- **Tab Actions không chạy / bị mờ:** vào **Settings → Actions → General**,
  chọn *Allow all actions and reusable workflows*.
- **Workflow lỗi ở bước tải `libv2ray.aar`:** kiểm tra tag trong
  `ANDROID_LIB_XRAY_TAG` có tồn tại và có asset `libv2ray.aar`.
- **Cài APK báo "App not installed":** gỡ bản cũ trước (khác chữ ký), hoặc
  dùng keystore cố định như mục *Ký APK*.
- **Tài khoản GitHub bị tạm ngưng/flag:** xác minh email, bật 2FA và liên hệ
  [GitHub Support](https://support.github.com). Không tạo tài khoản trùng;
  việc này không liên quan đến mã nguồn và không nên tìm cách lách.

## Miễn trừ

Phần mềm được cung cấp "nguyên trạng", không bảo hành. Bạn tự chịu trách
nhiệm về cấu hình server, quyền truy cập mạng và quy định pháp luật tại
nơi bạn sử dụng.
