#SingleInstance force
SendMode "Input"

lastMount := 3 ; broom by default
remountKey := "b"

#HotIf WinActive("ahk_exe HogwartsLegacy.exe")
	; Monitor mounts
	~Tab::{
		timeout := 0
		While GetKeyState("Tab", "P") && timeout < 1 { ; while tab is pressed
			k1 := GetKeyState("1", "P")
			k2 := GetKeyState("2", "P")
			k3 := GetKeyState("3", "P")

			; if any of the mount keys is pressed, set current mount to that key
			switch 1 {
				case k1:
					lastMount := 1
				case k2:
					lastMount := 2
				case k3:
					lastMount := 3
			}
			
			timeout += 0.01
		}
		Return
	}

	; Remount the last used mount when the hotkey is pressed
	~b:: {
		if KeyWait(remountKey, "T0.4") { ; if the key is held down for less than 0.4 seconds
			Return
		} else {
			; remount
			Send("{Tab Down}")
			Sleep(450) ; the magic number
			Send(lastMount)
			Send("{Tab up}")
		}
		Return
	}
