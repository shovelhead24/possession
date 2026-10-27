# Regional satellite imagery — 2026-10-24

Performance Demo attaches `performance_satellite.gd` after the water palette shader adaptation. It restores use of the existing native regional satellite images on the backdrop; it does not change terrain geometry, collision, water elevations or source assets.

The active region is selected using the existing backdrop patch ownership function and origin-independent ring coordinates. One active regional image is retained. The existing home satellite loader now accepts an optional source path, sharing its versioned on-disk cache, S3TC compression and mipmap generation. Decode/compression happens on a worker; GPU creation happens on the main thread. Obsolete worker results are discarded, missing imagery retains the preview, and the worker is joined on exit.

The shader uses the existing patch UV and substitutes the regional imagery before tint, coastal water recolouring, lighting and haze. Full detail applies within 4 km of the view in ring coordinates and blends to the 512-pixel array from 4–8 km. Texture mipmaps and anisotropic filtering select appropriate samples. The source images are 8192 square; compressed image plus mipmaps is approximately 43 MiB. Loading can temporarily require additional CPU memory and the previous image remains resident until replacement.

Validation harness: `profile_performance_weather.gd --regional-satellite-review`, with all four isolated save overrides. It locates ground at arc 209013.6, lateral 9962.4, verifies on-foot support and saved-start reapplication, captures preview/full-resolution comparisons, and checks coordinates across an origin shift. The spawn sidecar is copied into the player's layout only after verification, with its previous value backed up.
