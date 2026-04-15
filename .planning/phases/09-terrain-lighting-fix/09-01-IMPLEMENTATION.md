# Phase 9.1 Implementation Checklist: Terrain Lighting Fix

## Overview
Implement normal mapping, improve PBR workflow, optimize shadows, and reduce ambient washout for better terrain lighting.

## Phase 9.1: Add Normal Mapping Support

### Task 1: Create/acquire normal map textures
- [ ] Check if normal maps exist for grass, stone, snow, sand
- [ ] If missing, generate normal maps from existing textures
- [ ] Place normal maps in appropriate directories

### Task 2: Add normal map texture uniforms to terrain shader
- [ ] Add uniform sampler2D declarations for normal maps
- [ ] Add normal strength parameters per texture type
- [ ] Update shader to sample normal maps

### Task 3: Implement triplanar normal mapping for cliffs
- [ ] Extend triplanar mapping to include normal maps
- [ ] Implement proper normal blending for triplanar surfaces
- [ ] Adjust normal strength based on slope and texture type

### Task 4: Adjust normal strength parameters
- [ ] Set appropriate normal strengths (grass: 0.5, stone: 1.0, snow: 0.3, sand: 0.4)
- [ ] Test normal mapping at different viewing angles

## Phase 9.2: Improve PBR Lighting

### Task 1: Add specular calculations to shader
- [ ] Add specular intensity parameter
- [ ] Implement specular calculations using normal map
- [ ] Adjust specular based on material type

### Task 2: Adjust ROUGHNESS values
- [ ] Update ROUGHNESS values: snow: 0.7, stone: 0.8, grass: 0.85, sand: 0.9
- [ ] Add ROUGHNESS variation based on texture type

### Task 3: Add METALLIC variation
- [ ] Add METALLIC parameter for wet/icy surfaces
- [ ] Implement METALLIC variation based on height and moisture
- [ ] Test metallic reflections on snow and water edges

### Task 4: Integrate normal mapping with lighting
- [ ] Ensure normal maps affect all lighting calculations
- [ ] Test with directional light at different angles
- [ ] Verify normal mapping works with day/night cycle

## Phase 9.3: Optimize Directional Light & Shadows

### Task 1: Increase directional light energy
- [ ] Update DirectionalLight3D energy in world.tscn
- [ ] Test different energy values (1.2-1.5 range)
- [ ] Ensure energy works with day/night cycle

### Task 2: Adjust shadow parameters
- [ ] Set shadow bias: 0.1
- [ ] Set normal bias: 1.0
- [ ] Set shadow distance: 2000
- [ ] Enable shadow filtering if available

### Task 3: Test shadow quality
- [ ] Test shadows at different times of day
- [ ] Check for "shadow acne" with normal mapping
- [ ] Verify shadow quality vs performance

### Task 4: Ensure shadows work with normal mapping
- [ ] Test shadow casting with normal mapped surfaces
- [ ] Adjust bias if shadow artifacts appear
- [ ] Verify shadows on mountain slopes

## Phase 9.4: Reduce Ambient Washout

### Task 1: Reduce ambient light energy
- [ ] Decrease ambient energy from 0.7 to 0.3-0.4
- [ ] Update Environment settings in world.tscn
- [ ] Test with different ambient colors

### Task 2: Adjust ambient color
- [ ] Update ambient color to complement directional light
- [ ] Ensure ambient works with day/night cycle
- [ ] Test ambient at different times of day

### Task 3: Update day/night cycle ambient settings
- [ ] Modify day_night_cycle.gd ambient color transitions
- [ ] Ensure ambient reduction doesn't make nights too dark
- [ ] Test ambient transitions

## Phase 9.5: Improve Day/Night Transitions

### Task 1: Smooth out lighting transition curves
- [ ] Review and adjust transition curves in day_night_cycle.gd
- [ ] Ensure smooth transitions between day/night lighting states
- [ ] Test transitions at different speeds

### Task 2: Ensure night lighting shows terrain details
- [ ] Test normal mapping visibility at night
- [ ] Adjust night ambient to show surface details
- [ ] Verify specular highlights work at night

### Task 3: Adjust sun visibility checking
- [ ] Test sun visibility function with new lighting
- [ ] Ensure visibility checking doesn't cause flickering
- [ ] Optimize raycast if performance impacted

## Testing Plan

### Visual Testing
- [ ] Test at mountain peak (-1137, 431)
- [ ] Test in valleys and flat areas
- [ ] Test at different times of day
- [ ] Test underwater lighting
- [ ] Test with different weather conditions (if applicable)

### Performance Testing
- [ ] Check FPS impact of normal mapping
- [ ] Test shadow performance
- [ ] Verify memory usage
- [ ] Test on Intel UHD graphics

### Quality Assurance
- [ ] Verify no visual artifacts
- [ ] Check for shadow acne
- [ ] Ensure normal mapping doesn't cause "swimming" effect
- [ ] Verify lighting consistency across chunks

## Success Criteria
- Mountains show clear depth and form with directional lighting
- Normal mapping adds surface detail without performance hit
- Shadows work correctly on terrain slopes
- Day/night transitions are smooth and natural
- Performance remains acceptable on Intel UHD
- No visual artifacts or lighting inconsistencies

## Risk Mitigation
- Create backup of original shader before modifications
- Test each change incrementally
- Have fallback values if normal maps unavailable
- Monitor performance after each major change

## Estimated Time: ~20 minutes per major task, ~2 hours total