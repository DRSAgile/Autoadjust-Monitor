﻿# Autoadjust-Monitor
A script that automatically adjusts the monitor's contrast depending on the length of the day and whether it is clear or cloudy.

• The contrast is changing from the lowest set level at sunrise to peaking at zenith to again the lowest level at sunset.  
• The trajectory of the change is either linear, or circular, parabolic, Bell-curve (normal distribution).  
• The curves for up to zenith and down from it are set separately to allow more flexibility for particular light conditions the monitor is situated in.  
• Similarly, the coefficients for different cloudiness is set both in three gradations and also depending on if the current time is before or after zenith.  
• A separate coefficient for contrast in full-screen mode that might additionally brighten up the monitor for video player applications, YouTube via Internet browsers, games, so on.  
• Multu-user configuration is supported.  

The script requires a preparation to work as intended.

Namely, a table file with sunrise and sunset times data for a whole year for a specific location needed. The times are basically the same, no matter which year the data is taken for. The script will work regardless if the data is for a leap year or not. 

Additionally, weather service might be used to adjust the monitor depending on how cloudy or sunny it is currently outside. Just as with the sunrise and sunset times, it will require coordinates, but also an API key that can be received upon registration in the weather service.

More details are in the script itself and in a separate configuration file, which can be either changed manually via a text editor or from a tray menu for some of the options.

[*Class Monitor* wrapper by jNizM](https://github.com/jNizM/Class_Monitor) for Microsoft's [Monitor Configuration API](https://learn.microsoft.com/en-us/windows/win32/api/_monitor/) is used.
