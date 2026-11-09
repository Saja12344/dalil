#!/usr/bin/env python3
"""Merge official RCRC metro stations + line geometries into Nazlah catalog."""

from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "Nazlah/Resources/SampleData/metro_catalog.json"
PLACES = ROOT / "Nazlah/Resources/SampleData/places.json"
RCRC_STATIONS = Path("/tmp/rcrc_stations.json")
RCRC_LINES = Path("/tmp/rcrc_lines.json")

LINE_BY_CODE = {
    "Line1": "blue",
    "Line2": "red",
    "Line3": "orange",
    "Line4": "yellow",
    "Line5": "green",
    "Line6": "purple",
}

OFFICIAL_EN_TO_ID = {
    "SAB": "sabb",
    "Dr Sulaiman Al Habib": "dr_sulaiman_al_habib",
    "KAFD": "kafd",
    "Al Murooj": "al_muruj",
    "King Fahad District": "king_fahd_district",
    "King Fahad District 2": "king_fahd_district_2",
    "stc": "stc",
    "Al Wurud 2": "al_wurud_2",
    "Al Urubah": "al_urubah",
    "Alinma Bank": "alinma",
    "Bank Albilad": "bank_albilad",
    "King Fahad Library": "king_fahd_library",
    "Ministry of Interior": "moi",
    "Al Muorabba": "al_murabba",
    "Passport Department": "jawazat",
    "National Museum": "national_museum",
    "Al Bat'ha": "al_batha",
    "Qasr Al Hokm": "qasr_al_hokm",
    "Al Owd": "al_oud",
    "Skirinah": "skirinah",
    "Manfouhah": "manfouhah",
    "Al Iman Hospital": "iman_hospital",
    "Transportation Center": "public_transport_center",
    "Al Aziziah": "al_aziziyah",
    "Ad Dar Al Baida": "ad_dar_al_baida",
    "King Saud University": "king_saud_university",
    "King Salman Oasis": "king_salman_oasis",
    "KACST": "technology_city",
    "At Takhassussi": "takhassusi",
    "Al Wurud": "al_wurud_1",
    "King Abdulaziz Road": "king_abdulaziz_road",
    "Ministry of Education": "ministry_of_education",
    "An Nuzhah": "an_nuzhah",
    "Riyadh Exhibition Center": "riyadh_exhibition_center",
    "Khalid Bin Alwaleed Road": "khalid_bin_al_waleed",
    "Al Hamra": "al_hamra",
    "Al Khaleej": "al_khaleej",
    "Ishbiliyah": "ishbiliyah",
    "King Fahad Sport City": "king_fahd_sports_city",
    "Jeddah Road": "jeddah_road",
    "Tuwaiq": "tuwaiq",
    "Ad Douh": "ad_douh",
    "Western Station": "western",
    "Aishah bint Abi Bakr Street": "aisha_bint_abi_bakr",
    "Dhahrat Al Badiah": "dhahrat_al_badiah",
    "Sultanah": "sultanah",
    "Al Jarradiyah": "al_juradiyah",
    "Courts Complex": "courts_complex",
    "Al Hilla": "al_halah",
    "Al Margab": "al_marqab",
    "As Salhiyah": "as_salhiyah",
    "First Industrial City": "first_industrial_city",
    "Railway": "railway",
    "Al Malaz": "al_malaz",
    "Jarir District": "jarir_district",
    "Al Rajhi Grand Mosque": "al_rajhi_grand_mosque",
    "Harun Ar Rashid Road": "harun_al_rashid",
    "An Naseem": "an_naseem",
    "Hassan Bin Thabit street": "hassan_bin_thabit",
    "Khashm Al An": "khashm_al_an",
    "Ar Rabi": "ar_rabi",
    "Uthman Bin Affan Road": "uthman_bin_affan",
    "SABIC": "sabic",
    "PNU1": "pnu_1",
    "PNU2": "pnu_2",
    "Airport T5": "airport_t5",
    "Airport T3-4": "airport_t34",
    "Airport T1-2": "airport_t12",
    "Ministry of Finance": "ministry_of_finance",
    "King Abdulaziz Hospital": "king_abdulaziz_hospital",
    "Ministry of Defense": "ministry_of_defense",
    "Al Wizarat": "ministries",
    "GOSI": "gosi",
    "Officers Club": "officers_club",
    "Abu Dhabi square": "abu_dhabi_square",
    "Ad Dhabab": "ad_dhabab",
    "As Sulimaniyah": "as_sulimaniyah",
    "King Salman Park": "king_salman_park",
    "Granadia": "granada",
    "Al Yarmuk": "yarmouk",
    "Al Andalus": "andalus",
    "Khurais Road": "khurais",
    "As Salam": "as_salam",
}

TYPE_MAP = {
    "Elevated": "elevated",
    "Deep Underground": "underground",
    "Shallow Underground": "underground",
    "At Grade": "atGrade",
}


def mean(points: list[tuple[float, float]]) -> tuple[float, float]:
    lat = sum(p[0] for p in points) / len(points)
    lon = sum(p[1] for p in points) / len(points)
    return lat, lon


def rcrc_type(desc: str) -> str:
    return TYPE_MAP.get(desc, "underground")


