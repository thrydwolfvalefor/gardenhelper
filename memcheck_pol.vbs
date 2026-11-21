' Written by GardenHelper memcheck.lua (//gh memory): writes pol.exe memory to data\pol_memory.txt.
On Error Resume Next
Dim fso, dir, wmi, p, f, parentPid, line
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName) & "\data\"
parentPid = -1
Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
For Each p In wmi.ExecQuery("SELECT ParentProcessId, CommandLine FROM Win32_Process WHERE Name = 'wscript.exe'")
  If Not IsNull(p.CommandLine) Then
    If InStr(1, p.CommandLine, WScript.ScriptName, 1) > 0 Then parentPid = p.ParentProcessId
  End If
Next
Set f = fso.CreateTextFile(dir & "pol_memory.tmp", True)
For Each p In wmi.ExecQuery("SELECT ProcessId, PrivatePageCount, WorkingSetSize, VirtualSize FROM Win32_Process WHERE Name = 'pol.exe'")
  line = p.ProcessId & " " & p.PrivatePageCount & " " & p.WorkingSetSize & " " & p.VirtualSize
  If p.ProcessId = parentPid Then
    line = line & " self"
  Else
    line = line & " other"
  End If
  f.WriteLine line
Next
If Err.Number <> 0 Then f.WriteLine "error " & Err.Description
f.WriteLine "end"
f.Close
If fso.FileExists(dir & "pol_memory.txt") Then fso.DeleteFile dir & "pol_memory.txt", True
fso.MoveFile dir & "pol_memory.tmp", dir & "pol_memory.txt"
