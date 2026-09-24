# kesh_kart

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web release builds

Build either browser portal through the release script, not plain `flutter build web`.
It versions `main.dart.js`, clears obsolete Flutter caches once for a new
release, and reloads the browser once when needed. Users do not need to hard refresh.

```powershell
.\scripts\build_web_release.ps1 -Portal customer
.\scripts\build_web_release.ps1 -Portal barber
```

## KeshKart Barber Android / Play internal testing

The Android application identity is `com.keshkart.barber` and its visible label is
**KeshKart Barber**. Native Android checkout uses Razorpay Standard Checkout;
the app receives only a server-created order and the public Razorpay key, then
sends the success callback back to the existing server verification endpoint.
Subscription activation remains webhook-authoritative on the backend.

Before building a Play bundle, use the existing Google Play upload keystore for
this package. Copy `android/key.properties.example` to `android/key.properties`
and fill it in locally, or provide the equivalent `KEY_*` environment values.
Both the keystore and properties file are ignored by Git. Do not add either to
source control and do not share their passwords.

Before building the first Android APK with this new package, register
`com.keshkart.barber` as a separate Android app in the existing Firebase
project and replace `android/app/google-services.json` with the downloaded
configuration. Do not edit the existing JSON by hand: its Firebase app ID and
OAuth/notification configuration belong to the registered package. Update the
Truecaller Android application registration with the new package and signing
certificate as well.

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=your-existing-upload-alias
storeFile=upload-keystore.jks
```

With signing configured, choose a Play version code greater than the most
recent uploaded build, then create the signed bundle:

```powershell
flutter build appbundle --release --build-name 1.0.0 --build-number <next-play-build-number>
```

Or run the guarded release script, which checks that signing points to a real
local keystore and prints the final AAB checksum:

```powershell
.\scripts\build_android_internal_test.ps1 -BuildNumber <next-play-build-number>
```

Upload `build/app/outputs/bundle/release/app-release.aab` to the Play Console's
Internal testing track. Complete this real-device smoke test before promoting
the release:

1. Barber login, shop profile, seats, services, queue, QR and receipt scan.
2. Location rejection outside Khambhat and normal access inside the supported
   service area.
3. A new subscription checkout. This is live Razorpay: use an
   owner-authorized payment only, and confirm backend/webhook verification
   before expecting Pro access.
4. Coupon/zero-price subscription, terms consent, insights, and reconnect
   behavior.
