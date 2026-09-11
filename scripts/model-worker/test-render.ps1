$ErrorActionPreference='Stop'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'worker.ps1'),[ref]$tokens,[ref]$errors)
foreach ($function in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Quote-Arg','Run-Child')}, $false)) { Invoke-Expression $function.Extent.Text }
$runtime=Join-Path $env:TEMP ('possession-render-test-'+[guid]::NewGuid())
New-Item -ItemType Directory $runtime | Out-Null
$config=[pscustomobject]@{checkout=$runtime}
$fixture=@'
import bpy
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_cube_add()
material=bpy.data.materials.new('TestMaterial')
material.diffuse_color=(0.25,0.4,0.2,1)
bpy.context.object.data.materials.append(material)
bpy.ops.export_scene.gltf(filepath=str(Path.cwd()/'model.glb'),export_format='GLB')
'@
[IO.File]::WriteAllText((Join-Path $runtime 'fixture.py'),$fixture)
$blender='C:\Program Files\Blender Foundation\Blender 4.4\blender.exe'
$build=Run-Child $blender @('--background','--factory-startup','--python-exit-code','1','--python',(Join-Path $runtime 'fixture.py')) 'fixture' '' 3
if ($build.code -ne 0) { throw $build.output }
$render=Run-Child $blender @('--background','--factory-startup','--python-exit-code','1','--python',(Join-Path $PSScriptRoot 'validate_model.py'),'--',$runtime,'weapons') 'render' '' 5
if ($render.code -ne 0 -or $render.output -notmatch 'MODEL_VALIDATION_PASSED') { throw $render.output }
Copy-Item (Join-Path $PSScriptRoot 'project.godot') $runtime
$import=Run-Child 'C:\Godot\Godot_v4.5.1-stable_win64.exe' @('--headless','--path',$runtime,'--editor','--import') 'import' '' 3
if ($import.code -ne 0 -or $import.output -match '(?m)^(SCRIPT ERROR|ERROR):') { throw $import.output }
Write-Output "PASS: real Blender GLB export, independent geometry validation, two CPU renders, Godot import. Evidence: $runtime"
