#!/usr/bin/env python3
"""Build the v1 metro catalog from public OSM coordinates + published line order."""
from __future__ import annotations

import json
from pathlib import Path

# OpenStreetMap node coordinates (public data). Keys are match aliases.
OSM = {
    "dr_sulaiman_al_habib": (24.811571, 46.625692),
    "pnu_1": (24.841609, 46.717399),
    "pnu_2": (24.859675, 46.704416),
    "airport_t5": (24.940513, 46.710470),
    "airport_t34": (24.955792, 46.702356),
    "airport_t12": (24.961056, 46.698985),
    "sabic": (24.807123, 46.709354),
    "uthman_bin_affan": (24.801437, 46.696041),
    "king_fahd_sports_city": (24.793083, 46.836429),
    "ishbiliyah": (24.792275, 46.810810),
    "yarmouk": (24.791313, 46.766320),
    "granada": (24.786467, 46.729166),
    "ar_rabi": (24.786336, 46.660264),
    "al_khaleej": (24.782175, 46.794410),
    "al_hamra": (24.776347, 46.776483),
    "kafd": (24.767430, 46.643198),
    "khalid_bin_al_waleed": (24.767844, 46.759367),
    "andalus": (24.756731, 46.790261),
    "riyadh_exhibition": (24.754552, 46.727108),
    "al_muruj": (24.754257, 46.654504),
    "an_nuzhah": (24.748211, 46.712420),
    "king_fahd_district": (24.744943, 46.659297),
    "khurais": (24.740798, 46.798605),
    "ministry_of_education": (24.740584, 46.695708),
    "king_abdulaziz_road": (24.736772, 46.685314),
    "king_fahd_district_2": (24.736320, 46.663630),
    "al_wurud": (24.733359, 46.677231),
    "stc": (24.727202, 46.668258),
    "takhassusi": (24.723717, 46.654373),
    "as_salam": (24.722750, 46.811216),
    "khashm_al_an": (24.721665, 46.860699),
    "kacst": (24.720468, 46.646663),
    "king_salman_oasis": (24.717002, 46.638598),
    "as_sulimaniyah": (24.712898, 46.700291),
    "hassan_bin_thabit": (24.712800, 46.847572),
    "king_saud_university": (24.710230, 46.628340),
    "ad_dhabab": (24.709698, 46.707839),
    "alinma": (24.703437, 46.680199),
    "an_naseem": (24.700477, 46.827540),
    "officers_club": (24.698283, 46.717931),
    "bank_albilad": (24.696506, 46.683700),
    "king_fahd_library": (24.690195, 46.686975),
    "gosi": (24.686753, 46.718148),
    "harun_al_rashid": (24.686092, 46.795962),
    "al_rajhi_mosque": (24.680222, 46.779484),
    "ministries": (24.675384, 46.718350),
    "moi": (24.674417, 46.694888),
    "jarir": (24.673057, 46.760406),
    "mod": (24.667830, 46.718277),
    "malaz": (24.660406, 46.744549),
    "mewa": (24.659827, 46.717724),
    "mof": (24.652602, 46.716431),
    "railway": (24.649509, 46.740697),
    "national_museum": (24.645361, 46.713125),
    "first_industrial": (24.644709, 46.739393),
    "al_batha": (24.638300, 46.714848),
    "salhiyah": (24.637765, 46.732844),
    "marqab": (24.634503, 46.726289),
    "halah": (24.632250, 46.721793),
    "qasr_al_hokm": (24.628783, 46.716177),
    "courts": (24.626750, 46.712283),
    "juradiyah": (24.618367, 46.697793),
    "sultanah": (24.614870, 46.686309),
    "dhahrat_al_badiah": (24.606688, 46.653848),
    "aisha": (24.600587, 46.643810),
    "jeddah_road": (24.591576, 46.543602),
    "aziziyah": (24.587295, 46.760865),
    "tuwaiq": (24.585500, 46.559837),
    "ad_douh": (24.582516, 46.588490),
    "western": (24.581812, 46.614579),
    "dar_al_baida": (24.560093, 46.776307),
    "salahaddin": (24.728451, 46.700614),
}


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def osm(key):
    lat, lon = OSM[key]
    return lat, lon, "openStreetMap"


def approx(coord, note):
    return coord[0], coord[1], "approximatePublic"


