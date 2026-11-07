# Done Did It

A habit and chore tracker for iPhone. Set things up as daily, weekly (on set days or any days), monthly (on a set date or any day), or repeating every few days or weeks. Check them off with one tap, and see your progress as a month calendar of symbols, a day-by-day week rundown, streaks and a heatmap.

## Put it on your iPhone (free, with your Mac)

You need a Mac with **Xcode** (free from the Mac App Store) and your iPhone's USB cable.

1. **Download the code.** On this repo's GitHub page, tap the green **Code** button, then **Download ZIP**. Double-click the ZIP to unzip it.
2. **Open the project.** Double-click `DoneDidIt.xcodeproj`. Xcode opens.
3. **Sign in with your Apple ID.** In Xcode go to **Xcode → Settings → Accounts**, press **+**, choose **Apple ID** and sign in. A normal Apple ID works; you don't need a paid developer account.
4. **Pick your team.** In the left sidebar click the blue **DoneDidIt** project icon, then the **DoneDidIt** target, then **Signing & Capabilities**. Under **Team**, choose your name (Personal Team). If Xcode says the bundle identifier is taken, change `com.jessvds88.donedidit` to something unique, like `com.yourname.donedidit`.
5. **Plug in your iPhone** and unlock it. If it asks "Trust This Computer?", tap **Trust**.
6. **Turn on Developer Mode** on the iPhone: **Settings → Privacy & Security → Developer Mode**, switch it on, and let the phone restart.
7. **Choose your iPhone** in the device menu at the top of the Xcode window, then press the **▶ Run** button.
8. The first time, the iPhone will block the app. Go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**. Then open Done Did It from your home screen.

With a free Apple ID, the app stops opening after **7 days**. When that happens, plug in your phone and press ▶ Run again; your habits stay saved. A paid Apple Developer account ($99/year) makes it last a year, or lets you use TestFlight.

## Your data

Habits are saved on the phone, in the app's own storage. They aren't shared with the web version.

## For developers

SwiftUI, iOS 17+, no dependencies. Source is in `DoneDidIt/`. The project uses Xcode 16 synchronized folders, so new `.swift` files in that folder are picked up automatically. GitHub Actions builds every pull request for the simulator.
