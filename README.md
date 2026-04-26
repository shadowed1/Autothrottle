<p align="center">
  <img src="https://i.imgur.com/Dck6PZ3.png" alt="logo" width="400" />
</p>  

<br><br>

# What is Autothrottle?

- Prevents Macbooks becoming too hot while enabling full performance when cooled.
- Designed for all Macs using Apple Silicon.
- Toggles Low Power Mode without brightness change.
- Customize clockspeed limit, cooldown duration, CPU usage threshold, and more.

# How to use it?

- When opening the Autothrottle app, it will appear as a CPU icon in MacOS' Menu Bar.
- Click the CPU icon in the Menu Bar and click Autothrottle's Stopped/Running button to start/stop. 
- Open Autothrottle's settings to customize thermal limits.

# How does it work?

- Autothrottle uses Apple's powermetric tool to monitor CPU clockspeed.
- Heuristical algorithm used to detect when Apple micro-throttles CPU when hot. <br>
- Low Power Mode is toggled on when exceeding user-defined limits (in Settings), 
- Autothrottle restores full performance when cooldown duration ends. 
- Brightness is read by using Apple's DisplayServicesGetBrightness and preserved.
- Autothrottle locks and unlocks saved display brightness value right before and after Low Power Mode toggling.
- Uses Apple's pmset to control Low Power Mode.
- Inverted CPU clockspeed algorithm used to display Apple's CPU thermal clockspeed limits. 