# Interpolated / extended public approximations for stations not in OSM extract.
SABB = lerp(OSM["dr_sulaiman_al_habib"], (24.855, 46.608), 0.55)
AL_URUBAH = lerp(OSM["stc"], OSM["alinma"], 0.45)
AL_WURUD_2 = lerp(OSM["stc"], OSM["alinma"], 0.18)
AL_MURABBA = lerp(OSM["moi"], OSM["national_museum"], 0.35)
JAWAZAT = lerp(OSM["moi"], OSM["national_museum"], 0.68)
AL_OUD = lerp(OSM["qasr_al_hokm"], OSM["aziziyah"], 0.16)
SKIRINAH = lerp(OSM["qasr_al_hokm"], OSM["aziziyah"], 0.32)
MANFOUHAH = lerp(OSM["qasr_al_hokm"], OSM["aziziyah"], 0.48)
IMAN = lerp(OSM["qasr_al_hokm"], OSM["aziziyah"], 0.64)
PTC = lerp(OSM["qasr_al_hokm"], OSM["aziziyah"], 0.80)
KING_SALMAN_PARK = lerp(OSM["ministry_of_education"], OSM["as_sulimaniyah"], 0.45)
ABU_DHABI = lerp(OSM["ad_dhabab"], OSM["officers_club"], 0.5)
KAAH = OSM["mewa"]  # nearest mapped civic stop on King Abdulaziz Rd

LINES = [
    {
        "id": "blue",
        "nameAr": "المسار الأزرق",
        "nameEn": "Blue Line",
        "colorHex": "#0070C0",
        "displayOrder": 1,
        "shortCode": "1",
    },
    {
        "id": "red",
        "nameAr": "المسار الأحمر",
        "nameEn": "Red Line",
        "colorHex": "#C8102E",
        "displayOrder": 2,
        "shortCode": "2",
    },
    {
        "id": "orange",
        "nameAr": "المسار البرتقالي",
        "nameEn": "Orange Line",
        "colorHex": "#F36C21",
        "displayOrder": 3,
        "shortCode": "3",
    },
    {
        "id": "yellow",
        "nameAr": "المسار الأصفر",
        "nameEn": "Yellow Line",
        "colorHex": "#E2B400",
        "displayOrder": 4,
        "shortCode": "4",
    },
    {
        "id": "green",
        "nameAr": "المسار الأخضر",
        "nameEn": "Green Line",
        "colorHex": "#009639",
        "displayOrder": 5,
        "shortCode": "5",
    },
    {
        "id": "purple",
        "nameAr": "المسار البنفسجي",
        "nameEn": "Purple Line",
        "colorHex": "#6F2C91",
        "displayOrder": 6,
        "shortCode": "6",
    },
]

