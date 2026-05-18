<p align="center">
  <img src="https://github.com/shadowed1/Autothrottle/blob/main/bin/readme_assets/AutothrottleHeader.png?raw=true" alt="logo" width="600" />
</p>  

<br><br>

# What is Autothrottle?

- Prevents Macbooks becoming too hot while enabling full performance when cool.
- Designed for all Macs using Apple Silicon.
- Autothrottle toggles Low Power Mode without brightness change to maintain user-defined clockspeed limit.
- Customize clockspeed limit, cooldown duration, CPU usage threshold, and more.

### Current Release:
https://github.com/shadowed1/Autothrottle/releases/download/0.17/Autothrottle.dmg

<br><br>

<p align="center">
  <img src="https://github.com/shadowed1/Autothrottle/blob/main/bin/readme_assets/AutothrottleMenuBar.png?raw=true" alt="logo" width="600" />
</p>

<p align="center">
  <img src="https://github.com/shadowed1/Autothrottle/blob/main/bin/readme_assets/AutothrottleSettings.png?raw=true" alt="logo" width="600" />
</p>  

<br><br>

## How to use it?

- When opening the Autothrottle app, it will appear as a CPU icon in MacOS' Menu Bar.
- Click the CPU icon in the Menu Bar and click Autothrottle's Stopped/Running button to start/stop. 
- Open Autothrottle's settings to customize thermal limits.
- Inside settings remove Autothrottle clicking Uninstall; click About to check for updates!

## How does it work?

- Autothrottle uses Apple's powermetric tool to monitor CPU clockspeed and CPU usage.
- Heuristical algorithm used to detect when MacOS micro-throttles CPU when hot.
- Low Power Mode is toggled on when exceeding user-defined limits (in Settings), 
- Autothrottle restores full performance when cooldown duration ends. 
- Brightness is read by using `DisplayServicesGetBrightness` and preserved.
- Autothrottle locks and unlocks saved display brightness value right before and after Low Power Mode toggling.
- Uses `pmset` to control Low Power Mode.

### Changelog:

- Apr 28th, 2026 - 0.1: `Initial Release.` <br>
- May 1st, 2026  - 0.11: `Relaxed default CPU limits slightly. Fixed rare brightness flicker issue.` <br>
- May 2nd, 2026  - 0.12: `Added dropdown menu to advanced section. Improved dropdown menus.` <br>
- May 2nd, 2026  - 0.13: `Fixed mismatched menu bar slider size.` <br>
- May 7th, 2026  - 0.14: `Added default, dark, clear, and tinted icon styling.` <br>
- May 10th, 2026 - 0.15: `Fixed peak clockspeed error. Improved uninstaller to remove leftover files.` <br>
- May 15th, 2026 - 0.16: `Fixed clockspeed error when CPU is already really hot prior to fresh install.` <br>
- May 18th, 2026 - 0.17: `Updated to be compatible with Taho 26.5's security changes. Added dynamic clockspeed update support.` <br>

### Acknowledgments:

*[Seoclaid](https://github.com/seoclaid)* - Thanks for helping with icon and UI. <br>
*[Skylar](https://github.com/skylartaylor)* - Thanks for valuable advice on helping me with UI. <br>
