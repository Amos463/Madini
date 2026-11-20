# Matoleo ya formula

| Toleo | Mabadiliko ya hesabu |
|---|---|
| v1.3 | Decimal; scenarios hubadilisha grade pekee; makato % ya mapato |
| v1.4 | Scenarios: grade + bei + recovery (mshtuko unaohaririwa); hesabu ya msingi haikubadilika |
| v1.6 | Injini moja: kemikali, purity (mara moja), faida/net, ushahidi wa recovery; hesabu ya mnyororo wa dhahabu ileile |
| v1.7 | Hakuna mabadiliko ya formula; muhuri wa uadilifu, ukaguzi mpana wa kurudia hesabu |
| v1.8 | Hesabu ya ore HAIJABADILIKA. Imeongezwa hesabu ya doré (angalia chini); `formulaVersion` = `MADINI v1.8-recovery-dore-decimal` |
| v1.9 | Hakuna mabadiliko ya hesabu. Backup/restore validation, strict recompute checks na actual-outcome version sequencing zimeimarishwa; formulaVersion imeachwa ileile ili historia ya V1.8 isionekane imebadilishwa formula. |

Mlolongo: dry mass = wet x (1 - moisture); contained = dry tonnes x grade; recovered = contained x recovery; payable = recovered x payability; revenue = payable x bei; makato = revenue x %; net = revenue - makato - gharama; bid = net - faida lengwa.

Sera: formula ikibadilika kwa namna inayobadilisha namba, `formulaVersion` ibadilishwe na rekodi za zamani ziendelee kuonyesha namba zao zilizohifadhiwa (zimehifadhiwa na muhuri); injini ya sasa inarudia hesabu kwa kulinganisha tu na kuitaja kama "formula changed".

Mlolongo wa doré (v1.8): net mass = gross x (1 - punguzo la uzito); purity iliyotumika = purity iliyopimwa - tahadhari/100; fine gold = net mass x purity iliyotumika (purity mara moja tu); payable = fine x payability; revenue = payable x bei; makato = revenue x %; gharama = refining/assay + usafirishaji + nyinginezo; net = revenue - makato - gharama; bid = net - faida lengwa; faida = net - bei ya ununuzi. Scenarios: purity +/- pointi na bei +/- %.


## Mipaka ya formula ya doré
Formula ya doré kwenye V1.8/V1.9 inathamini Au pekee: uzito halisi × gold purity. Haijumuishi Ag/silver credits, impurity penalties, treatment charges zinazobadilika kwa refinery, minimum deductions au settlement schedules. Usiiite refinery settlement engine. Rejea ya fire assay na recovery evidence ni taarifa zilizotajwa na mtumiaji; app haihakiki uhalisi wake.
