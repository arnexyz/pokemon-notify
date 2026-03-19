#!/usr/bin/env python3
"""Download Pokemon names and type data from PokeAPI."""
import json
import os
import urllib.request

app_dir = os.path.expanduser("~/.claude/Pokemon Notify.app")
resources_dir = os.path.join(app_dir, "Contents/Resources")

headers = {"User-Agent": "Mozilla/5.0"}

# Download names
print("Downloading Pokemon names...")
req = urllib.request.Request("https://pokeapi.co/api/v2/pokemon?limit=649", headers=headers)
data = json.loads(urllib.request.urlopen(req).read())
names = {}
for p in data["results"]:
    pid = p["url"].rstrip("/").split("/")[-1]
    names[pid] = p["name"].capitalize()

with open(os.path.join(resources_dir, "pokemon_names.json"), "w") as f:
    json.dump(names, f)
print(f"Saved {len(names)} Pokemon names")

# Download types
print("Downloading Pokemon types (this takes a minute)...")
types = {}
for i, p in enumerate(data["results"]):
    pid = p["url"].rstrip("/").split("/")[-1]
    req2 = urllib.request.Request(p["url"], headers=headers)
    pdata = json.loads(urllib.request.urlopen(req2).read())
    types[pid] = [t["type"]["name"] for t in pdata["types"]]
    if (i + 1) % 50 == 0:
        print(f"  {i + 1}/649...")

with open(os.path.join(resources_dir, "pokemon_types.json"), "w") as f:
    json.dump(types, f)
print(f"Saved types for {len(types)} Pokemon")
