# My Sari-Sari Store
 
An offline-first inventory, point-of-sale and *utang* (customer credit) app for small neighborhood stores, built with Flutter for Android.
 
It works without internet. Signing in with Google is optional and only adds automatic backups to your own Google Drive.
 
## Features
 
- **Inventory**: items and categories, sold by piece or by kilo (0.25 kg, 0.5 kg...), a "+" button to restock, and low-stock alerts you can set globally or per item.
- **Price changes done right**: restock at a new price and the old stock keeps its old price until it sells out, with the option to update everything right away.
- **Point of sale**: a kiosk-style screen with categories on the left, tap-to-add products, quick cash buttons, automatic change, and partial payment with the rest charged to utang.
- **Utang tracking**: customer list, balances, installment payments, manual adjustments, and a full history for each customer.
- **Transaction history**: void a sale with a required reason. The sale stays in the history, stock goes back, and utang is reversed.
- **Dashboard and reports**: sales, profit, expenses (each with a breakdown), utang collected, low-stock alerts, and an end-of-day report for any day.
- **Printable PDFs**: inventory list and low-stock shopping list in A4.
- **Backups**: automatic daily backups to a private, hidden folder in your own Google Drive (the latest 5 days are kept), a backup file you can save on the phone, and restore.
- **Privacy and security**: PIN lock with fingerprint unlock, light and dark mode, and no ads, tracking or analytics.
## Download
 
Get the latest Android APK from the [Releases page](https://github.com/FbkFriend/Store-Tracker/releases/latest).
 
You'll need to allow installing apps from unknown sources. During testing, Google sign-in works only for approved test accounts. Everyone else can use the app as a guest.
 
## Built with
 
- Flutter and Dart
- SQLite (`sqflite`) for local data, `provider` for state
- Google Sign-In and the Google Drive app data folder for backups
- `pdf` and `printing` for reports, `local_auth` for fingerprint unlock
## Run from source
 
```bash
git clone https://github.com/FbkFriend/Store-Tracker.git
cd Store-Tracker
flutter pub get
flutter run
```
 
Guest mode works out of the box. To use Google sign-in in your own build, create your own OAuth clients in Google Cloud (an Android client with your package name and signing key's SHA-1, plus a Web client), enable the Google Drive API, and put the Web client ID in `lib/core/auth/google_auth_service.dart`.
 
## Privacy
 
Your data stays on your phone unless you choose to back it up to your own Google Drive. The developer never receives it. Read the full [Privacy Policy and Terms](https://fbkfriend.github.io/Store-Tracker/).
 
## Feedback
 
Found a bug or have an idea? Please [open an issue](https://github.com/FbkFriend/Store-Tracker/issues).
 
## Author
 
Made by Denmark Angelo C. Dela Cruz as a student project.
 
## License
 
No license has been chosen yet, so all rights are reserved by default.
