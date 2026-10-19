# Release checklist (Google Play)

Status: not released. Items marked "you" need the owner; the rest are done
or done by CI.

## Decide before the first upload (cannot change later)

- [ ] **App name** (you). "Little Muslim" is a placeholder.
- [ ] **Application ID** (you). Currently `com.jibrilmohamod.islamic_kids_app`.
      Google Play never lets an app change it after the first upload.

## Signing (you, once)

Google Play App Signing keeps the real signing key; we only hold an upload
key. Create it on your own computer, never in chat:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

Then in GitHub, repo Settings, Secrets and variables, Actions, add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the clipboard from the command above |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password you chose |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password you chose |

Keep `upload-keystore.jks` and the passwords in a password manager. From the
next push, CI also builds a signed `.aab` for Play.

## Store listing and policy forms

- [ ] Privacy policy at a public URL (you choose where). Draft: `docs/privacy-policy.md`.
- [ ] Target audience: ages 9 to 12 (and 6 to 8 if wanted). Families Policy applies.
- [ ] Data safety form: "No data collected", "No data shared".
- [ ] Ads: "No ads".
- [ ] Content rating questionnaire.
- [ ] Short and full description, screenshots, feature graphic.
- [ ] Credits in the listing: QuranEnc.com, HadeethEnc.com, AlQuran.cloud and the reciter.

## Before sending to review

- [ ] Tested on a low-end Android phone (Android 7 or newer).
- [ ] Somali strings checked by a native speaker, or Somali stays switched off.
- [ ] Internal testing track with a few families first.

## Done

- [x] No AD_ID, no location, no analytics SDKs, no ads
- [x] INTERNET permission only (content updates and audio)
- [x] Parent area behind an adult question
- [x] Font licences shown in the app (SIL OFL)
- [x] Source and version shown for every translation (QuranEnc terms)
