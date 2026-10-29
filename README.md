# Cash Book

Log cash expenses on your iPhone and keep them in your own Google Sheet.

- **`web/`**: the Home Screen web app. It's free, never expires and needs no Apple ID. GitHub Pages publishes it automatically.
- **`backend/`**: the Google Apps Script that stores everything in your Sheet.
- **`CashBook/`**: a native SwiftUI version. It's only useful with an Apple Developer account; build it from the Actions tab.

## Set up the web app

1. **Update the Apps Script.** In your Sheet, go to Extensions → Apps Script and paste `backend/Code.gs`. Put your own `SECRET` and `CURRENCY` back in. Then go to Deploy → Manage deployments → ✏️ → Version: **New version** → Deploy. Your URL doesn't change.
2. **Add it to your Home Screen.** On the iPhone, open the web app link in **Safari**, tap **Share → Add to Home Screen**, then tap **Add**.
3. **Connect it.** Open **Cash Book from the Home Screen** (not from Safari), go to **Settings**, and paste your web app URL (ending in `/exec`) and your secret key.

Your URL and secret are stored only on your phone. They are never in this repo.

To preview the app with sample data, add `?demo` to the link.
