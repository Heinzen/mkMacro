;Assume MIT Licensing

;Author: Heinzen/Magiruu
;AppFactory author: evilC (Modified by Heinzen)
;GifPlayer author: A_Samurai (Modified by Heinzen)

;	---TODOS---
; 1) Implement delay between skills - done
; 2) Improve GUI performance
; 3) Kill switch

; New 1) Try to block new inputs whenever one is triggered already

#SingleInstance, Force
#Include %A_ScriptDir%\Import\AppFactory.ahk
#Include %A_ScriptDir%\Import\GifPlayer.ahk
#Include %A_ScriptDir%\Import\Updater.ahk
#Include %A_ScriptDir%\Import\Json_ToObj.ahk

Gui +LastFound

;	Start-up
;	-------------
If(!A_IsAdmin)
	RunAsAdmin()

RunAsAdmin() {
	Global 0
	IfEqual, A_IsAdmin, 1, Return 0
	Loop, %0%
		params .= A_Space . %A_Index%
	DllCall("shell32\ShellExecute" (A_IsUnicode ? "":"A"),uint,0,str,"RunAs",str,(A_IsCompiled ? A_ScriptFullPath
	: A_AhkPath),str,(A_IsCompiled ? "": """" . A_ScriptFullPath . """" . A_Space) params,str,A_WorkingDir,int,1)
	ExitApp
}

;	Updater
;	-------
workingVersion := "v0.6"
Update(workingVersion)


;Shell hooks for an optimal way to disable the overlay if BNS or AHK loses focus.
;Using a SetTimer drastically reduces performance as well as interrupts current 
;rotation
hWnd := WinExist(), DllCall( "RegisterShellHookWindow", UInt,hWnd )
MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
OnMessage( MsgNum, "ShellMessage" )

ShellMessage( wParam,lParam ) {
	if(wParam = 0x8004)
		CheckActiveWindow()
}

;	Context Variables
; 	-----------------
global t_Overlay := 0
global t_Hold := 0
global t_Delay := 0
global t_RotationBox := 0
global t_DelayBox := 0
global t_ConfirmButton := 0
global t_Hook := 0
global t_hotkey :=
global t_AnicancelSkill
global t_Anicancel
global t_GameRegion
global t_AutoBias
global rotation :=
global toggle := 0
global _overlayX := 855
global _overlayY := 550
global bns_class := "ahk_class LaunchUnrealUWindowsClient"
global script_class := "ahk_class AutoHotkeyGUI" 
global transparency := EEAA99
global ActiveOverlay := "o_Still"
global move_Tooltip := 0
global still_Style := ""
global spin_Style := ""
global default_gdc := 25
global estimated_gcd :=
global ping := 0
global Europe_IP := "18.194.180.254"
global NorthAmerica_IP := "64.25.37.235"

;Change this to byte64
;Temp solution since I have other issues to solve first
global gif_Spinner := A_ScriptDir "\Resources\spinner.gif"
global still_Spinner := A_ScriptDir "\Resources\still.png"

if(!FileExist(still_Spinner) or !FileExist(gif_Spinner)) {
	resourcePath := A_ScriptDir "\Resources"
	If(!FileExist(resourcePath))
		FileCreateDir, Resources
	FileInstall, spinner.gif, %gif_Spinner%, 1
	FileInstall, still.png, %still_Spinner%, 1
}
	
;	GUI Design
;	----------
;	The reason to use AppFactory is to make all settings persistent
;	as well as for the functionality of capturing the extra keybinds
;	that are not supported natively
factory := new AppFactory()

GUI,Add,GroupBox,x299 y15 w140 h180,Settings
	GUI,Add,Text,x312 y35 w70 h13,Delay (in ms)
	factory.AddControl("DelayBox", "Edit", "x313 y50 w40 h21 vt_DelayBox", "0", Func("SubmitAll"))
	GUI,Add,Text,x312 y75 w120 h13,Rotation (";" separated)
	factory.AddControl("RotationBox", "Edit", "x313 y90 w70 h21 vt_RotationBox", "3;t;f;", Func("SubmitAll"))
	factory.AddInputButton("HK1", "x312 y130 w115 h25", Func("TryRecordHotkey").Bind("Keybind"))
	GUI,Add,Button,x312 y160 w115 gg_ConfirmButton vt_ConfirmButton,Save

GUI,Add,GroupBox,x157 y15 w140 h180,Animation Canceler
	GUI,Add,Text,x169 y35 w120 h13,Game region
	factory.AddControl("RegionPicker", "ComboBox", "x169 y50 w120 vt_GameRegion", "North America|Europe", "Game Region", Func("SubmitAll"))
	GUI,Add,Text,x169 y75 w120 h13,Skill to cancel
	factory.AddControl("AniCancelSkill", "Edit", "x169 y90 w70 h21 Limit1 vt_AnicancelSkill", "f", Func("SubmitAll"))
	GUI,Add,Text,x169 y115 w120 h13,Auto-bias value
	factory.AddControl("AutoBiasValue", "Edit", "x169 y130 w70 h21 vt_AutoBias", "1.20", Func("SubmitAll"))
	GUI,Add,Text,x169 y155 w120 h13,Estimated GCD: 
	GUI,Add,Text,x250 y155 w30 h13 vtext_GCD,0

GUI,Add,GroupBox,x15 y15 w130 h180,Toggles
	factory.AddControl("Overlay", "CheckBox", "x27 y45 w90 h13 vt_Overlay", "Display Overlay", Func("ToggleOverlay"))
	factory.AddControl("HoldKB", "CheckBox", "x27 y65 w90 h13 vt_Hold", "Attack Toggle", Func("SubmitAll"))
	factory.AddControl("ToggleDelay", "CheckBox", "x27 y85 w90 h13 vt_Delay", "Enable Delay", Func("SubmitAll"))
	factory.AddControl("HookToClient", "CheckBox", "x27 y105 w90 h13 vt_Hook", "Hook to BnS", Func("SubmitAll"))
	factory.AddControl("AniCancel", "CheckBox", "x27, y125, w110, h13 vt_Anicancel", "Animation Canceler", Func("SubmitAll"))

DetectHiddenWindows, On
WinSetTitle, mkMacro
GUI, Submit, NoHide
GUI,Show,w455 h220, mkMacro %workingVersion%

CreateOverlay()
OnMessage(0x2A1,"WM_MOUSEHOVER")
OnMessage(0x201,"WM_LMBDOWN")
OnMessage(0x4a, "Receive_WM_COPYDATA")
	
;The create/destroy problem has been addressed.
;In this case it is still less demanding to have
;two ActiveX elements running than creating/destroying
;these GUI elements
CreateOverlay() {
	try {
		AnimatedGifControl("o_Still", still_Spinner, "x0 y0 w50 h50")
		GUI, o_Still:-Caption +AlwaysOnTop
		GUI, o_Still:+Owner
		GUI, o_Still:Add, GroupBox, x0  y-6 w50 h57
		if(t_Overlay = 0) 
			GUI, o_Still:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate Hide, o_Still
		else
			GUI, o_Still:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate, o_Still
		
		AnimatedGifControl("o_Spin", gif_Spinner, "x0 y0 w50 h50")
		GUI, o_Spin:-Caption +AlwaysOnTop
		GUI, o_Spin:+Owner
		GUI, o_Spin:Add, GroupBox, x0  y-6 w50 h57
		GUI, o_Spin:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate Hide, o_Spin	
		
		WinSet, Transparent, 170, o_Still 	;Do not use TransColor as that 
		WinSet, Transparent, 170, o_Spin	;breaks Windows GUI Draw at this point.
	} catch, what {
		
	}
	return	
}

;Need this so we can move the Overlay without a Tray bar
WM_LMBDOWN()
{
	PostMessage, 0xA1, 2
}

;	GUI Controls
;	------------	
g_ConfirmButton:
	SubmitAll()
	return

SubmitAll() {
	SplitRotation()
	GUI, Submit, NoHide
	SetPingCalculationTimer()
	return
}

SetPingCalculationTimer() {
	if(t_Anicancel = 0) {
		SetTimer, CalculateGCD, Off
		GuiControl,,text_GCD,0
		estimated_gcd := 0
	}
	else
		SetTimer, CalculateGCD, 500
}

CalculateGCD:
	if(t_GameRegion = "North America")
		addr := NorthAmerica_IP
	else
		addr := Europe_IP
	
	SetTimer, CalculateGCD, off
	if A_IsCompiled {
	Run, % A_ScriptDir . "\Import\PingMsg.exe """ . A_ScriptName . """ "
		. addr . " " . A_Index,, Hide, threadID
	}
	else {
		Run, % A_ScriptDir . "\Import\PingMsg.ahk """ . A_ScriptName . """ "
			. addr . " " . A_Index,, Hide, threadID
	}
return

Receive_WM_COPYDATA(wParam, lParam){
    Global
    Critical

    StringAddress := NumGet(lParam + 2*A_PtrSize)
    CopyOfData := StrGet(StringAddress)

    ;hostID|HostName|PingTime|IP
    reply := StrSplit(CopyOfData, "|")

    ;Process reply
    ;Does not update latency if ping timedout
	if (reply[3] != "TIMEOUT")
    {
		;Good Return
        ;Add new ping time to array
        ping := reply[3]
		SetGlobalCooldown()
	}
	else {
		;Is timeout
		GuiControl,,text_GCD,NULL
	}
	
    return true
}

SetGlobalCooldown() {
	if(ping != 0) {
		skilldelay := ping * t_AutoBias
		maxdelay := skilldelay * 1.7
		estimated_gcd := Floor((skilldelay + maxdelay)/2)
		GuiControl,,text_GCD,%estimated_gcd%
	}
	SetTimer, CalculateGCD, 500
}
	
ToggleOverlay(){
	SubmitAll()
	WinGet, still_Style, Style, o_Still
	WinGet, spin_Style, Style, o_Spin
	if(t_Overlay = "1" ) {
		if(activeOverlay = "o_Still" and !(still_Style & 0x10000000))
			GUI, %ActiveOverlay%:show, NoActivate
		else if(activeOverlay = "o_Spin" and !(spin_Style & 0x10000000))
			GUI, %ActiveOverlay%:show, NoActivate
		else
			return
	}
	else {
		GUI, o_Spin:hide
		GUI, o_Still:hide
	}
	return
}

CheckActiveWindow() {
	if(!(WinActive(bns_class) or WinActive(script_class)) and t_Overlay = "1") {
		GUI, o_Spin:hide
		GUI, o_Still:hide
	}
	else if(WinActive(bns_class) or WinActive(script_class))
		ToggleOverlay()
	return
}		

SplitRotation() {
	if(t_RotationBox != "")
		rotation := StrSplit(t_RotationBox, ";")
	return
}

TryRecordHotkey(ctrl, state) {
	if(t_Hotkey = "")
	{
		Gui, Submit, NoHide
		temp := StrSplit(A_ThisHotkey, "~")
		t_Hotkey := temp[2]
	}
	TriggerAction(ctrl, state)
}
	
TriggerAction(ctrl, state) {
	if(t_Hook = 1 and !WinActive(bns_class))
		return
	if(t_Hold = 1)
		ChangeToggleState()
	if(t_Overlay = 1)
		UpdateSpinner()
	if(t_Rotation != rotation)
		SplitRotation()
	if(t_AniCancel = 0)
		FireRotation()
	else
		FireAniCancelledRotation()
		
}	

ChangeToggleState() {
	if(t_Hold = 1 and GetKeyState(t_hotkey, "P") = 1)
		toggle := !toggle
}

UpdateSpinner() {
	WinGetPos, x, y,,,%ActiveOverlay%
	if(x != "" and y != "")
	{
		_overlayX := x
		_overlayY := y
	}
	
	if(toggle = 1 or GetKeyState(t_hotkey, "P") = 1) {
		ActiveOverlay := "o_Spin"
		GUI, o_Spin:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate, o_Spin
		GUI, o_Still:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate Hide, o_Still
	}
	else {
		ActiveOverlay := "o_Still"
		GUI, o_Still:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate, o_Still
		GUI, o_Spin:Show,x%_overlayX% y%_overlayY% w50 h50 NoActivate Hide, o_Spin
	}
	return
}

FireAniCancelledRotation() {
	if((t_Hook = 1 and !WinActive(bns_class)) or (t_Hold = 1 and toggle = 0))
		return
				
	while(toggle = 1 or GetKeyState(t_hotkey, "P") = 1) {
		timeStart := A_TickCount
		loop {
			SendInput {%t_AnicancelSkill%}
			timeNow := A_TickCount - timeStart
			if(timeNow > 20)
				break
		}
		Sleep, estimated_gcd
		ParseRotation()
		
	}
	
	;if(t_Anicancel = 1 and GetKeyState(t_AnicancelSkill) = 1)
	;	SendInput {%t_AnicancelSkill% up}
	
}

FireRotation() {
	while(toggle = 1 or GetKeyState(t_hotkey, "P") = 1) {
		if((t_Hook = 1 and !WinActive(bns_class)) or (t_Hold = 1 and toggle = 0))
			break
		
		ParseRotation()
				
		if(t_Delay = "1")
			Sleep, t_delayBox
	}
}

ParseRotation() { 
	for index, skill in rotation {	
		;Verifies whether its a delay command
		i_length := StrLen(skill)
		l_delay := SubStr(skill, 1)
		
		if(i_length > 1 and l_delay Is Number) {
			Sleep, l_delay
			SendInput {%skill% down}
			SendInput {%skill% up}
		}
		else if(i_length = 1) {
			SendInput {%skill% down}
			SendInput {%skill% up}
		}	
	}
}

GuiClose:
	ExitApp