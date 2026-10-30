# MyPocket

MyPocket is a personal finance app I built with Flutter. You write down the money that comes in and the money that goes out, and the app helps you see where it is going. It also has an AI chat for money questions, but that part is optional and the app works fine without it.

## What it does

You can record income (salary, bonus, business, other) and expenses (food, drinks, groceries, transport, bills, entertainment, shopping, health, other). Every entry has an amount, a date and an optional note.

The home screen shows your balance and how much came in and went out this month. There is a calendar where days with transactions get a small dot, and tapping a day lists what happened on that day.

When you log an expense, the app can save your current location. The map tab then shows pins for every place you spent money, and tapping a pin shows the transaction.

The app also watches your spending and sends a reminder when something looks off. It checks two things.

1. An expense that is out of routine. This means an amount more than twice the average of earlier expenses in the same category (it needs at least three earlier ones), or a first expense in a new category that is Rp 200,000 or more.
2. An expense that could get heavy if it keeps repeating. This means a category that shows up four or more times in 30 days and adds up to more than 15 percent of your income for those 30 days (or Rp 500,000 if you have not recorded any income). The reminder also shows what that would add up to over a year.

These checks run on the phone itself, so the reminders work offline.

## AI chat

The Assistant tab has a switch. When it is off, the tab shows an offline summary with your three biggest spending categories and any findings from the checks above. Nothing is sent anywhere.

When it is on, you can chat with a Groq model about your finances. The app sends your recent messages together with a short summary of the last 30 days, so the answers can refer to your own numbers.

The Groq API key is not in the app. The app talks to a small Flask server that holds the key and forwards the request to Groq. I did it this way because a key inside a phone app can be pulled out by anyone who opens the APK.

The server address can be changed from inside the app (the server icon next to the switch), so a new address does not need a rebuild. There is a test button that calls the health endpoint of the server.

## Built with

Flutter for the app, with shared_preferences for local storage, table_calendar, flutter_map with OpenStreetMap tiles (no map API key needed), geolocator, flutter_local_notifications and intl. The backend is Python with Flask and Flask-Limiter. The AI model is served by Groq.

## Folder layout

```
mypocket/
  pubspec.yaml
  lib/
    main.dart        screens and theme
    services.dart    data model, storage, checks, Groq call, location, notifications
  backend/
    app.py           Flask server with /chat and /health
    requirements.txt
    .env.example
```

The android and ios folders are not included. You create them with flutter create (step 2 below).

## Running it

You need the Flutter SDK, VS Code with the Flutter and Dart extensions, an Android emulator or a phone with USB debugging, Python 3.10 or newer, and a Groq API key. I used Flutter 3.24.4 on Windows.

1. Open the mypocket folder in VS Code.

2. Create the platform folders and get the packages.

```
flutter create . --project-name mypocket --org com.mypocket
flutter pub get
```

If it asks about overwriting files, do not overwrite lib or pubspec.yaml.

3. Android setup. In android/app/src/main/AndroidManifest.xml, add these permissions above the application tag and set the label to MyPocket.

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

The notification package needs desugaring. In android/app/build.gradle, turn it on inside compileOptions and add the dependency at the bottom.

```gradle
compileOptions {
    coreLibraryDesugaringEnabled true
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

If your file is build.gradle.kts, use isCoreLibraryDesugaringEnabled = true and coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4").

On older Flutter versions the location plugin can fail to build with an error about flutter.compileSdkVersion. Pinning the plugin fixed it for me. Add this at the bottom of pubspec.yaml, outside the dependencies block.

```yaml
dependency_overrides:
  geolocator_android: 4.6.1
```

4. Start the backend in a second terminal.

```
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

Open .env and fill in GROQ_API_KEY and APP_TOKEN. For the token, any long random string works. You can make one with this.

```
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Then run it and open http://localhost:5000/health. You should see {"status":"ok"}.

```
python app.py
```

5. Run the app. Put the same token in .vscode/launch.json (the toolArgs line), pick a device in VS Code and press F5. From the terminal it is this.

```
flutter run --dart-define=APP_TOKEN=yourtoken
```

On an Android emulator, the default server address http://10.0.2.2:5000 points to your computer. Since that address is plain http, add android:usesCleartextTraffic="true" to the application tag while testing.

## Using it on other phones

A phone outside your network cannot reach localhost, so I use a Cloudflare quick tunnel.

```
cloudflared tunnel --url http://localhost:5000
```

It prints an https address. Paste it into the server field in the app, press the test button, save, and turn the AI switch on. The address changes every time the tunnel restarts, and the backend and the tunnel both have to be running for the chat to work. Everything else in the app works without them.

To build an APK, raise the version in pubspec.yaml each time (1.0.0+2, then +3 and so on) so it installs over the old one.

```
flutter build apk --release --dart-define=APP_TOKEN=yourtoken
```

The file ends up in build/app/outputs/flutter-apk/app-release.apk.

## Things to know

Data is stored only on the phone, so it is not synced between devices, and uninstalling the app deletes it.

The APP_TOKEN is baked into the APK, so it only keeps casual traffic out. The server also limits requests per IP. This setup is meant for me and a few people I hand the APK to, not for a public release. For that I would add real user login on the backend.

Never commit backend/.env, the APK or your real token. The .gitignore in this repo already covers them. If a key ever ends up in a commit, revoke it in the Groq console and make a new one.

## Not done yet

Budgets per category, charts, exporting data, searching for place names on the map, and scheduled daily reminders.
