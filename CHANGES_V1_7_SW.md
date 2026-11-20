# MADINI V1.7 — Production Hardening

> **Hakuna compile, analyze, test wala build iliyoendeshwa** (mazingira ya kazi hayana Flutter/Dart/Android SDK). Muundo ulikaguliwa kwa script (imports, mabano, majina) na hesabu za mfano kwa Python. **CI ndiyo hatua ya kwanza.**

## Vizuizi vya duka vilivyopatikana na kurekebishwa (vimethibitishwa kwa vyanzo rasmi, Nov 2026)
1. **Target API 36:** Google Play inahitaji apps mpya/masasisho kulenga Android 16 (API 36) tangu 31 Aug 2026. V1.6 ilitumia AGP 8.5.0/`flutter.targetSdkVersion` (haitoshi). Sasa: `compileSdk=36`, `targetSdk=36`, AGP 8.9.1, Gradle 8.12, Kotlin 2.1.0, Java 17, Flutter >= 3.35.
2. **16 KB page size:** maktaba ya zamani ya SQLCipher (community `android-database-sqlcipher` 4.5.x) haikuwa 16 KB. `sqflite_sqlcipher` 3.3.0+ inatumia SQLCipher 4.10 na 3.4.0 inaunga SDK 36; V1.7 inatumia `^3.4.0`. CI sasa inaendesha `scripts/check_16kb.sh` (ELF LOAD alignment + zipalign -P 16) kwenye release APK; usipitishe ikishindwa.
3. **CI ya release:** job ya `signed-release` (kwa mkono) inajenga AAB iliyosainiwa kutoka secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`).

## Uadilifu wa rekodi
4. **Muhuri wa uadilifu (SHA-256)** kwa kila tathmini mpya (`integrity_seal.dart`): mabadiliko yoyote ya values/result/formula yanagunduliwa; ukurasa wa undani na PDF vinaonyesha hali. Matokeo halisi yametengwa kwa makusudi. (Ni ushahidi wa mabadiliko, si ulinzi dhidi ya mtu mwenye ufikiaji kamili wa kifaa.)
5. **Formula versioning:** kurudia hesabu sasa kunalinganisha toleo; tofauti kwa rekodi za toleo la zamani zinaitwa "formula changed" (si udanganyifu). Muhtasari wa matoleo: `docs/FORMULA_VERSIONS_SW.md`. Ukaguzi wa `recheckStored` umepanuliwa (dryWeight, dryTonnes, gradeUsed, priceUsed, recoveryUsed, net, chemicals, purchase).
6. **Matokeo halisi:** yenye maonyo (recovery > 100%, purity < 50%, tofauti > pointi 10) sasa yanahitaji uthibitisho wa wazi na yanawekwa alama "inahitaji ukaguzi" (inaonekana kwenye historia na PDF). Rejea na tarehe vilikuwepo.
7. **Makato ya kisheria 0%:** yanahitaji kisanduku cha kuthibitisha kuwa ni kwa makusudi (au uthibitisho wa viwango). Nakala ya tathmini haibebi tena "nimethibitisha viwango" (viwango vinaweza kuwa vimebadilika).

## Database na backup
8. **PRAGMA quick_check** kila database inapofunguliwa; ikishindwa: skrini maalum ya "Database imeharibika" (hakuna kufuta kimya) inayoelekeza kwenye backup.
9. **Faili za vyeti yatima** (restore/hifadhi iliyokatizwa) zinafutwa baada ya saa 24 tu, na zile zisizo kwenye database.
10. **Backup:** ukubwa wa faili linalosimbwa unakaguliwa kabla ya kulisoma; chaguo jipya la **backup nyepesi** (bila faili za vyeti) kwa simu zenye RAM ndogo; ujumbe wazi wa vyeti vilivyoachwa.
11. Ripoti ya PDF: tests za namba kubwa, maandishi marefu (kurasa nyingi) na herufi zisizo za Latin-1.
12. Kushiriki ripoti kunashughulikia makosa (hakuna crash kimya).

## Yasiyofanyika kwa makusudi (uaminifu)
- **Backup ya streaming/chunked:** haikutekelezwa; muundo mpya wa faili bila compiler/kifaa ungekuwa hatari kuliko tatizo lenyewe. Hatua za kupunguza hatari ni #10 hapo juu. Jaribu backup kamili kwenye simu ya RAM ndogo; ikigoma, tumia nyepesi au nielekeze nijenge streaming.
- **Injini za matoleo ya zamani hazihifadhiwi:** badala yake namba zilizohifadhiwa + muhuri ni rekodi rasmi (#4, #5). Hesabu ya matoleo 1.3-1.6 ni ileile isipokuwa scenarios (angalia docs).
- **applicationId:** tayari ni `tz.madini.madini` (si jina la jumla); thibitisha tu kuwa ndilo unalotaka kabla ya kupakia kwa mara ya kwanza (haliwezi kubadilishwa baadaye).
- **pubspec.lock:** hutengenezwa na `flutter pub get` (CI inaipakia kama artifact: iweke kwenye repo).

## Bado yanahitaji watu/vifaa vyako
Compile/test (CI), majaribio ya simu halisi (migration, backup/restore, PIN, FLAG_SECURE, kasi), keystore ya release, Play Console (data safety, sera ya faragha/masharti kupitiwa na mwanasheria), uthibitisho wa metallurgist/mhasibu wa formula na viwango vya makato, ukaguzi huru wa cryptography, pilot dhidi ya assay halisi.
