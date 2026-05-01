<p align="center">
  <img src="https://github.com/shadowed1/Autothrottle/blob/main/bin/readme_assets/AutothrottleHeader.png?raw=true" alt="logo" width="600" />
</p>  

<br><br>

# What is Autothrottle?

- Prevents Macbooks becoming too hot while enabling full performance when cool.
- Designed for all Macs using Apple Silicon.
- Toggles Low Power Mode without brightness change.
- Customize clockspeed limit, cooldown duration, CPU usage threshold, and more.

# Current Release:
https://github.com/shadowed1/Autothrottle/releases/download/0.1/Autothrottle.dmg

<br><br>

<p align="center">
  <img src="https://github.com/shadowed1/Autothrottle/blob/main/bin/readme_assets/AutothrottleMenuBar.png?raw=true" alt="logo" width="600" />
</p>

<p align="center">
  <img src="https://github.com/shadowed1/Autothrottle/blob/main/bin/readme_assets/AutothrottleSettings.png?raw=true" alt="logo" width="600" />
</p>  

<br><br>

# How to use it?

- When opening the Autothrottle app, it will appear as a CPU icon in MacOS' Menu Bar.
- Click the CPU icon in the Menu Bar and click Autothrottle's Stopped/Running button to start/stop. 
- Open Autothrottle's settings to customize thermal limits.
- Inside settings, Uninstall button will remove Autothrottle. About can check for updates!

# How does it work?

- Autothrottle uses Apple's powermetric tool to monitor CPU clockspeed.
- Heuristical algorithm used to detect when Apple micro-throttles CPU when hot.
- Low Power Mode is toggled on when exceeding user-defined limits (in Settings), 
- Autothrottle restores full performance when cooldown duration ends. 
- Brightness is read by using `DisplayServicesGetBrightness` and preserved.
- Autothrottle locks and unlocks saved display brightness value right before and after Low Power Mode toggling.
- Uses `pmset` to control Low Power Mode.
- Inverted CPU clockspeed algorithm used to display Apple's CPU thermal clockspeed limits.

# Changelog:

- April 28th, 2026, 0.1: `Initial Release.`