# id, ar, en, lines, coord_fn, type, facilities
# stationType: underground | elevated | atGrade | interchangeHub
STATIONS = [
    # Blue
    ("sabb", "ساب", "SABB", ["blue"], approx(SABB, ""), "elevated", ["parking"]),
    ("dr_sulaiman_al_habib", "د. سليمان الحبيب", "Dr. Sulaiman Al Habib", ["blue"], osm("dr_sulaiman_al_habib"), "elevated", ["parking"]),
    ("kafd", "كافد", "KAFD", ["blue", "yellow", "purple"], osm("kafd"), "interchangeHub", ["parking", "prayerRoom", "retail", "customerService"]),
    ("al_muruj", "المروج", "Al Muruj", ["blue"], osm("al_muruj"), "elevated", []),
    ("king_fahd_district", "حي الملك فهد", "King Fahd District", ["blue"], osm("king_fahd_district"), "underground", []),
    ("king_fahd_district_2", "حي الملك فهد 2", "King Fahd District 2", ["blue"], osm("king_fahd_district_2"), "underground", []),
    ("stc", "STC", "STC", ["blue", "red"], osm("stc"), "interchangeHub", ["parking", "prayerRoom", "retail", "customerService"]),
    ("al_wurud_2", "الورود 2", "Al Wurud 2", ["blue"], approx(AL_WURUD_2, ""), "underground", []),
    ("al_urubah", "العروبة", "Al Urubah", ["blue"], approx(AL_URUBAH, ""), "underground", []),
    ("alinma", "مصرف الإنماء", "Alinma Bank", ["blue"], osm("alinma"), "underground", ["retail"]),
    ("bank_albilad", "بنك البلاد", "Bank Albilad", ["blue"], osm("bank_albilad"), "underground", ["retail"]),
    ("king_fahd_library", "مكتبة الملك فهد", "King Fahd Library", ["blue"], osm("king_fahd_library"), "underground", []),
    ("moi", "وزارة الداخلية", "Ministry of Interior", ["blue"], osm("moi"), "underground", []),
    ("al_murabba", "المربع", "Al Murabba", ["blue"], approx(AL_MURABBA, ""), "underground", []),
    ("jawazat", "الجوازات", "Jawazat", ["blue"], approx(JAWAZAT, ""), "underground", []),
    ("national_museum", "المتحف الوطني", "National Museum", ["blue", "green"], osm("national_museum"), "interchangeHub", ["prayerRoom", "retail", "customerService"]),
    ("al_batha", "البطحاء", "Al Batha", ["blue"], osm("al_batha"), "underground", ["retail"]),
    ("qasr_al_hokm", "قصر الحكم", "Qasr Al Hokm", ["blue", "orange"], osm("qasr_al_hokm"), "interchangeHub", ["prayerRoom", "retail", "customerService"]),
    ("al_oud", "العود", "Al Oud", ["blue"], approx(AL_OUD, ""), "elevated", []),
    ("skirinah", "سكيرينة", "Skirinah", ["blue"], approx(SKIRINAH, ""), "elevated", []),
    ("manfouhah", "منفوحة", "Manfouhah", ["blue"], approx(MANFOUHAH, ""), "elevated", []),
    ("iman_hospital", "مستشفى الإيمان", "Iman Hospital", ["blue"], approx(IMAN, ""), "elevated", []),
    ("public_transport_center", "مركز النقل العام", "Public Transport Center", ["blue"], approx(PTC, ""), "elevated", ["parking"]),
    ("al_aziziyah", "العزيزية", "Al Aziziyah", ["blue"], osm("aziziyah"), "elevated", []),
    ("ad_dar_al_baida", "الدار البيضاء", "Ad Dar Al Baida", ["blue"], osm("dar_al_baida"), "elevated", ["parking"]),
    # Red
    ("king_saud_university", "جامعة الملك سعود", "King Saud University", ["red"], osm("king_saud_university"), "elevated", ["parking"]),
    ("king_salman_oasis", "واحة الملك سلمان", "King Salman Oasis", ["red"], osm("king_salman_oasis"), "elevated", []),
    ("technology_city", "مدينة التقنية", "Technology City", ["red"], osm("kacst"), "elevated", []),
    ("takhassusi", "التخصصي", "Takhassusi", ["red"], osm("takhassusi"), "underground", []),
    ("al_wurud_1", "الورود 1", "Al Wurud 1", ["red"], osm("al_wurud"), "underground", []),
    ("king_abdulaziz_road", "طريق الملك عبدالعزيز", "King Abdulaziz Road", ["red"], osm("king_abdulaziz_road"), "underground", []),
    ("ministry_of_education", "وزارة التعليم", "Ministry of Education", ["red", "green"], osm("ministry_of_education"), "interchangeHub", []),
    ("an_nuzhah", "النزهة", "Al Nuzhah", ["red"], osm("an_nuzhah"), "elevated", []),
    ("riyadh_exhibition_center", "مركز الرياض للمعارض", "Riyadh Exhibition Center", ["red"], osm("riyadh_exhibition"), "elevated", []),
    ("khalid_bin_al_waleed", "طريق خالد بن الوليد", "Khalid Bin Al Waleed Road", ["red"], osm("khalid_bin_al_waleed"), "elevated", []),
    ("al_hamra", "الحمراء", "Al Hamra", ["red", "purple"], osm("al_hamra"), "elevated", []),
    ("al_khaleej", "الخليج", "Al Khaleej", ["red"], osm("al_khaleej"), "elevated", []),
    ("ishbiliyah", "إشبيلية", "Ishbiliyah", ["red"], osm("ishbiliyah"), "elevated", []),
    ("king_fahd_sports_city", "مدينة الملك فهد الرياضية", "King Fahd Sports City", ["red"], osm("king_fahd_sports_city"), "elevated", ["parking"]),
    # Orange
    ("jeddah_road", "طريق جدة", "Jeddah Road", ["orange"], osm("jeddah_road"), "elevated", ["parking"]),
    ("tuwaiq", "طويق", "Tuwaiq", ["orange"], osm("tuwaiq"), "elevated", []),
    ("ad_douh", "الدوح", "Ad Douh", ["orange"], osm("ad_douh"), "elevated", []),
    ("western", "المحطة الغربية", "Western Station", ["orange"], osm("western"), "interchangeHub", ["parking", "prayerRoom", "retail", "customerService"]),
    ("aisha_bint_abi_bakr", "شارع عائشة بنت أبي بكر", "Aisha Bint Abi Bakr Street", ["orange"], osm("aisha"), "elevated", []),
    ("dhahrat_al_badiah", "ظهرة البديعة", "Dhahrat Al Badiah", ["orange"], osm("dhahrat_al_badiah"), "elevated", []),
    ("sultanah", "سلطانة", "Sultanah", ["orange"], osm("sultanah"), "elevated", []),
    ("al_juradiyah", "الجرادية", "Al Juradiyah", ["orange"], osm("juradiyah"), "underground", []),
    ("courts_complex", "مجمع المحاكم", "Court Complex", ["orange"], osm("courts"), "underground", []),
    ("al_halah", "الحلة", "Al Halah", ["orange"], osm("halah"), "underground", []),
    ("al_marqab", "المرقب", "Al Marqab", ["orange"], osm("marqab"), "underground", []),
    ("as_salhiyah", "الصالحية", "As Salhiyah", ["orange"], osm("salhiyah"), "elevated", []),
    ("first_industrial_city", "المدينة الصناعية الأولى", "First Industrial City", ["orange"], osm("first_industrial"), "elevated", []),
    ("railway", "سكة الحديد", "Railway", ["orange"], osm("railway"), "elevated", []),
    ("al_malaz", "الملز", "Al Malaz", ["orange"], osm("malaz"), "elevated", []),
    ("jarir_district", "حي جرير", "Jarir District", ["orange"], osm("jarir"), "elevated", []),
    ("al_rajhi_grand_mosque", "جامع الراجحي", "Al Rajhi Grand Mosque", ["orange"], osm("al_rajhi_mosque"), "elevated", []),
    ("harun_al_rashid", "طريق هارون الرشيد", "Haroun Al Rashid Road", ["orange"], osm("harun_al_rashid"), "elevated", []),
    ("an_naseem", "النسيم", "An Naseem", ["orange", "purple"], osm("an_naseem"), "elevated", []),
    ("hassan_bin_thabit", "شارع حسان بن ثابت", "Hassan Bin Thabit Street", ["orange"], osm("hassan_bin_thabit"), "elevated", []),
    ("khashm_al_an", "خشم العان", "Khashm Al An", ["orange"], osm("khashm_al_an"), "elevated", ["parking"]),
    # Yellow
    ("ar_rabi", "الربيع", "Ar Rabi", ["yellow", "purple"], osm("ar_rabi"), "elevated", []),
    ("uthman_bin_affan", "طريق عثمان بن عفان", "Uthman Bin Affan Road", ["yellow", "purple"], osm("uthman_bin_affan"), "elevated", []),
    ("sabic", "سابك", "SABIC", ["yellow", "purple"], osm("sabic"), "elevated", []),
    ("pnu_1", "جامعة الأميرة نورة 1", "Princess Nourah University 1", ["yellow"], osm("pnu_1"), "elevated", []),
    ("pnu_2", "جامعة الأميرة نورة 2", "Princess Nourah University 2", ["yellow"], osm("pnu_2"), "elevated", []),
    ("airport_t5", "مطار الملك خالد — الصالة 5", "Airport Terminal 5", ["yellow"], osm("airport_t5"), "atGrade", ["parking"]),
    ("airport_t34", "مطار الملك خالد — الصالتان 3–4", "Airport Terminals 3–4", ["yellow"], osm("airport_t34"), "atGrade", ["parking"]),
    ("airport_t12", "مطار الملك خالد — الصالتان 1–2", "Airport Terminals 1–2", ["yellow"], osm("airport_t12"), "atGrade", ["parking"]),
    # Green remaining
    ("king_salman_park", "حديقة الملك سلمان", "King Salman Park", ["green"], approx(KING_SALMAN_PARK, ""), "underground", []),
    ("as_sulimaniyah", "السليمانية", "As Sulimaniyah", ["green"], osm("as_sulimaniyah"), "underground", []),
    ("ad_dhabab", "الضباب", "Ad Dhabab", ["green"], osm("ad_dhabab"), "underground", []),
    ("abu_dhabi_square", "ساحة أبوظبي", "Abu Dhabi Square", ["green"], approx(ABU_DHABI, ""), "underground", []),
    ("officers_club", "نادي الضباط", "Officers Club", ["green"], osm("officers_club"), "underground", []),
    ("gosi", "التأمينات الاجتماعية", "GOSI", ["green"], osm("gosi"), "underground", []),
    ("ministries", "الوزارات", "Ministries", ["green"], osm("ministries"), "underground", []),
    ("ministry_of_defense", "وزارة الدفاع", "Ministry of Defense", ["green"], osm("mod"), "underground", []),
    ("king_abdulaziz_hospital", "مستشفى الملك عبدالعزيز", "King Abdulaziz Hospital", ["green"], osm("mewa"), "underground", []),
    ("ministry_of_finance", "وزارة المالية", "Ministry of Finance", ["green"], osm("mof"), "underground", []),
    # Purple remaining
    ("granada", "غرناطة", "Granada", ["purple"], osm("granada"), "elevated", []),
    ("yarmouk", "اليرموك", "Yarmouk", ["purple"], osm("yarmouk"), "elevated", []),
    ("andalus", "الأندلس", "Andalus", ["purple"], osm("andalus"), "elevated", []),
    ("khurais", "طريق خريص", "Khurais Road", ["purple"], osm("khurais"), "elevated", []),
    ("as_salam", "السلام", "As Salam", ["purple"], osm("as_salam"), "elevated", []),
]

