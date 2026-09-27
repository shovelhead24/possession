# Rexy debug controls

Available globally in `tactical.tscn`, including while driving and paused.

- **6 / numpad 6:** open or close Rexy controls.
- **P:** pause/resume the simulation. No visible pause button.
- **Hide / Show combat indicators:** button in the 6 panel toggles all enemy
  viewcones, Rexy's bite volume and target diamond together. Works paused;
  does not change enemy sensing or attacks. New spawns inherit the setting.
- **Take control:** third-person Rexy movement with WASD, mouse orbit,
  left click or Space to bite. The normal up/left/right/finisher cycle remains.
- Open 6 again and choose **Release Rexy control** to return to your player
  or vehicle. The original camera/FOV and weapon-overlay state are restored.

Modes: automatic patrol/hunt, patrol only, hunt (hold if no prey), hold position.
Manual takeover suspends AI steering. The camera has distance, height and FOV
sliders, smoothing and an obstacle-avoidance ray.

The asset has one imported animation take. The selector exposes that full take,
its walking excerpt, a planted rest pose, and previews of the four procedural
attacks. Previews are non-damaging and do not consume entries in the attack cycle.
Choose Live behaviour animation to resume gameplay.

Live AI and manual control now share one movement motor: the same 9 m/s speed,
turn response, terrain contact and source-frame 312–413 walk loop. The final
eight frames blend to the matching same-leg pose; the diagnostics retain source
frame numbering. There is no opening emote in normal patrol or chase.
The opening 0–50 frame emote is allowed only after a confirmed Rexy kill,
two seconds with no visible living threats ahead, and a 45-second cooldown.
A surviving tossed target still blocks it. New threats interrupt it.

The always-visible readout shows unpaused simulation time, pause state,
current animation, frame (30-fps animation indexing), behaviour and target.
A green rotating diamond marks the selected/held target in the world.
`user://trex-bite.log` includes the same simulation clock for event correlation.

`test_trex_controls.gd` covers input dispatch, preview selection, pause/resume,
frozen timer/frame/bite, manual movement/bite, target diamond, control return,
and availability/takeover while driving. `--ui-preview` saves a panel screenshot.
# Flight terrain and patrol diagnostics

The combat-indicator toggle also shows colour-coded Rexy patrol circuits and
their current navigation paths. Rexys start near the outer map corners and
converge at the centre; a tested encounter occurred around 2:54 simulation time.

In the 6 menu, scroll down to enable Terrain brush. V enters flying mode;
aim at the ground, Page Up raises and Page Down lowers. Adjust radius and
height per stroke in 6. Ctrl+S or Save terrain to disk saves the edited bake
for the next launch, retaining the original. Fixed foundations are protected.
