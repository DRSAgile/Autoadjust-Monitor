# Autoadjust-Monitor
A script that automatically adjusts the monitor's contrast depending on the length of the day and whether it is clear or cloudy.

The contrast is changing from the lowest set level at sunrise to peaking at zenith to again the lowest level at sunset either linearly, or via circular, parabolic or Bell-curve trajectories.

The script requires a preparation to work as intended.

Namely, a table file with sunrise and sunset times data for a whole year for a specific location needed. The times are basically the same, no matter which year the data is taken for. The script will work regardless if the data is for a leap year or not. 

Additionally, weather service might be used to adjust the monitor depending on how cloudy or sunny it is currently outside. Just as with the sunrise and sunset times, it will require coordinates, but also an API key that can be received upon registration in the weather service.

More details are in the script itself and in a separate configuration file.

[*Class Monitor* wrapper by jNizM](https://github.com/jNizM/Class_Monitor) for Microsoft's [Monitor Configuration API](https://learn.microsoft.com/en-us/windows/win32/api/_monitor/) is used.
