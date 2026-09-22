# BrickClone

NFC-triggered app blocker using Core NFC + FamilyControls/ManagedSettings. Tap a registered
tag to lock the apps you picked; tap again to unlock.

## 1. Buy the right tag

Get **NTAG213 or NTAG215** tags (stickers, cards, or keyfobs — any shape). Avoid MIFARE
Classic S50 tags (like the one you screenshotted) — they need sector authentication to write
data and add unnecessary complexity. NTAG21x is natively NDEF-writable, which is what
`NFCManager.swift` writes to.

You don't need to pre-program anything yourself — the app does it. See step 5.

## 2. Apple Developer setup (one-time)

1. Sign in at developer.apple.com (free or $99/year account both work for this).
2. **Certificates, Identifiers & Profiles → Devices** — register your iPhone's UDID
   (find it in Xcode's Devices window, or Settings app on some iOS versions).
3. **Identifiers → App IDs** — register `com.majd.brickclone` (or change the bundle ID in
   `project.yml` to whatever you use), and enable the **Family Controls** capability under it.
   This grants the `.development` entitlement locally — no Apple approval queue needed, since
   you're not distributing to the App Store.
4. **Profiles** — create a **Development** provisioning profile for that App ID, including
   your registered device. Download it.
5. **Certificates** — create/download an iOS Development certificate, export it from Keychain
   Access as a `.p12` (set a password).

## 3. GitHub repo secrets

In your repo → Settings → Secrets and variables → Actions, add:

| Secret | Value |
|---|---|
| `P12_BASE64` | `base64 -i YourCert.p12 \| pbcopy` then paste |
| `P12_PASSWORD` | the password you set exporting the .p12 |
| `MOBILEPROVISION_BASE64` | `base64 -i YourProfile.mobileprovision \| pbcopy` then paste |
| `DEVELOPMENT_TEAM` | your 10-character Apple Team ID |
| `PROVISIONING_PROFILE_SPECIFIER` | the profile's name as shown in the developer portal |

Also edit `ExportOptions.plist` and replace `YOUR_TEAM_ID` / `YOUR_PROFILE_NAME`.

## 4. Build

Push to `main` or run the workflow manually (Actions tab → Build IPA → Run workflow).
Download the `BrickClone-ipa` artifact when it finishes.

## 5. Sideload and program the tag

1. Install the `.ipa` (Sideloadly, AltStore/SideStore, or `ios-deploy` over USB — since it's
   signed with a Development profile tied to your device UDID, any of these work).
   Free Apple ID certs expire after 7 days (just re-run the Action and reinstall);
   paid account certs last a year.
2. Open the app, grant Screen Time (FamilyControls) authorization when prompted.
3. Tap **Choose apps to block** and select your distracting apps.
4. Tap **Program a new tag**, then hold your blank NTAG213/215 to the top of your iPhone
   (near the camera). The app generates a random ID, writes it to the tag as an NDEF text
   record, and remembers it in `UserDefaults` as the trusted tag.
5. Tap **Tap tag to lock/unlock**, then tap the same tag — it reads the ID back, compares it
   to the one it registered, and toggles the shield. Any other tag is ignored.

To register a different/replacement tag later, just tap **Program a new tag** again — it
overwrites which ID is trusted.
