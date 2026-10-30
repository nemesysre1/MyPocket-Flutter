# MyPocket

Aplikasi keuangan pribadi (Flutter) dengan backend Flask untuk asisten AI Groq.

```
mypocket/
├── pubspec.yaml
├── lib/                 main.dart, services.dart
├── backend/             app.py, requirements.txt, .env.example
└── .vscode/launch.json
```

## Prasyarat
- Flutter SDK (cek dengan `flutter doctor`)
- VS Code + ekstensi **Flutter** dan **Dart**
- Android Studio / Android SDK (untuk emulator) atau HP Android dengan USB debugging
- Python 3.10+
- Key API Groq (console.groq.com)

## A. Menyiapkan proyek Flutter
1. Extract zip, lalu di VS Code pilih **File > Open Folder** dan buka folder `mypocket`.
2. Buka terminal (**Terminal > New Terminal**), jalankan:
   ```
   flutter create . --project-name mypocket --org com.mypocket
   flutter pub get
   ```
   Perintah pertama membuat folder `android/` dan `ios/`. Jika ditanya soal menimpa file, jangan timpa `lib/` dan `pubspec.yaml`. Setelah itu cek `lib/main.dart` masih berisi MyPocket.
3. Buka `android/app/src/main/AndroidManifest.xml`:
   - Tepat di atas tag `<application`, tambahkan:
     ```xml
     <uses-permission android:name="android.permission.INTERNET"/>
     <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
     <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
     <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
     ```
   - Ubah `android:label="mypocket"` menjadi `android:label="MyPocket"`.
   - Hanya jika server memakai `http://` (satu Wi-Fi, tanpa tunnel), tambahkan `android:usesCleartextTraffic="true"` di tag `<application`.
4. Aktifkan desugaring (diperlukan paket notifikasi) di `android/app/build.gradle.kts`:
   ```kotlin
   android {
       compileOptions { isCoreLibraryDesugaringEnabled = true }
   }
   dependencies {
       coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
   }
   ```
   Jika file kamu `build.gradle` (Groovy), pakai `coreLibraryDesugaringEnabled true` dan `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'`. Blok `android { ... }` dan `dependencies { ... }` sudah ada di file, cukup tambahkan barisnya ke dalam blok yang sama.

## B. Menjalankan backend Flask
Buka terminal kedua (ikon `+` di panel terminal):
```
cd backend
python -m venv venv
venv\Scripts\activate          (Mac/Linux: source venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env         (Mac/Linux: cp .env.example .env)
```
Jika PowerShell menolak activate: `Set-ExecutionPolicy -Scope Process Bypass`.

Isi `backend/.env`: `GROQ_API_KEY` dengan key Groq-mu dan `APP_TOKEN` dengan string acak panjang. Lalu:
```
python app.py
```
Tes di browser: `http://localhost:5000/health` harus menampilkan `{"status":"ok"}`.

## C. Tunnel agar bisa diakses dari luar (opsional)
Terminal ketiga:
```
cloudflared tunnel --url http://localhost:5000
```
Salin alamat `https://....trycloudflare.com` yang muncul. Alamat berubah setiap tunnel dijalankan ulang, tetapi bisa diganti dari dalam aplikasi (langkah E). Untuk emulator di komputer yang sama, tunnel tidak diperlukan.

## D. Menjalankan aplikasi
1. Buka `.vscode/launch.json`, ganti `ganti_dengan_token_di_env` dengan `APP_TOKEN` yang sama persis dengan di `backend/.env`.
2. Pilih perangkat di pojok kanan bawah VS Code (emulator atau HP).
3. Tekan **F5**. Atau lewat terminal:
   ```
   flutter run --dart-define=APP_TOKEN=tokenmu
   ```
Di emulator Android, alamat server bawaan `http://10.0.2.2:5000` langsung mengarah ke backend di komputermu.

## E. Mengatur alamat server di aplikasi
Tab **Asisten** > ikon server di kanan atas > tempel alamat (tanpa `/chat`) > **Tes koneksi** > **Simpan**. Lalu nyalakan switch **AI aktif**. Jika switch mati, aplikasi berjalan offline dan tidak mengirim data apa pun.

## F. Membuat APK untuk dibagikan
1. Naikkan versi di `pubspec.yaml` setiap build (`version: 1.0.0+2`, lalu `+3`, dst.) agar bisa dipasang di atas versi lama.
2. Build:
   ```
   flutter build apk --release --dart-define=APP_TOKEN=tokenmu
   ```
3. Hasil: `build/app/outputs/flutter-apk/app-release.apk`. Build selalu dari komputer yang sama agar update tanpa uninstall tetap berhasil.

## Masalah umum
- **Kode 401:** `APP_TOKEN` di build berbeda dengan di `.env`. Token tertanam saat build, jadi perlu run atau build ulang.
- **Kode 502:** key Groq salah atau kuota habis. Cek terminal backend.
- **Tidak dapat terhubung:** backend atau tunnel mati, atau alamat salah. Uji `alamat/health` di browser HP.
- **Error saat build tentang desugaring:** langkah A4 belum dilakukan.

## Keamanan sebelum push ke GitHub
Jangan commit `backend/.env`, APK, atau token asli. Sebelum push, jalankan `git ls-files | findstr /i ".env"` (Mac/Linux: `grep`) dan `git grep gsk_`. Jika key pernah ter-commit, cabut dan buat key baru di dashboard Groq.
