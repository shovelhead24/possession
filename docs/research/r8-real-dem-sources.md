# R8 — Real-World Terrain Data Sources (2026-07-22)

**Question:** can real map data (height + texture) be sampled directly for splicing into L0, and from where?

**Verified live (no auth, from this machine, 2026-07-22):**
- **Terrarium elevation tiles** — `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png`, 256² RGB PNGs, elevation = `(R·256 + G + B/256) − 32768`. Test tile 11/1072/723 (Alps) decoded to 1,061–3,158 m — correct. Easiest scripted bulk source.
- **Copernicus GLO-30** — `copernicus-dem-30m` S3 bucket, 30 m global GeoTIFF COGs, HTTP 200 with no auth. Higher quality than SRTM; license: free incl. commercial, one attribution line.

**Login-gated (usable if ever needed):** SRTM (NASA Earthdata; public domain), ALOS AW3D30 (JAXA). **US-only bonus:** USGS 3DEP lidar to 1 m, public domain, open on AWS — hero-area candidate.

**Texture/imagery:** Sentinel-2 (10 m, free + attribution, Earth Search STAC API on AWS) as reference/masks; NAIP (US, public domain). **Google/Bing imagery is not licensed for game extraction — never.** Note: at our bake resolutions, real heightforms matter far more than real imagery — biome-driven texturing over real relief beats stretched satellite photos; treat imagery as masks/reference, not shipped textures.

**Pipeline fit:** DEM splicing is an *input option to L0*, not a new system — spliced patches composite with noise/intent, L1 erosion welds the seams, downstream layers are agnostic. Registered as `splice_dem` source patches in layerbuf-v0.md L0 params.

**Diegetic bonus:** the Earth-zoo canon (lore.md) means real Earth terrain is *lore-consistent, not a shortcut* — the builders sampled Earth. The Alps section on the ring can literally be the Alps.

**Licensing rule for the shipped game:** public domain (SRTM/USGS) and attribution-OK (Copernicus/Sentinel) sources only; attribution lines collected in credits at bake time (the recipe knows which tiles it used — provenance is automatic).
