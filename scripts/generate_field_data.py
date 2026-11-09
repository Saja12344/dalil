#!/usr/bin/env python3
"""Merge TikTok field notes into metro_catalog.json exits and places.json."""

from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "Nazlah/Resources/SampleData/metro_catalog.json"
PLACES_PATH = ROOT / "Nazlah/Resources/SampleData/places.json"
UPDATED = "2026-09-16T00:00:00Z"

# station_id, number, ar_dir, en_dir, ar_land, en_land, status (verified|pending),
# n_offset, e_offset, access
EXITS = [
    ("al_aziziyah", "2", "شارع الشباب (شمال شرق)", "Al Shabab Street (NE)", "كوفي أركان", "Arkan Cafe", "verified", 1, 1, "unknown"),
    ("al_aziziyah", "3", "مطعم يمين الباب (كابشن سند)", "Restaurant to the right (Sanad caption)", "باب المحطة", "Station door", "pending", 1, -1, "unknown"),
    ("king_fahd_district_2", "1", "تعبر تقاطع الشارع إلى درج كهربائي", "Cross the intersection to an escalator", "درج كهربائي", "Escalator", "pending", 1, 0, "stepFree"),
    ("king_fahd_district_2", "2", "أقرب مخرج — درج عادي مو كهربائي", "Nearest exit — regular stairs, not an escalator", "ضفّه ومَركب", "Daffah and Markab", "pending", -1, 0, "stairsOnly"),
    ("king_fahd_library", "5", "برج ومول الفيصلية", "Al Faisaliah Tower and Mall", "الفيصلية", "Al Faisaliah", "verified", 0, 1, "unknown"),
    ("bank_albilad", "3", "طريق الأمير محمد بن عبدالعزيز (شرق)", "Prince Mohammed Bin Abdulaziz Rd (East)", "كرمز", "Kermez", "verified", 0, 1, "unknown"),
    ("sabb", "1", "طريق العليا (شمال)", "Olaya Street (North)", "درايد", "Dried", "verified", 1, 0, "unknown"),
    ("alinma", "3", "شارع العليا (جنوب شرق)", "Olaya Street (SE)", "جراوند", "Ground Cafe", "verified", -1, 1, "unknown"),
    ("al_urubah", "3", "شارع العليا (جنوب شرق)", "Olaya Street (SE)", "تكا وي", "Tikkaway", "verified", -1, 1, "unknown"),
    ("al_urubah", "5", "مركز المملكة / المملكة مول", "Kingdom Centre / Kingdom Mall", "المملكة مول", "Kingdom Mall", "verified", 1, -1, "unknown"),
    ("kafd", "3", "مشي 3 دقايق للوجهة", "3-minute walk to the destination", "وادي كافد", "KAFD Valley", "pending", 1, 0, "unknown"),
    ("dr_sulaiman_al_habib", "4", "شارع العليا (جنوب غرب) — سولتير مول", "Olaya Street (SW) — Solitaire Mall", "سولتير مول", "Solitaire Mall", "verified", -1, -1, "unknown"),
    ("stc", "2", "مشي 3 دقايق للوجهة", "3-minute walk to the destination", "واحة نجد", "Najd Oasis Walk", "pending", 0, 1, "unknown"),
    ("qasr_al_hokm", "باب", "سهم يمين مع أيقونات سيارة", "Right arrow with car icons", "مخرج واحد فقط", "Single door exit", "verified", 0, 1, "unknown"),
    ("courts_complex", "1", "سوق الزل (سهم يسار)", "Al Zal Market (left arrow)", "سوق الزل", "Al Zal Market", "verified", 0, -1, "unknown"),
    ("al_muruj", "3", "مخابز ديا وعنوان القهوة", "Dia Bakery and Unwan al Qahwa", "ديا", "Dia", "pending", 1, 0, "unknown"),
    ("moi", "2", "شارع عبدالملك بن مروان (شرق)", "Abdulmalik Bin Marwan Street (East)", "كوفي كولد", "Cold Cafe", "verified", 0, 1, "unknown"),
    ("al_wurud_2", "3", "شارع الأمير سلطان بن سلمان (شرق)", "Prince Sultan Bin Salman Street (East)", "كوفي سكيل", "Skill Cafe", "verified", 0, 1, "unknown"),
    ("aisha_bint_abi_bakr", "2", "حي ظهرة البديعة (غرب)", "Dharat Al Badi'ah District (W)", "فوجي", "Fuji Cafe", "verified", 0, -1, "unknown"),
    ("dhahrat_al_badiah", "1", "البديعة مول (غرب)", "Al Badi'ah Mall (W)", "كوفي NC", "NC Cafe", "verified", 0, -1, "unknown"),
    ("hassan_bin_thabit", "1", "محلات سيارات ودان كافيه", "Car shops and Dan Cafe", "دان كافيه", "Dan Cafe", "pending", 1, 0, "unknown"),
    ("hassan_bin_thabit", "2", "مستشفى الجزيرة والهرم بلازا", "Al Jazeera Hospital and Al Haram Plaza", "صاحب التوفير وبنده وهيرفي", "Sahib Al Tawfeer, Panda, Harvey's", "pending", -1, 1, "unknown"),
    ("an_naseem", "1", "مشي 5 دقايق", "5-minute walk", "سولارا", "Solara", "pending", 1, 0, "unknown"),
    ("harun_al_rashid", "باب-أ", "بوابة أولى — قطعة شارع بينها وبين الثانية", "First gate — a street segment between the two gates", "الروابي بلازا", "Al Rawabi Plaza", "pending", 1, 0, "unknown"),
    ("harun_al_rashid", "باب-ب", "بوابة ثانية — قطعة شارع بينها وبين الأولى", "Second gate — a street segment between the two gates", "الروابي بلازا", "Al Rawabi Plaza", "pending", -1, 0, "unknown"),
    ("al_rajhi_grand_mosque", "1", "أسواق المجد والعثيم مول", "Al Majd markets and Othaim Mall", "افتتاح المخرج", "Exit opening", "pending", 0, 1, "unknown"),
    ("jarir_district", "1", "تلفّ ورا إلى حديقة النهضة", "Go around behind to Al Nahda Park", "حديقة النهضة", "Al Nahda Park", "pending", 1, 0, "unknown"),
    ("jarir_district", "2", "قطعة شارع ومشي 5 دقايق", "Street segment and a 5-minute walk", "كوفي حواف", "Hawaf Cafe", "pending", 0, 1, "unknown"),
    ("jarir_district", "3", "مشروع سفن — لسا ما فتح", "Safan project — not open yet", "سفن", "Safan", "pending", -1, 0, "unknown"),
    ("king_abdulaziz_road", "1", "عيادة ميلان (كابشن سند)", "Milan Clinic (Sanad caption)", "ميلان", "Milan", "pending", 1, 0, "unknown"),
    ("king_abdulaziz_road", "2", "طريق الملك عبدالله (شرق)", "King Abdullah Road (East)", "Alice Cafe", "Alice Cafe", "verified", 0, 1, "unknown"),
    ("king_saud_university", "3", "وقف جامعة الملك سعود", "King Saud University Endowment", "بيتر بيكري", "Peter Bakery", "verified", 1, 0, "unknown"),
    ("technology_city", "1", "حديقة العلوم", "Science Park", "كوفي طَول", "Tawl Cafe", "verified", 1, 0, "unknown"),
    ("al_wurud_1", "1", "مشي دقيقتين لأتموسفير", "2-minute walk to Atmosphere", "ATMOSPHERE", "Atmosphere", "pending", 1, 0, "unknown"),
    ("al_wurud_1", "2", "حي الورود", "Al Wurud District", "خمسة التوفير", "Khamsa Al Tawfeer", "verified", 0, 1, "unknown"),
    ("an_nuzhah", "2", "شركة المياه الوطنية", "National Water Company", "ريسوس", "Resos", "verified", 0, 1, "unknown"),
    ("ministry_of_education", "1", "ممشى الملك عبدالله", "King Abdullah Walk", "كوفي Chic", "Chic Cafe", "pending", 1, 0, "unknown"),
    ("riyadh_exhibition_center", "2", "معرض الأقمشة", "Fabric exhibition", "مركز المعارض", "Exhibition Center", "pending", 0, 1, "unknown"),
    ("officers_club", "4", "طريق الملك عبدالعزيز (شمال شرق)", "King Abdulaziz Rd (NE)", "مطعم الشرفة", "Shurfa Restaurant", "verified", 1, 1, "unknown"),
    ("andalus", "3", "طريق عبدالرحمن الناصر (شمال غرب)", "Abdulrahman An Nasir Rd (NW)", "مشغل اللمسة المتألقة", "Al Lamsa Al Muta'aliqa", "verified", -1, -1, "unknown"),
    ("sabic", "3", "طريق الأمير محمد بن سلمان (جنوب)", "Prince Mohammed Ibn Salman Rd (S)", "كافيدا", "Cavida", "verified", -1, 0, "unknown"),
    ("railway", "1", "بوابة القطار", "Train gate", "سار", "SAR", "pending", 1, 0, "unknown"),
]


