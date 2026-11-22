#!/usr/bin/env python3
"""Fetch and normalize MA Office of Fishing and Boating Access (OFBA) sites.

Queries the official MassGIS ArcGIS FeatureServer (public, unauthenticated) and
writes a deterministic offline JSON snapshot to ReelRecords/Resources/ma-public-access.json.
"""

from __future__ import annotations

import datetime as dt
import json
import math
import pathlib
import sys
import urllib.parse
import urllib.request

ENDPOINT = (
    "https://services1.arcgis.com/hGdibHYSPO59RG1h/arcgis/rest/services/"
    "Office_of_Fishing_and_Boating_Access_Sites/FeatureServer/0/query"
)
SOURCE_LABEL = "MassGIS / MA Office of Fishing and Boating Access (OFBA)"
OUTPUT_PATH = pathlib.Path(__file__).resolve().parents[1] / "ReelRecords" / "Resources" / "ma-public-access.json"


def clean_str(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() in {"none", "null", "n/a", "na"}:
        return None
    return text


def clean_int(value: object) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        parsed = int(float(str(value).strip()))
    except (TypeError, ValueError):
        return None
    return parsed if parsed > 0 else None


def parse_facility_codes(raw: object) -> list[str]:
    text = clean_str(raw)
    if not text:
        return []
    seen: set[str] = set()
    codes: list[str] = []
    for token in text.replace(";", ",").split(","):
        code = token.strip().upper()
        if code in {"A", "B", "C", "D", "E", "F"} and code not in seen:
            seen.add(code)
            codes.append(code)
    return codes


def fetch_features() -> list[dict]:
    params = urllib.parse.urlencode(
        {
            "where": "1=1",
            "outFields": "*",
            "outSR": "4326",
            "f": "json",
            "resultRecordCount": "2000",
        }
    )
    url = f"{ENDPOINT}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": "ReelRecords/1.0 (MassGIS OFBA snapshot)"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    if "error" in payload:
        raise RuntimeError(f"ArcGIS error: {payload['error']}")
    return payload.get("features", [])


def normalize_feature(feature: dict) -> dict | None:
    attrs = feature.get("attributes") or {}
    geom = feature.get("geometry") or {}

    pending = clean_str(attrs.get("PENDING"))
    if pending and pending.lower() == "yes":
        return None

    lat = geom.get("y")
    lon = geom.get("x")
    if lat is None or lon is None:
        return None
    try:
        lat_f = float(lat)
        lon_f = float(lon)
    except (TypeError, ValueError):
        return None
    if not (math.isfinite(lat_f) and math.isfinite(lon_f)):
        return None
    if not (-90.0 <= lat_f <= 90.0 and -180.0 <= lon_f <= 180.0):
        return None

    ofba_id = clean_str(attrs.get("OFBA_ID"))
    object_id = clean_str(attrs.get("OBJECTID"))
    name = clean_str(attrs.get("FACNAME"))
    if not name or (not ofba_id and not object_id):
        return None

    site_id = f"MA-{ofba_id}" if ofba_id else f"MA-OBJ-{object_id}"
    canonical_ofba_id = ofba_id or f"OBJ-{object_id}"

    facility_raw = attrs.get("FACILITY_TYPE")
    if facility_raw is None:
        facility_raw = attrs.get("FACILITY_T")

    barrier_raw = clean_str(attrs.get("BARRIER_FREE")) or clean_str(attrs.get("BARRIER_FR"))
    barrier_free = bool(barrier_raw and barrier_raw.lower() in {"yes", "y", "true", "1"})

    return {
        "id": site_id,
        "ofbaId": canonical_ofba_id,
        "name": name,
        "town": clean_str(attrs.get("TOWN")),
        "state": "MA",
        "facilityTypeCodes": parse_facility_codes(facility_raw),
        "rampType": clean_str(attrs.get("RAMPTYPE")),
        "parking": clean_str(attrs.get("PARKING")),
        "lanes": clean_int(attrs.get("NOLANES")),
        "fee": clean_str(attrs.get("FEE")),
        "restricted": clean_str(attrs.get("RESTRICTED")),
        "barrierFree": barrier_free,
        "comments": clean_str(attrs.get("COMMENTS")),
        "maintainer": clean_str(attrs.get("MAINTRESP")),
        "latitude": round(lat_f, 6),
        "longitude": round(lon_f, 6),
    }


def main() -> int:
    features = fetch_features()
    sites = [site for f in features if (site := normalize_feature(f)) is not None]
    sites.sort(key=lambda s: (s["id"], s["name"]))

    seen_ids: set[str] = set()
    duplicates: list[str] = []
    for site in sites:
        if site["id"] in seen_ids:
            duplicates.append(site["id"])
        seen_ids.add(site["id"])
    if duplicates:
        raise ValueError(f"Duplicate access site IDs detected: {sorted(set(duplicates))}")

    snapshot = {
        "source": SOURCE_LABEL,
        "state": "MA",
        "fetchedAt": dt.date.today().isoformat(),
        "sites": sites,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(snapshot, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    size_kb = OUTPUT_PATH.stat().st_size / 1024
    print(f"Wrote {len(sites)} sites to {OUTPUT_PATH} ({size_kb:.1f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
