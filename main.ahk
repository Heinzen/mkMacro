;Assume MIT Licensing

;Author: Heinzen/Magiruu
;AppFactory author: evilC (Modified by Heinzen)
;GifPlayer author: A_Samurai (Modified by Heinzen)

;	---TODOS---
; 1) Implement delay between skills
; 2) Improve GUI performance
; 3) Kill switch

#SingleInstance, Force
#MaxThreadsPerHotkey 2
#Include %A_ScriptDir%\Import\AppFactory.ahk
#Include %A_ScriptDir%\Import\GifPlayer.ahk

Gui +LastFound

;	Request Admin
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

;SetTimer, CheckActiveWindow, 2500

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
global rotation :=
global toggle := 0
global gif_Spinner := A_ScriptDir "\Resources\spinner.gif"
global still_Spinner := A_ScriptDir "\Resources\\still.png"
global _overlayX := 855
global _overlayY := 550
global bns_class := "ahk_class LaunchUnrealUWindowsClient"
global script_class := "ahk_class AutoHotkeyGUI" 
global transparency := EEAA99
global ActiveOverlay := "o_Still"
global move_Tooltip := 0
global still_Style := ""
global spin_Style := ""

;	GUI Design
;	----------
factory := new AppFactory()

GUI,Add,GroupBox,x157 y15 w140 h180,Settings
	GUI,Add,Text,x169 y35 w70 h13,Delay (in ms)
	factory.AddControl("DelayBox", "Edit", "x170 y50 w40 h21 vt_DelayBox", "0", Func("SubmitAll"))
	GUI,Add,Text,x171 y75 w120 h13,Rotation (";" separated)
	factory.AddControl("RotationBox", "Edit", "x170 y90 w70 h21 vt_RotationBox", "3;t;f;", Func("SubmitAll"))
	factory.AddInputButton("HK1", "x170 y130 w115 h25", Func("TryRecordHotkey").Bind("Keybind"))
	GUI,Add,Button,x170 y160 w115 gg_ConfirmButton vt_ConfirmButton,Save
	
GUI,Add,GroupBox,x15 y15 w120 h180,Toggles
	factory.AddControl("Overlay", "CheckBox", "x27 y45 w90 h13 vt_Overlay", "Display Overlay", Func("ToggleOverlay"))
	factory.AddControl("HoldKB", "CheckBox", "x27 y65 w90 h13 vt_Hold", "Attack Toggle", Func("SubmitAll"))
	factory.AddControl("ToggleDelay", "CheckBox", "x27 y85 w90 h13 vt_Delay", "Enable Delay", Func("SubmitAll"))
	factory.AddControl("HookToClient", "CheckBox", "x27 y105 w90 h13 vt_Hook", "Hook to BnS", Func("SubmitAll"))
DetectHiddenWindows, On
WinSetTitle, mk Macro
GUI, Submit, NoHide
GUI,Show,w310 h220, mkMacro

CreateOverlay()
OnMessage(0x2A1,"WM_MOUSEHOVER")
OnMessage(0x201,"WM_LMBDOWN")
	
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
	return
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
	
	while(toggle = 1 or GetKeyState(t_hotkey, "P") = 1)
		FireRotation()
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

FireRotation() {
	for index, skill in rotation {	
		if((t_Hook = 1 and !WinActive(bns_class)) or (t_Hold = 1 and toggle = 0))
			break
		SendInput {%skill%}
	
		if(t_Delay = "1")
			Sleep, %t_DelayBox% ; Adding the extra average of 15.6ms is seemingless in this case
		else
			DllCall("Sleep", "UInt", 5) ; Save CPU Performance and use WinAPI's call for reliability
	}
}

GuiClose:
	ExitApp