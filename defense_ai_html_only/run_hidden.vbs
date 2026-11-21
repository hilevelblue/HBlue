' Runs main.ps1 with no visible window (no cmd/PowerShell popup).
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\main.ps1"""
CreateObject("WScript.Shell").Run cmd, 0, True
