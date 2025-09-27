## 🔧 Steps to Enable Persistent Wi-Fi Debugging for Flutter

### 1. First-time setup (one time only)

1. **Enable Developer Options** on your phone:

   - Go to **Settings → About phone → tap “Build number” 7 times**.
   - In **Developer options**, enable:

     - **USB debugging**
     - **Wireless debugging** (if your device supports it; if not, we’ll use the TCP method).

2. **Connect USB cable once** (only needed the first time).
   Run this to check device:

```bash
adb devices
```

✅ Output should show your device as `device`.

---

### 2. Switch to Wi-Fi debugging

Find your phone’s Wi-Fi IP address:

```bash
adb shell ip route
```

➡ Look for `src <IP>`. Example: `10.11.74.25`

Now switch adb to TCP mode:

```bash
adb tcpip 5555
```

Connect to the phone’s IP:

```bash
adb connect <PHONE_IP>:5555
```

Example:

```bash
adb connect 10.11.74.25:5555
```

Check devices:

```bash
adb devices
```

✅ You should see both USB and Wi-Fi entries. Now unplug USB — Wi-Fi stays connected.

---

### 3. Run Flutter over Wi-Fi

```bash
flutter run -d <PHONE_IP>:5555
```

Example:

```bash
flutter run -d 10.11.74.25:5555
```

Hot reload now works wirelessly 🚀

---

### 4. Make it **persistent** (auto-connect script)

Windows batch file (save as `adb_wifi_connect.bat`):

```bat
@echo off
REM Replace with your phone's IP
set PHONE_IP=10.11.74.25

echo Restarting adb in TCP mode...
adb tcpip 5555

echo Connecting to phone %PHONE_IP%:5555 ...
adb connect %PHONE_IP%:5555

echo Listing connected devices:
adb devices

pause
```

📌 Place this in your Flutter project root or Desktop.
Next time you reboot, just double-click this script → your phone auto-connects.

---

### 5. (Optional) Add adb to PATH permanently

So you don’t need the full path every time:

1. Open **System Properties → Environment Variables**.
2. Add this to PATH:

```
C:\Users\Daniel\AppData\Local\Android\Sdk\platform-tools
```

3. Restart terminal → now `adb` works everywhere.

---

✅ From now on, every time you connect your laptop to your phone’s hotspot, just run:

```bash
adb_wifi_connect.bat
```

and then:

```bash
flutter run -d <PHONE_IP>:5555
```
