# Low-poly tanks

Tank.glb and Light Tank.glb are unchanged user-supplied files from Downloads/Low Poly Military Vehicles-glb (18 October 2026). Source license/author metadata was not supplied; retain accompanying attribution if provided.

Performance Demo uses Tank-articulated.glb, derived from Tank.glb by split_tank_glb.py. The generator preserves complete triangles, material assignments, normals and UVs; verify_tank_split.py independently compares all 2,796 triangles. Source geometry is split into hull, turret, barrel and fourteen wheels. Reviewed overrides keep headlights on the hull and roof/rear stowage/antennas on the turret. The report records each component.

Gameplay rig: world/performance_tank.gd and performance_tank_factory.gd. Eight original suspension contacts and existing cannon behavior are retained. Road wheels animate; the smooth continuous tread bands remain static. Other demo scenes keep Altay. Light Tank.glb (3,088 triangles) remains an unused alternative.
