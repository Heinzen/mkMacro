Update(workingVersion) { 
	endpoint := "https://api.github.com/gists/141c490b1b32ba8fe265f2822d88bafc"
	api := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	api.Open("GET", Endpoint, False)
	api.Send()
	response := api.ResponseText
	latestVersion := Json_ToObj(Response).files.mkmacro_version.content
	
	if(IsNewVersionAvailable(workingVersion, latestVersion)) {
		MsgBox, 4, ,Upload available. Download and run?
		IfMsgBox, No
			Return  ; User pressed the "No" button.
		IfMsgBox, Yes
			DownloadUpdate(latestVersion)
	}
	DownloadPingMsg(latestVersion)
}

DownloadUpdate(v) {
	downloadURL := "https://github.com/Heinzen/mkMacro/releases/download/" . v . "/mkMacro.exe"
	RenameSelf()
	
	UrlDownloadToFile, %downloadURL%, %A_WorkingDir%\mkMacro.exe
	DeleteSelf()
	Run, %A_ScriptName%
	ExitApp
}

RenameSelf() {
	FileMove, %A_ScriptName%, mkMacro_old.exe
}

DownloadPingMsg(v) {
	if FileExist(A_WorkingDir . "\PingMsg.exe")
		FileDelete, %A_WorkingDir%\PingMsg.exe

	downloadURL := "https://github.com/Heinzen/mkMacro/releases/download/" . v . "/PingMsg.exe"
	UrlDownloadToFile, %downloadURL%, %A_WorkingDir%\PingMsg.exe
	
	
}


;This is used because binaries cannot delete themselves -- find better solution
DeleteSelf() {
FileSetAttrib, -R-A-S-H-N-O-T, %A_ScriptFullPath%
FileDelete, %A_Temp%\selfDelete.VBS
FileAppend,
(
Wscript.Sleep 2000
Dim fso, MyFile
Set fso = CreateObject("Scripting.FileSystemObject")
Set MyFile = fso.GetFile("%A_ScriptDir%\mkMacro_old.exe")
MyFile.Delete

'Delete the currently executing script
Dim objFSO    'Create a File System Object
Set objFSO = CreateObject("Scripting.FileSystemObject")
objFSO.DeleteFile WScript.ScriptFullName
Set objFSO = Nothing
)
, %A_Temp%\selfDelete.VBS

Run, %A_Temp%\selfDelete.VBS
}

IsNewVersionAvailable(working, latest){
	working := RegExReplace(working, "\D")
	latest := RegExReplace(latest, "\D")
	
	latest > working ? r := true : r:= false
	return r
}