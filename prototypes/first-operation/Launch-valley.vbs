Option Explicit
Dim shell, fs, root, godot
Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
root = fs.GetParentFolderName(WScript.ScriptFullName)
godot = "C:\Godot\Godot_v4.5.1-stable_win64.exe"
If Not fs.FileExists(godot) Then
    MsgBox "Godot was not found at " & godot, 48, "FOB study"
    WScript.Quit 1
End If
shell.Run Chr(34) & godot & Chr(34) & " --path " & Chr(34) & root & Chr(34) & " res://tactical.tscn", 1, False