def main() -> None:
    stations_raw = json.loads(RCRC_STATIONS.read_text())["results"]
    lines_raw = json.loads(RCRC_LINES.read_text())["results"]
    catalog = json.loads(CATALOG.read_text())
    places_doc = json.loads(PLACES.read_text())

    unmatched = []
    by_id: dict[str, dict] = defaultdict(lambda: {"records": [], "line_seq": {}})
    for rec in stations_raw:
        en = rec["metro_station_desc_en"]
        sid = OFFICIAL_EN_TO_ID.get(en)
        if not sid:
            unmatched.append(en)
            continue
        geo = rec["geo_point_2d"]
        line_id = LINE_BY_CODE[rec["metro_line_cd"]]
        by_id[sid]["records"].append(rec)
        by_id[sid]["line_seq"][line_id] = rec["metro_station_seq"]
        by_id[sid]["name_en"] = en
        by_id[sid]["name_ar"] = rec["metro_station_desc_ar"]
        by_id[sid]["points"] = by_id[sid].get("points", []) + [(geo["lat"], geo["lon"])]
        by_id[sid]["types"] = by_id[sid].get("types", []) + [rcrc_type(rec["metro_station_type_desc_en"])]

    if unmatched:
        raise SystemExit(f"Unmapped official stations: {unmatched}")

    catalog_ids = {s["id"] for s in catalog["stations"]}
    missing = catalog_ids - set(by_id)
    extra = set(by_id) - catalog_ids
    if missing or extra:
        raise SystemExit(f"ID mismatch missing={sorted(missing)} extra={sorted(extra)}")

    old_coords = {s["id"]: (s["latitude"], s["longitude"]) for s in catalog["stations"]}
    now = datetime(2026, 10, 2, tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    for station in catalog["stations"]:
        official = by_id[station["id"]]
        lat, lon = mean(official["points"])
        station["latitude"] = round(lat, 7)
        station["longitude"] = round(lon, 7)
        station["nameEn"] = official["name_en"]
        station["nameAr"] = official["name_ar"]
        station["coordinateSource"] = "official"
        station["updatedAt"] = now
        types = official["types"]
        if len(station["lineIds"]) > 1 or station["stationType"] == "interchangeHub":
            station["stationType"] = "interchangeHub"
        else:
            station["stationType"] = types[0]

    line_order: dict[str, list[tuple[int, str]]] = defaultdict(list)
    for sid, info in by_id.items():
        for line_id, seq in info["line_seq"].items():
            line_order[line_id].append((seq, sid))

    color_by_code = {LINE_BY_CODE[r["metro_line_cd"]]: r["metro_line_color_cd"].lstrip("#") for r in lines_raw}
    path_by_code = {}
    for rec in lines_raw:
        lid = LINE_BY_CODE[rec["metro_line_cd"]]
        geom = rec["geoshape"]["geometry"]
        if geom["type"] == "LineString":
            coords = geom["coordinates"]
        elif geom["type"] == "MultiLineString":
            coords = [pt for part in geom["coordinates"] for pt in part]
        else:
            raise SystemExit(f"Unexpected geometry {geom['type']}")
        path_by_code[lid] = [
            {"latitude": round(lat, 7), "longitude": round(lon, 7)} for lon, lat in coords
        ]

    for line in catalog["lines"]:
        ordered = [sid for _, sid in sorted(line_order[line["id"]])]
        if set(ordered) != set(line["stationIds"]):
            raise SystemExit(f"Line {line['id']} station set mismatch {set(ordered) ^ set(line['stationIds'])}")
        line["stationIds"] = ordered
        if line["id"] in color_by_code:
            line["colorHex"] = "#" + color_by_code[line["id"]].upper()
        line["path"] = path_by_code[line["id"]]

    deltas = {
        sid: (new[0] - old[0], new[1] - old[1])
        for sid, old in old_coords.items()
        for new in [(next(s for s in catalog["stations"] if s["id"] == sid)["latitude"],
                     next(s for s in catalog["stations"] if s["id"] == sid)["longitude"])]
    }

    for exit_row in catalog["exits"]:
        dlat, dlon = deltas[exit_row["stationId"]]
        exit_row["latitude"] = round(exit_row["latitude"] + dlat, 7)
        exit_row["longitude"] = round(exit_row["longitude"] + dlon, 7)

    for place in places_doc["places"]:
        sid = place.get("stationId")
        if sid in deltas:
            dlat, dlon = deltas[sid]
            place["latitude"] = round(place["latitude"] + dlat, 7)
            place["longitude"] = round(place["longitude"] + dlon, 7)

    catalog["attribution"] = {
        "stationNames": "Royal Commission for Riyadh City open data: metro-stations-in-riyadh-by-metro-line-and-station-type-2024.",
        "coordinates": "Official RCRC geo_point_2d (2024/2026 station dataset). Interchanges averaged across line records.",
        "schematic": "Official RCRC metro-lines-in-riyadh-2024 LineString geometries rendered on MapKit.",
        "exits": catalog["attribution"]["exits"],
    }

    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    PLACES.write_text(json.dumps(places_doc, ensure_ascii=False, indent=2) + "\n")
    print(f"stations={len(catalog['stations'])} exits={len(catalog['exits'])} places={len(places_doc['places'])}")
    for line in catalog["lines"]:
        print(line["id"], len(line["stationIds"]), "path", len(line["path"]), line["stationIds"][0], "→", line["stationIds"][-1])


if __name__ == "__main__":
    main()