LINE_ORDER = {
    "blue": [
        "sabb", "dr_sulaiman_al_habib", "kafd", "al_muruj", "king_fahd_district",
        "king_fahd_district_2", "stc", "al_wurud_2", "al_urubah", "alinma",
        "bank_albilad", "king_fahd_library", "moi", "al_murabba", "jawazat",
        "national_museum", "al_batha", "qasr_al_hokm", "al_oud", "skirinah",
        "manfouhah", "iman_hospital", "public_transport_center", "al_aziziyah",
        "ad_dar_al_baida",
    ],
    "red": [
        "king_saud_university", "king_salman_oasis", "technology_city", "takhassusi",
        "stc", "al_wurud_1", "king_abdulaziz_road", "ministry_of_education",
        "an_nuzhah", "riyadh_exhibition_center", "khalid_bin_al_waleed", "al_hamra",
        "al_khaleej", "ishbiliyah", "king_fahd_sports_city",
    ],
    "orange": [
        "jeddah_road", "tuwaiq", "ad_douh", "western", "aisha_bint_abi_bakr",
        "dhahrat_al_badiah", "sultanah", "al_juradiyah", "courts_complex",
        "qasr_al_hokm", "al_halah", "al_marqab", "as_salhiyah", "first_industrial_city",
        "railway", "al_malaz", "jarir_district", "al_rajhi_grand_mosque",
        "harun_al_rashid", "an_naseem", "hassan_bin_thabit", "khashm_al_an",
    ],
    "yellow": [
        "kafd", "ar_rabi", "uthman_bin_affan", "sabic", "pnu_1", "pnu_2",
        "airport_t5", "airport_t34", "airport_t12",
    ],
    "green": [
        "ministry_of_education", "king_salman_park", "as_sulimaniyah", "ad_dhabab",
        "abu_dhabi_square", "officers_club", "gosi", "ministries",
        "ministry_of_defense", "king_abdulaziz_hospital", "ministry_of_finance",
        "national_museum",
    ],
    "purple": [
        "kafd", "ar_rabi", "uthman_bin_affan", "sabic", "granada", "yarmouk",
        "al_hamra", "andalus", "khurais", "as_salam", "an_naseem",
    ],
}


