# Orodha ya kutoa MADINI sokoni (V1.9)

## A. Kompyuta/CI (kwa mpangilio)
1. Weka source kwenye GitHub; workflow `MADINI Quality Gates` iendeshe. Ikishindwa, nipe log kamili (nitarekebisha).
2. `flutter pub get` -> weka `pubspec.lock` kwenye repo (artifact `pubspec-lock`).
3. `flutter analyze` na `flutter test` zipite zote.
4. `scripts/check_16kb.sh` ipite (16 KB alignment). Ikishindwa, usipakie kwenye Play.
5. Tengeneza keystore ya release (nje ya Git), weka secrets nne za GitHub, endesha `signed-release` (workflow_dispatch) kupata AAB.
6. Hakikisha AAB inalenga API 36 (Play Console itakataa vinginevyo).

## B. Simu halisi (angalau 2: mpya + ya RAM ndogo)
1. Migration kutoka toleo la zamani lenye data; hesabu rekodi/vyeti kabla na baada.
2. Backup kamili (na vyeti ~30 MB) na nyepesi; hakiki; futa app; sakinisha; rejesha; linganisha.
3. Kasi: PIN, backup, restore bila kuganda/OOM kwenye simu ya RAM ndogo.
4. PIN: makosa 5 -> kufungiwa; app switcher haionyeshi yaliyomo; screenshot imezuiwa.
5. Hariri rekodi nje ya app (au simulate) -> ukurasa wa undani uonyeshe "muhuri haulingani".
6. Rekodi matokeo halisi yenye recovery > 100% -> onyo + alama "inahitaji ukaguzi".
7. Shiriki PDF/cheti/backup; faili za muda zifutwe.
8. Database iliyoharibika (simulate) -> skrini ya "imeharibika", hakuna kufuta kimya.

9. Doré: hifadhi tathmini ya fire assay (rejea), XRF na macho; thibitisha alama ya "imethibitishwa"/"KUKADIRIA TU", purity iliyotumika (tahadhari) na bid tofauti kati ya njia.
10. Rekodi matokeo halisi, kisha yarekebishe: sababu inahitajika, toleo la zamani linaonekana kwenye "Historia ya matoleo", na muhuri bado ni halali.
11. Fungua tena app baada ya siku 2+ na vyeti vingi: hakuna cheti kilichofutwa na kifuta cha yatima (idadi ya vyeti ni ile ile).

## C. Wataalamu na biashara
1. Tume ya Madini: viwango vya royalty/inspection na nani anabeba.
2. Metallurgist/mhasibu: formula, recovery, payability, vizingiti (CV 20%, max/min 2, outlier, mshtuko wa scenarios); `docs/VALIDATION_PROTOCOL_SW.md`.
3. Ukaguzi huru wa cryptography/key lifecycle.
4. Mwanasheria: sera ya faragha na masharti (rasimu ziko `docs/`); Play Console: data safety, content rating, mawasiliano ya msaada.
5. Pilot dhidi ya assay certificates halisi kabla ya kutangaza usahihi wowote.
6. Doré: mnunuzi/mhasibu mzoefu athibitishe viwango vya tahadhari ya purity (fire assay 0, XRF 2, macho 5 ni mapendekezo ya awali tu) na vizingiti vya maonyo (purity -3 pointi, fine gold 5%, uzito 2%).


## V1.9 hardening checks
- [ ] Restore ya backup yenye duplicate assessment/sample/certificate IDs inakataliwa kabla ya DB write.
- [ ] Restore inakataa sample isiyo na assessment, negative/non-finite grade, invalid price na certificate yenye SHA-256 isiyolingana.
- [ ] Backup zaidi ya 120 MB inakataliwa; certificate attachments zaidi ya 30 MB zinaelezwa.
- [ ] Recompute ya Ore/Doré inakataa scenario/field iliyokosekana.
- [ ] Actual outcome history inahifadhi namba za matoleo bila kurudia au kurudi nyuma.
- [ ] Fire assay/metallurgical evidence inaelezwa kama user-declared, si independently verified.
- [ ] Doré UI inasema wazi kuwa formula ni Au-only na haina Ag credits/settlement penalties.
