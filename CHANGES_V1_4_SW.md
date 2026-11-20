# MADINI V1.4 — Marekebisho ya ukaguzi (9)

> Yameandikwa kwenye source; **hayajacompile wala kupimwa kwa kifaa**. Fuata `RELEASE_CHECKLIST_SW.md`.

1. **parseNum salama kwa fedha** (`lib/core/format.dart`): `500,000` haisomwi tena kama 500. Koma moja yenye tarakimu 3 hasa (`1,250`) inakataliwa kwa ujumbe wazi; `1,500,000`, `1,234.5`, `3,5` zinakubaliwa. Tests zimeongezwa.
2. **Outlier** (`assay_analysis.dart`): kigezo cha 2 SD hakiwezi kuwaka kwa n<=5 (z juu = (n-1)/√n). Sasa: ulinganisho na median (>50%) kwa n>=3, pamoja na robust z (MAD>3.5) kwa n>=5.
3. **Kizuizi cha utofauti** kinaanza n>=2 (CV>=20% AU max/min>=2), si n>=3.
4. **Scenarios halisi**: conservative/optimistic zinabadilisha grade + bei + recovery kwa mshtuko unaohaririwa (chaguo-msingi ±10% bei, ±5 pts recovery; 0 = grade pekee). Bei/recovery zilizotumika zinaonekana kwenye matokeo, detail na PDF. Onyo kama zote zinafanana.
5. **Makato ya kisheria**: hakuna 6%/1% zilizojazwa mapema; ni lazima kuingiza (0 kama hakuna). Maelezo wazi nani anabeba. Kitufe cha BoT ni "mfano — thibitisha".
6. **PIN/usalama**: fail-closed (hitilafu ya hifadhi haizimi PIN; hash ikikosekana huku alama ipo = imefungwa), saa ikirudishwa nyuma haifupishi kufungiwa, `FLAG_SECURE` (hakuna screenshot/preview ya app switcher), faili za muda za kushiriki zinafutwa (kila kuanza app, kufunga, na kabla ya kushiriki kipya).
7. **Utendaji**: `cryptography_flutter` imewashwa (`FlutterCryptography.enable()`) kwa PBKDF2/AES ya asili; backup/restore/hakiki zina kiashiria cha maendeleo.
8. **Hatari ya kupoteza data**: kikumbusho cha backup (siku 14) kwenye Home; nenosiri la backup lina sheria za nguvu + kurudia mara mbili + onyo la kupotea; backup inahakikiwa papo hapo; kitufe cha "Hakiki backup bila kurejesha".
9. **Mapungufu madogo**: migration ya DB v<5 (`values`→`values_json`, FTS); faili za `-wal/-shm/-journal` za legacy zinahamishwa pamoja (zilikuwa zinaweza kuharibu DB mpya); audit events ziko kwenye backup (bila nakala wakati wa restore).

## Yanayobaki (hayawezi kutatuliwa kwa source pekee)
- `pubspec.lock` haijatengenezwa (hakuna Flutter hapa): endesha `flutter pub get` kisha uiweke kwenye repo.
- Kusonga saa mbele kunaweza bado kufupisha kufungiwa kwa PIN (kikomo cha offline).
- PIN haisimbi database (ufunguo uko Keystore); haya ni kinga ya skrini.
- Viwango vya royalty/inspection, vizingiti vya CV/outlier/scenario, na muundo wa makato vinahitaji kuidhinishwa na Tume ya Madini/mtaalamu.