def main():
    stations = []
    for sid, ar, en, lines, coord, stype, facilities in STATIONS:
        lat, lon, source = coord
        stations.append({
            "id": sid,
            "nameAr": ar,
            "nameEn": en,
            "lineIds": lines,
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "stationType": stype,
            "facilities": facilities,
            "hasVerifiedExits": False,
            "hasVerifiedIndoorPlaces": sid in {"stc", "kafd", "qasr_al_hokm"},
            "heroImageURL": None,
            "coordinateSource": source,
            "updatedAt": "2026-09-01T00:00:00Z",
        })

    ids = {s["id"] for s in stations}
    for line_id, order in LINE_ORDER.items():
        missing = [x for x in order if x not in ids]
        extra = []
        if missing:
            raise SystemExit(f"missing stations for {line_id}: {missing}")

    catalog = {
        "attribution": {
            "stationNames": "Public Riyadh Metro line lists (RCRC / published network descriptions).",
            "coordinates": "OpenStreetMap contributors where a matching station node exists. Remaining stations use approximate public interpolation along the published alignment and are flagged coordinateSource=approximatePublic.",
            "schematic": "Original Nazlah schematic derived from station order and interchange topology. Not a reproduction of Darb or official Qitar Al-Riyadh artwork.",
            "exits": "No official exit numbers are included until a station has verified StationExit records.",
        },
        "lines": [
            {**line, "stationIds": LINE_ORDER[line["id"]]}
            for line in LINES
        ],
        "stations": stations,
        "exits": [],
    }
    out = Path(__file__).resolve().parents[1] / "Nazlah" / "Resources" / "SampleData" / "metro_catalog.json"
    out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {out} stations={len(stations)} lines={len(LINES)}")


if __name__ == "__main__":
    main()
