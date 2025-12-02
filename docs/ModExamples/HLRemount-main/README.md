# HLRemount
An AHK V2.0 script for Hogwarts Legacy which remounts your most recent mount quickly upon pressing b

## Installation
### A: Running or compiling the script with AutoHotkey
1. Install [AutoHotkey](https://www.autohotkey.com/) `v2.0`
2. Get the source code
3. Clone this repo with git or download the [latest version](https://github.com/moritztim/HLRemount/releases/latest)'s source code and extract the archive
2. Download the [latest version]()'s source code
#### If you want to run it through the installed AutoHotkey:
3. Open the `.ahk` file.
#### If want to compile it to get a standalone executable:
3. Right click the `.ahk` file
4. Select `Compile`.
You can now use the resulting executable (even on a system that does not have AutoHotkey installed).
You can even compare the hash with the executable I provided to see if you could've just trusted me in the first place.
### B: Running the executable *(if you trust me)*
Simply download the executable of the [latest version](https://github.com/moritztim/HLRemount/releases/latest) and execute it.
> ⚠️ You should not trust a random stranger on the internet who gives you an executable, so it's highly advisable to review and compile/run the script yourself.

## Usage
# Ingame
Press b on your keyboard to equip your last used mount. By default it's the broom.
# Pausing and stopping the script
The script does not run when the game is not in focus.
If you want the hotkey to be inactive but the script to still observe what mount you're using (so you can remount it later), right click the tray icon and select `Suspend Hotkeys`. Simply do this again to enable the hotkey again.
If you want to stop the script completely, right click the tray icon and select `Exit`.

## Customisation
* To change the default mount, change the number on line 4 (`lastMount := 3`) to the number next to your mount in the tab menu.
* To change the hotkey, replace `b` on line 5 (`remountKey := "b"`)
> more information on the documentation of [AutoHotkey](https://www.autohotkey.com/docs/v2/)

> icon used for the executable by [Twitter](https://github.com/twitter/twemoji/blob/master/assets/svg/1f9f9.svg)
