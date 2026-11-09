#!/usr/bin/env python3
"""Load OSM places collected around official exits into the app catalog.

Does not rematch exits. Maps each unique place to the catalog station by name
and keeps the shortest walking relationship (best exit).
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "Nazlah/Resources/SampleData/metro_catalog.json"
PLACES = ROOT / "Nazlah/Resources/SampleData/places.json"
FLUTTER_PLACES = ROOT / "nazlah_flutter/assets/data/places.json"
ROUTED = ROOT / "data/metro_nearby_places_routed.json"


def category_for(rel: dict) -> str:
    sub = (rel.get("subcategory") or "").lower()
    cat = (rel.get("category") or "").lower()
    if sub == "cafe":
        return "cafe"
    if sub in {"restaurant", "fast_food"}:
        return "restaurant"
    if cat == "food":
        return "restaurant"
    if cat == "fitness" or sub in {"gym", "fitness_centre", "sports_centre", "fitness_station"}:
        return "gym"
    if sub == "pharmacy":
        return "pharmacy"
    return "other"


def place_names(rel: dict) -> tuple[str, str]:
    tags = rel.get("osm_tags") or {}
    ar = (
        rel.get("place_name_ar")
        or tags.get("name:ar")
        or tags.get("name")
        or rel.get("place_name")
        or ""
    ).strip()
    en = (
        rel.get("place_name_en")
        or tags.get("name:en")
        or tags.get("name")
        or rel.get("place_name")
        or ""
    ).strip()
    return ar, en


def is_unnamed(ar: str, en: str) -> bool:
    blob = f"{ar} {en}".lower()
    return not ar or not en or "unnamed" in blob or ar == "(unnamed OSM place)"


def osm_id_token(place_osm_id: str) -> str:
    return place_osm_id.replace("/", "-")


def maps_url(name: str, lat: float, lon: float) -> str:
    return f"https://www.google.com/maps/search/?api=1&query={quote(f'{name} {lat},{lon}')}"


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    places_doc = json.loads(PLACES.read_text())
    routed = json.loads(ROUTED.read_text())

    by_en = {s["nameEn"].strip().lower(): s for s in catalog["stations"]}
    by_ar = {s["nameAr"].strip(): s for s in catalog["stations"]}
    exits_by_key = {(e["stationId"], str(e["exitNumber"])): e for e in catalog["exits"]}

    editorial = [p for p in places_doc["places"] if not str(p.get("id", "")).startswith("osm-")]
    occupied = {(p["stationId"], p["nameAr"].strip(), p["nameEn"].strip().lower()) for p in editorial}

    best: dict[str, dict] = {}
    skipped_unnamed = 0
    skipped_station = 0
    for rel in routed["places"]:
        if rel.get("routing_status") != "ok":
            continue
        ar, en = place_names(rel)
        if is_unnamed(ar, en):
            skipped_unnamed += 1
            continue
        station = by_en.get((rel.get("station_name_en") or "").strip().lower()) or by_ar.get(
            (rel.get("station_name_ar") or "").strip()
        )
        if station is None:
            skipped_station += 1
            continue
        osm_id = rel["place_osm_id"]
        minutes = float(rel.get("walking_duration_minutes") or 10**9)
        current = best.get(osm_id)
        if current is None or minutes < current["_minutes"]:
            best[osm_id] = {**rel, "_station": station, "_ar": ar, "_en": en, "_minutes": minutes}

    now = datetime(2026, 10, 20, tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    added = []
    for osm_id, rel in sorted(best.items(), key=lambda item: item[1]["_minutes"]):
        station = rel["_station"]
        ar, en = rel["_ar"], rel["_en"]
        key = (station["id"], ar, en.lower())
        if key in occupied:
            continue
        exit_number = rel.get("exit_number")
        exit_rec = exits_by_key.get((station["id"], str(exit_number))) if exit_number else None
        walk_m = int(round(float(rel.get("walking_distance_meters") or 0)))
        walk_min = max(1, int(round(float(rel["_minutes"]))))
        exit_label_ar = f"مخرج {exit_number}" if exit_number else "أقرب مخرج"
        exit_label_en = f"Exit {exit_number}" if exit_number else "the nearest exit"
        pid = f"osm-{osm_id_token(osm_id)}"
        added.append(
            {
                "id": pid,
                "googlePlaceId": None,
                "nameAr": ar,
                "nameEn": en,
                "latitude": round(float(rel["latitude"]), 7),
                "longitude": round(float(rel["longitude"]), 7),
                "category": category_for(rel),
                "stationId": station["id"],
                "stationRelation": "nearby",
                "floor": None,
                "ticketGatePosition": None,
                "nearestExitId": exit_rec["id"] if exit_rec else None,
                "editorialTags": ["worthTheStop"] if rel["_minutes"] <= 5 else [],
                "verificationStatus": "verified",
                "source": "openStreetMap",
                "priceLevel": None,
                "rating": None,
                "reviewCount": None,
                "isOpenNow": None,
                "shortDescriptionAr": f"من {exit_label_ar} في {station['nameAr']}، حوالي {walk_min} دقائق مشي ({walk_m} م).",
                "shortDescriptionEn": f"From {exit_label_en} at {station['nameEn']}, about {walk_min} min walk ({walk_m} m).",
                "neighborhoodAr": station["nameAr"],
                "neighborhoodEn": station["nameEn"],
                "sourceURL": f"https://www.openstreetmap.org/{osm_id}",
                "mapsURL": maps_url(ar, float(rel["latitude"]), float(rel["longitude"])),
                "updatedAt": now,
            }
        )
        occupied.add(key)

    places_doc["places"] = editorial + added
    places_doc["attribution"]["places"] = (
        "Editorial places plus OSM amenities collected around official RCRC/OSM station exits, "
        "with OSRM foot walking from the matched exit. Not a complete business directory."
    )
    payload = json.dumps(places_doc, ensure_ascii=False, indent=2) + "\n"
    PLACES.write_text(payload)
    FLUTTER_PLACES.write_text(payload)

    stations_with = {p["stationId"] for p in places_doc["places"]}
    print("editorial kept", len(editorial))
    print("exit-osm added", len(added))
    print("total places", len(places_doc["places"]))
    print("stations with places", len(stations_with), "/", len(catalog["stations"]))
    print("skipped unnamed", skipped_unnamed, "skipped unmatched station", skipped_station)
    print("with catalog exit id", sum(1 for p in added if p["nearestExitId"]))


if __name__ == "__main__":
    main()
