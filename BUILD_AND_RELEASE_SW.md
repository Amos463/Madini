# Jinsi ya kuendesha MADINI V1.8

## Codespaces
Fungua repository ndani ya Codespaces, kisha terminal:

```bash
chmod +x scripts/preflight.sh
./scripts/preflight.sh
```

Script itafanya `flutter pub get`, analysis na tests (Web build haifanywi: app ni ya simu). Ikiwa Gradle CLI ipo, itazalisha Android wrapper ya Gradle 8.12 na kujenga debug APK.

## GitHub Actions
Push source kwenye GitHub. Fungua tab ya **Actions** na angalia workflow **MADINI Quality Gates**. APK ya debug itapatikana kama artifact tu baada ya workflow kufanikiwa.

## Release signing
Usitumie debug APK kwa uzinduzi. Tengeneza upload/release keystore kwenye kompyuta salama. Weka `key.properties` na keystore nje ya Git, kisha tumia `android/key.properties.example` kama mwongozo. Hifadhi nakala salama ya keystore na passwords. Kupoteza signing key kunaweza kuzuia kusasisha app iliyochapishwa.

```bash
flutter build appbundle --release
```

Release build inahitaji `android/key.properties` na keystore halisi. Usitume keystore au password kwenye chat, GitHub repository au ZIP ya source.