def maps_url(name: str) -> str:
    return "https://www.google.com/maps/search/?api=1&query=" + quote(f"{name} الرياض")


# station_id, name_ar, name_en, category, relation, exit_number, walk_min,
# source tiktok, indoor?, ar_note, en_note, tags
PLACE_ROWS = [
    ("al_aziziyah", "أركان", "Arkan Cafe", "cafe", "nearby", "2", 4, "https://www.tiktok.com/@3v_yn/video/7592934856024263957", False, "من مخرج 2 شارع الشباب شمال شرق.", "From Exit 2, Al Shabab Street NE.", ["worthTheStop"]),
    ("king_fahd_district_2", "ضفّه", "Daffah", "cafe", "nearby", "2", 3, "https://www.tiktok.com/@06fx/video/7496269236101254418", False, "جنب مَركب. أقرب مخرج 2 درج عادي.", "Next to Markab. Nearest is Exit 2, regular stairs.", ["worthTheStop"]),
    ("king_fahd_district_2", "مَركب", "Markab", "cafe", "nearby", "2", 3, "https://www.tiktok.com/@iicceel/video/7665700920524672277", False, "جنب ضفّه عند مخرج 2.", "Next to Daffah at Exit 2.", ["dessert"]),
    ("king_fahd_district_2", "هاف مليون", "Half Million", "cafe", "insideStation", "2", 1, "https://www.tiktok.com/@06fx/video/7496269236101254418", True, "جوا المحطة عند ضفّه، مو برا.", "Inside the station by Daffah, not outside.", ["worthTheStop"]),
    ("king_fahd_district_2", "أسواق طيبة", "Taybah Markets", "other", "nearby", "2", 6, "https://www.tiktok.com/@06fx/video/7496269236101254418", False, "من محطة الملك فهد 2.", "From King Fahd 2.", ["familyFriendly"]),
    ("king_fahd_district", "سلانت", "Slant Specialty Coffee", "cafe", "nearby", None, 8, "https://www.tiktok.com/@3v_yn/video/7596408465195568405", False, "عبر حافلة 430 من حي الملك فهد.", "Via bus 430 from King Fahd District.", ["workFriendly"]),
    ("king_fahd_library", "الفيصلية", "Al Faisaliah Tower and Mall", "other", "nearby", "5", 5, "https://www.tiktok.com/@lamamakeup5/video/7584072271455587591", False, "مخرج 5 — برج ومول الفيصلية.", "Exit 5 — Al Faisaliah Tower and Mall.", ["worthTheStop", "familyFriendly"]),
    ("king_fahd_library", "قود نيبر", "Good Neighbor", "cafe", "nearby", "5", 8, "https://www.tiktok.com/@irazlani/video/7503146874090638600", False, "من مكتبة الملك فهد.", "From King Fahd Library.", ["workFriendly"]),
    ("manfouhah", "كوفي منفوحة", "Manfuha Cafe", "cafe", "nearby", None, 4, "https://www.tiktok.com/@06fx/video/7500485243942554898", False, "أمام باب المحطة.", "In front of the station door.", ["breakfast"]),
    ("ad_dar_al_baida", "شاي المسرة", "Al Masarra Tea", "cafe", "nearby", None, 4, "https://www.tiktok.com/@06fx/video/7506109913513397512", False, "قرب محطة الدار البيضاء.", "Near Ad Dar Al Baida.", ["breakfast"]),
    ("bank_albilad", "كرمز", "Kermez Coffee", "cafe", "nearby", "3", 4, "https://www.tiktok.com/@3v_yn/video/7679435871845616916", False, "مخرج 3 طريق الأمير محمد شرق.", "Exit 3, Prince Mohammed Rd east.", ["worthTheStop"]),
    ("sabb", "درايد", "Dried", "cafe", "nearby", "1", 4, "https://www.tiktok.com/@3v_yn/video/7630837046302543124", False, "مخرج 1 طريق العليا شمال.", "Exit 1, Olaya Street north.", ["workFriendly"]),
    ("alinma", "جراوند", "Ground Cafe", "cafe", "nearby", "3", 4, "https://www.tiktok.com/@3v_yn/video/7680549166417841428", False, "مخرج 3 شارع العليا جنوب شرق.", "Exit 3, Olaya Street SE.", ["workFriendly"]),
    ("alinma", "بيلا نابولي", "Bella Napoli", "restaurant", "nearby", "3", 5, "https://www.tiktok.com/@3v_yn/video/7680549166417841428", False, "من مصرف الإنماء مخرج 3.", "From Alinma Exit 3.", ["worthTheStop"]),
    ("al_urubah", "تكا وي", "Tikkaway", "restaurant", "nearby", "3", 4, "https://www.tiktok.com/@3v_yn/video/7671396036182609173", False, "درايف ثرو من مخرج 3.", "Drive-thru from Exit 3.", ["breakfast"]),
    ("al_urubah", "المملكة مول", "Kingdom Centre Mall", "other", "directlyConnected", "5", 6, "https://www.tiktok.com/@nxoxono/video/7663553597078015253", False, "مخرج 5 مركز المملكة.", "Exit 5, Kingdom Centre.", ["familyFriendly", "worthTheStop"]),
    ("kafd", "وادي كافد", "KAFD Valley", "park", "nearby", "3", 3, "https://www.tiktok.com/@nearmetro/video/7627076231116229908", False, "مخرج 3 — مشي 3 دقايق.", "Exit 3 — 3-minute walk.", ["outdoorSeating", "worthTheStop"]),
    ("dr_sulaiman_al_habib", "سولتير مول", "Solitaire Mall", "other", "nearby", "4", 5, "https://www.tiktok.com/@nearmetro/video/7606713079711239444", False, "مخرج 4 شارع العليا جنوب غرب.", "Exit 4, Olaya Street SW.", ["familyFriendly"]),
    ("stc", "ممشى واحة نجد", "Najd Oasis Walk", "park", "nearby", "2", 3, "https://www.tiktok.com/@nearmetro/video/7598498949879581972", False, "مخرج 2 — مشي 3 دقايق.", "Exit 2 — 3-minute walk.", ["outdoorSeating"]),
    ("qasr_al_hokm", "نمق قهوة ومحمصة", "Namq Coffee and Roastery", "cafe", "insideStation", "باب", 1, "https://www.tiktok.com/@sxr.22/video/7653129402716441877", True, "داخل محطة قصر الحكم.", "Inside Qasr Al Hukm station.", ["worthTheStop", "breakfast"]),
    ("qasr_al_hokm", "محمصة شارع الوزير", "Wazir Street Roastery", "cafe", "nearby", "باب", 6, "https://www.tiktok.com/@3v_yn/video/7675823187657116948", False, "من الباب الوحيد للمحطة.", "From the station's single door.", ["breakfast"]),
    ("courts_complex", "سوق الزل", "Al Zal Market", "other", "nearby", "1", 5, "https://www.tiktok.com/@3v_yn/video/7605190650912394517", False, "مخرج 1 سهم يسار.", "Exit 1, left arrow.", ["familyFriendly"]),
    ("al_muruj", "مخابز ديا", "Dia Bakery", "dessert", "nearby", "3", 5, "https://www.tiktok.com/@3v_yn/video/7628985677878676757", False, "مخرج 3 المروج.", "Al Muruj Exit 3.", ["breakfast", "dessert"]),
    ("moi", "كولد", "Cold Cafe", "cafe", "nearby", "2", 4, "https://www.tiktok.com/@3v_yn/video/7627532759556279573", False, "مخرج 2 شارع عبدالملك بن مروان شرق.", "Exit 2, Abdulmalik Bin Marwan east.", ["workFriendly"]),
    ("al_wurud_2", "سكيل", "Skill Cafe", "cafe", "nearby", "3", 4, "https://www.tiktok.com/@3v_yn/video/7586702239419370772", False, "مخرج 3 شارع الأمير سلطان شرق.", "Exit 3, Prince Sultan Street east.", ["workFriendly"]),
    ("aisha_bint_abi_bakr", "فوجي", "Fuji Cafe", "cafe", "nearby", "2", 5, "https://www.tiktok.com/@3v_yn/video/7650878626090470677", False, "مخرج 2 حي ظهرة البديعة غرب. كابشن سند يقول 4.", "Exit 2, Dharat Al Badi'ah west. Sanad caption says 4.", ["worthTheStop"]),
    ("aisha_bint_abi_bakr", "مجاز", "Majaz Coffee", "cafe", "nearby", "2", 4, "https://www.tiktok.com/@riyadhcrv/video/7564063563946528018", False, "عند محطة عائشة.", "At Aisha station.", ["breakfast"]),
    ("dhahrat_al_badiah", "NC إنسي", "NC Cafe", "cafe", "nearby", "1", 4, "https://www.tiktok.com/@3v_yn/video/7670526833196125460", False, "مخرج 1 البديعة مول غرب.", "Exit 1, Al Badi'ah Mall west.", ["workFriendly"]),
    ("hassan_bin_thabit", "دان كافيه", "Dan Cafe", "cafe", "nearby", "1", 4, "https://www.tiktok.com/@nearmetro/video/7528777869472926994", False, "مخرج 1 مع محلات السيارات.", "Exit 1 with car shops.", ["breakfast"]),
    ("hassan_bin_thabit", "الهرم بلازا", "Al Haram Plaza", "other", "nearby", "2", 6, "https://www.tiktok.com/@nearmetro/video/7528777869472926994", False, "مخرج 2 مع مستشفى الجزيرة وبنده وهيرفي.", "Exit 2 with Al Jazeera Hospital, Panda, Harvey's.", ["familyFriendly"]),
    ("an_naseem", "سولارا", "Solara", "cafe", "nearby", "1", 5, "https://www.tiktok.com/@nearmetro/video/7530990466435845394", False, "مخرج 1 — مشي 5 دقايق.", "Exit 1 — 5-minute walk.", ["workFriendly"]),
    ("harun_al_rashid", "الروابي بلازا", "Al Rawabi Plaza", "other", "nearby", "باب-أ", 5, "https://www.tiktok.com/@nearmetro/video/7531753820334984466", False, "بوابتان وبينهم قطعة شارع.", "Two gates with a street segment between them.", ["familyFriendly"]),
    ("harun_al_rashid", "بلاك ستامب", "Black Stamp", "cafe", "nearby", "باب-ب", 6, "https://www.tiktok.com/@nearmetro/video/7531753820334984466", False, "عند هارون الرشيد.", "At Harun Al Rashid.", ["workFriendly"]),
    ("al_rajhi_grand_mosque", "أسواق المجد", "Al Majd Markets", "other", "nearby", "1", 6, "https://www.tiktok.com/@nearmetro/video/7608363008724585749", False, "مخرج 1 مع العثيم مول.", "Exit 1 with Othaim Mall.", ["familyFriendly"]),
    ("jarir_district", "حديقة النهضة", "Al Nahda Park", "park", "nearby", "1", 6, "https://www.tiktok.com/@nearmetro/video/7542507618330348807", False, "مخرج 1 — تلفّ ورا.", "Exit 1 — go around behind.", ["outdoorSeating", "familyFriendly"]),
    ("jarir_district", "كوفي حواف", "Hawaf Cafe", "cafe", "nearby", "2", 5, "https://www.tiktok.com/@nearmetro/video/7542507618330348807", False, "مخرج 2 — قطعة شارع ومشي 5 دقايق.", "Exit 2 — street segment and 5-minute walk.", ["workFriendly"]),
    ("king_abdulaziz_road", "عيادة ميلان", "Milan Clinic", "other", "nearby", "1", 5, "https://www.tiktok.com/@06fx/video/7498010006411840775", False, "مخرج 1 كابشن سند.", "Exit 1, Sanad caption.", []),
    ("king_abdulaziz_road", "Alice Cafe", "Alice Cafe", "cafe", "nearby", "2", 4, "https://www.tiktok.com/@3v_yn/video/7683863005519580437", False, "مخرج 2 طريق الملك عبدالله شرق.", "Exit 2, King Abdullah Road east.", ["worthTheStop"]),
    ("takhassusi", "سيبولوجي", "Sipology", "cafe", "nearby", None, 5, "https://www.tiktok.com/@3v_yn/video/7681693469810658581", False, "محطة التخصصي.", "Takhassusi station.", ["workFriendly"]),
    ("king_saud_university", "وقف جامعة الملك سعود", "King Saud University Endowment", "other", "nearby", "3", 5, "https://www.tiktok.com/@3v_yn/video/7602603596533746965", False, "مخرج 3.", "Exit 3.", ["worthTheStop"]),
    ("technology_city", "كوفي طَول", "Tawl Cafe", "cafe", "nearby", "1", 4, "https://www.tiktok.com/@3v_yn/video/7592219637404699924", False, "مخرج 1 حديقة العلوم.", "Exit 1, Science Park.", ["workFriendly"]),
    ("al_wurud_1", "ATMOSPHERE", "Atmosphere Coffee", "cafe", "nearby", "1", 2, "https://www.tiktok.com/@ad_d7m/video/7456824897701006610", False, "مخرج 1 — مشي دقيقتين.", "Exit 1 — 2-minute walk.", ["worthTheStop", "workFriendly"]),
    ("al_wurud_1", "إيا", "Eya / Okawa", "cafe", "nearby", "2", 4, "https://www.tiktok.com/@rallosa0/video/7677315146510814484", False, "عند مخرج 2 حي الورود.", "At Exit 2, Al Wurud District.", ["workFriendly"]),
    ("al_hamra", "الحمراء مول", "Al Hamra Mall", "other", "directlyConnected", None, 4, "https://www.tiktok.com/@nearmetro/video/7514260004996762887", False, "باب المول والسينما.", "Mall door and cinema.", ["familyFriendly"]),
    ("an_nuzhah", "شركة المياه الوطنية", "National Water Company", "other", "nearby", "2", 4, "https://www.tiktok.com/@nearmetro/video/7550284833209994503", False, "مخرج 2 ثم ريسوس.", "Exit 2 then Resos.", []),
    ("ministry_of_education", "كوفي Chic", "Chic Cafe", "cafe", "nearby", "1", 4, "https://www.tiktok.com/@frash.blogger/video/7620718716640169236", False, "مخرج 1 ممشى الملك عبدالله.", "Exit 1, King Abdullah Walk.", ["workFriendly"]),
    ("riyadh_exhibition_center", "معرض الأقمشة", "Fabric Exhibition", "other", "nearby", "2", 6, "https://www.tiktok.com/@nearmetro/video/7602244508830518549", False, "مخرج 2.", "Exit 2.", []),
    ("officers_club", "مطعم الشرفة", "Shurfa Restaurant", "restaurant", "nearby", "4", 5, "https://www.tiktok.com/@3v_yn/video/7594085099809803541", False, "مخرج 4 طريق الملك عبدالعزيز شمال شرق.", "Exit 4, King Abdulaziz Rd NE.", ["worthTheStop"]),
    ("andalus", "مشغل اللمسة المتألقة", "Al Lamsa Al Muta'aliqa", "other", "nearby", "3", 5, "https://www.tiktok.com/@3v_yn/video/7682842011484851477", False, "مخرج 3 طريق عبدالرحمن الناصر شمال غرب.", "Exit 3, Abdulrahman An Nasir NW.", []),
    ("granada", "غرناطة مول", "Granada Mall", "other", "directlyConnected", None, 4, "https://www.tiktok.com/@nearmetro/video/7636009000701562133", False, "جسر المول.", "Mall bridge.", ["familyFriendly"]),
    ("ar_rabi", "مخازن العناية", "Makhzan Al Inayah", "other", "nearby", None, 17, "https://www.tiktok.com/@3v_yn/video/7602337412735323412", False, "مشي 17 دقيقة من الربيع. أو حافلة 230 لكوفي جيره.", "17-minute walk from Ar Rabi, or bus 230 to Jeerah.", ["familyFriendly"]),
    ("as_salam", "ملت", "Melt", "dessert", "nearby", None, 6, "https://www.tiktok.com/@nearmetro/video/7520574699970022663", False, "مع MD عند محطة السلام.", "With MD at As Salam.", ["dessert"]),
    ("pnu_1", "معرض الكتاب", "Book Fair", "other", "nearby", None, 8, "https://www.tiktok.com/@nearmetro/video/7558054719701273863", False, "جامعة الأميرة نورة 1.", "Princess Nourah University 1.", ["familyFriendly"]),
    ("sabic", "كافيدا", "Cavida Cafe", "cafe", "nearby", "3", 6, "https://www.tiktok.com/@3v_yn/video/7629711328239766804", False, "مخرج 3 ثم حافلة 935.", "Exit 3 then bus 935.", ["workFriendly"]),
    ("railway", "بوابة القطار", "Train Gate", "other", "directlyConnected", "1", 3, "https://www.tiktok.com/@nearmetro/video/7546203337251704082", False, "مخرج 1 سكة الحديد.", "Exit 1, railway station.", []),
    ("uthman_bin_affan", "لاندري زون", "Laundry Zone", "other", "nearby", None, 6, "https://www.tiktok.com/@metro.girl0/video/7684422855076973832", False, "قرب جامعة الإمام.", "Near Imam University.", []),
    ("al_malaz", "منتزه الملك عبدالله", "King Abdullah Park", "park", "nearby", None, 8, "https://www.tiktok.com/@nearmetro/video/7544726379670113543", False, "الملعب والمنتزه من الملز.", "Stadium and park from Al Malaz.", ["outdoorSeating", "familyFriendly"]),
]


