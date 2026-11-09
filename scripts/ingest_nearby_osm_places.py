#!/usr/bin/env python3
"""Attach real nearby OSM places to official RCRC station coordinates."""

from __future__ import annotations

import json
import math
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "Nazlah/Resources/SampleData/metro_catalog.json"
PLACES = ROOT / "Nazlah/Resources/SampleData/places.json"

OVERPASS = "https://overpass-api.de/api/interpreter"
QUERY = r"""
[out:json][timeout:90];
(
  node["name"]["amenity"~"^(cafe|restaurant|fast_food|ice_cream|bakery)$"](24.55,46.54,24.97,46.86);
  node["name"]["shop"~"^(bakery|coffee|convenience|pastry)$"](24.55,46.54,24.97,46.86);
  node["name"]["leisure"="park"](24.55,46.54,24.97,46.86);
  node["name"]["tourism"~"^(attraction|viewpoint)$"](24.55,46.54,24.97,46.86);
);
out body;
"""

MAX_WALK_M = 700
PER_STATION = 6


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def category_for(tags: dict) -> str:
    amenity = tags.get("amenity", "")
    shop = tags.get("shop", "")
    leisure = tags.get("leisure", "")
    tourism = tags.get("tourism", "")
    if amenity in {"cafe"} or shop in {"coffee"}:
        return "cafe"
    if amenity in {"restaurant", "fast_food"}:
        return "restaurant"
    if amenity in {"ice_cream", "bakery"} or shop in {"bakery", "pastry"}:
        return "dessert"
    if leisure == "park":
        return "park"
    if tourism == "viewpoint":
        return "viewpoint"
    if tourism == "attraction":
        return "other"
    if shop == "convenience":
        return "other"
    return "other"


def maps_url(name: str, lat: float, lon: float) -> str:
    from urllib.parse import quote
    q = quote(f"{name} {lat},{lon}")
    return f"https://www.google.com/maps/search/?api=1&query={q}"


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    places_doc = json.loads(PLACES.read_text())
    stations = catalog["stations"]
    existing = places_doc["places"]
    existing_ids = {p["id"] for p in existing}
    occupied = {(p["stationId"], p["nameAr"].strip(), p["nameEn"].strip().lower()) for p in existing}

    req = urllib.request.Request(
        OVERPASS,
        data=QUERY.encode("utf-8"),
        headers={"User-Agent": "Nazlah/1.0 (metro nearby ingest)", "Content-Type": "text/plain"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    elements = payload.get("elements", [])
    print("osm nodes", len(elements))

    buckets: dict[str, list[tuple[float, dict]]] = {s["id"]: [] for s in stations}
    station_by_id = {s["id"]: s for s in stations}

    for el in elements:
        tags = el.get("tags") or {}
        name_en = (tags.get("name:en") or tags.get("name") or "").strip()
        name_ar = (tags.get("name:ar") or tags.get("name") or "").strip()
        if not name_en or not name_ar:
            continue
        lat, lon = float(el["lat"]), float(el["lon"])
        nearest = None
        best = 10_000.0
        for station in stations:
            d = haversine(lat, lon, station["latitude"], station["longitude"])
            if d < best:
                best = d
                nearest = station
        if nearest is None or best > MAX_WALK_M:
            continue
        buckets[nearest["id"]].append((best, el))

    now = datetime(2026, 10, 2, tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    added = []
    for sid, items in buckets.items():
        items.sort(key=lambda x: x[0])
        kept = 0
        station = station_by_id[sid]
        for dist, el in items:
            if kept >= PER_STATION:
                break
            tags = el.get("tags") or {}
            name_en = (tags.get("name:en") or tags.get("name") or "").strip()
            name_ar = (tags.get("name:ar") or tags.get("name") or "").strip()
            key = (sid, name_ar, name_en.lower())
            if key in occupied:
                continue
            pid = f"osm-{el['id']}"
            if pid in existing_ids:
                continue
            cat = category_for(tags)
            cuisine = tags.get("cuisine", "")
            desc_ar = f"مكان حقيقي على بعد {int(dist)} م من محطة {station['nameAr']}."
            desc_en = f"Mapped place {int(dist)} m from {station['nameEn']} station."
            if cuisine:
                desc_en += f" Cuisine: {cuisine}."
            place = {
                "id": pid,
                "googlePlaceId": None,
                "nameAr": name_ar,
                "nameEn": name_en,
                "latitude": round(float(el["lat"]), 7),
                "longitude": round(float(el["lon"]), 7),
                "category": cat,
                "stationId": sid,
                "stationRelation": "nearby",
                "floor": None,
                "ticketGatePosition": None,
                "nearestExitId": None,
                "editorialTags": ["worthTheStop"] if dist <= 180 else [],
                "verificationStatus": "verified",
                "source": "openStreetMap",
                "priceLevel": None,
                "rating": None,
                "reviewCount": None,
                "isOpenNow": None,
                "shortDescriptionAr": desc_ar,
                "shortDescriptionEn": desc_en,
                "neighborhoodAr": station["nameAr"],
                "neighborhoodEn": station["nameEn"],
                "sourceURL": f"https://www.openstreetmap.org/node/{el['id']}",
                "mapsURL": maps_url(name_ar, float(el["lat"]), float(el["lon"])),
                "updatedAt": now,
            }
            existing.append(place)
            existing_ids.add(pid)
            occupied.add(key)
            added.append((sid, name_ar, int(dist)))
            kept += 1

    places_doc["places"] = existing
    places_doc["attribution"]["places"] = (
        "Editorial/TikTok field places plus OpenStreetMap amenities within 700 m of official RCRC station coordinates. "
        "mapsURL opens Google Maps search for the real coordinates."
    )
    PLACES.write_text(json.dumps(places_doc, ensure_ascii=False, indent=2) + "\n")

    dhabab = [x for x in added if x[0] == "ad_dhabab"]
    print("added", len(added), "ad_dhabab", dhabab)
    by_station = {}
    for sid, _, _ in added:
        by_station[sid] = by_station.get(sid, 0) + 1
    empty = [s["id"] for s in stations if by_station.get(s["id"], 0) == 0 and not any(p["stationId"] == s["id"] for p in existing if not str(p["id"]).startswith("osm-"))]
    print("stations still without any places", len(empty), empty[:12])


if __name__ == "__main__":
    main()
