# Cash Book

A personal iPhone app for logging cash expenses. It syncs with your Google Sheet.

- Log an expense with a big amount pad, category buttons and an optional note. Date, time and location are added automatically.
- See a monthly overview with a category donut chart, daily spending bars and a comparison with last month.
- Browse your history by day, then search, filter, edit or swipe to delete.
- Works offline. Changes wait on the phone and sync when you're back online.
- Say "Hey Siri, add expense in Cash Book", or put it on the Action Button.

## 1. Update the Google Apps Script

1. Open your Sheet and go to Extensions → Apps Script.
2. Replace the code in `Code.gs` with `backend/Code.gs`. **Set `SECRET` and `CURRENCY` back to your own values.**
3. Go to Deploy → Manage deployments → ✏️ → Version: **New version** → Deploy. Your URL stays the same.

Your existing Shortcut keeps working.

## 2. Get the app file (.ipa)

Every push to `main` builds the app on GitHub's Mac servers.

1. Open the repo on github.com and go to **Actions** → the latest **Build iPhone app** run.
2. Under **Artifacts**, download `CashBook-ipa`.
3. Unzip it to get `CashBook.ipa`.

## 3. Install it from Windows with Sideloadly

1. Install **iTunes** (the version from apple.com, not the Microsoft Store one) and **Sideloadly** (sideloadly.io).
2. Plug in your iPhone and tap **Trust** on the phone.
3. Drag `CashBook.ipa` into Sideloadly, enter your Apple ID, and click **Start**.
4. On the iPhone, go to Settings → General → VPN & Device Management, tap your Apple ID, then tap **Trust**.
5. On iOS 16 and later, turn on Settings → Privacy & Security → **Developer Mode**, then restart the phone.

With a free Apple ID, the app has to be re-signed every 7 days. Plug in the phone and click Start again in Sideloadly; your data is kept. With a paid Apple Developer account, it lasts a year.

## 4. Connect the app

In the app, open **Settings**. Paste your web app URL (ending in `/exec`) and your secret key, then tap **Sync now**.