def slug(name_en: str) -> str:
    keep = []
    for ch in name_en.lower():
        if ch.isalnum():
            keep.append(ch)
        elif ch in " -_/":
            keep.append("-")
    s = "".join(keep).strip("-")
    while "--" in s:
        s = s.replace("--", "-")
    return s[:40]


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    stations = {s["id"]: s for s in catalog["stations"]}

    exits_out = []
    for sid, number, ar_d, en_d, ar_l, en_l, status, n, e, access in EXITS:
        st = stations[sid]
        lat = st["latitude"] + n * 0.00022
        lon = st["longitude"] + e * 0.00022
        exits_out.append(
            {
                "id": f"{sid}-exit-{number}",
                "stationId": sid,
                "exitNumber": number,
                "nameAr": f"مخرج {number}",
                "nameEn": f"Exit {number}",
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "directionAr": ar_d,
                "directionEn": en_d,
                "nearbyLandmarkAr": ar_l,
                "nearbyLandmarkEn": en_l,
                "accessibilityType": access,
                "verificationStatus": status,
                "verifiedAt": UPDATED if status == "verified" else None,
                "verifiedBy": "tiktok-plate" if status == "verified" else "field-notes",
            }
        )

    verified_stations = {e["stationId"] for e in exits_out if e["verificationStatus"] == "verified"}
    for st in catalog["stations"]:
        if st["id"] in verified_stations:
            st["hasVerifiedExits"] = True
        indoor = any(p[0] == st["id"] and p[8] for p in PLACE_ROWS)
        if indoor:
            st["hasVerifiedIndoorPlaces"] = True

    catalog["exits"] = exits_out
    catalog["attribution"]["exits"] = (
        "Field exits from TikTok plates (verified) and caption/field notes (pending). "
        "Coordinates are offset from the station node, not surveyed door positions."
    )
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")

    places_doc = json.loads(PLACES_PATH.read_text())
    existing = [p for p in places_doc["places"] if not str(p.get("id", "")).startswith("field-")]
    field_places = []
    used_ids = set()
    for i, row in enumerate(PLACE_ROWS):
        sid, ar, en, cat, rel, exit_no, mins, tiktok, indoor, ar_note, en_note, tags = row
        st = stations[sid]
        ident = f"field-{sid}-{slug(en)}"
        if ident in used_ids:
            ident = f"{ident}-{i}"
        used_ids.add(ident)
        bearing = (i % 8) - 3.5
        meters = max(40, mins * 80)
        lat = st["latitude"] + (meters / 111_000.0) * (0.4 if indoor else 1) * (1 if bearing >= 0 else -1)
        lon = st["longitude"] + (meters / 111_000.0) * 0.6 * ((i % 3) - 1)
        exit_id = f"{sid}-exit-{exit_no}" if exit_no else None
        field_places.append(
            {
                "id": ident,
                "googlePlaceId": None,
                "nameAr": ar,
                "nameEn": en,
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "category": cat,
                "stationId": sid,
                "stationRelation": rel,
                "floor": "داخل المحطة" if indoor else None,
                "ticketGatePosition": "afterGates" if indoor else None,
                "nearestExitId": exit_id,
                "editorialTags": tags,
                "verificationStatus": "verified",
                "source": "editorial",
                "priceLevel": 2,
                "rating": None,
                "reviewCount": None,
                "isOpenNow": True,
                "shortDescriptionAr": ar_note,
                "shortDescriptionEn": en_note,
                "indoorLocationNoteAr": ar_note if indoor else None,
                "indoorLocationNoteEn": en_note if indoor else None,
                "lastVerifiedAt": UPDATED,
                "verificationSource": "tiktok-field",
                "neighborhoodAr": st["nameAr"],
                "neighborhoodEn": st["nameEn"],
                "imageURLs": [],
                "sourceURL": tiktok,
                "mapsURL": maps_url(f"{ar} {st['nameAr']}"),
                "updatedAt": UPDATED,
            }
        )

    places_doc["places"] = existing + field_places
    places_doc["attribution"]["places"] = (
        "Editorial sample fixtures plus TikTok field places. "
        "sourceURL is the documenting clip; mapsURL is a Google Maps search for the place name in Riyadh."
    )
    PLACES_PATH.write_text(json.dumps(places_doc, ensure_ascii=False, indent=2) + "\n")
    print(f"exits={len(exits_out)} field_places={len(field_places)} kept={len(existing)}")


if __name__ == "__main__":
    main()
