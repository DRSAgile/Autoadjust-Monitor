# Autoadjust-Monitor
A script that automatically adjusts the monitor's contrast depending on the length of the day and whether it is clear or cloudy.

The script requires a preparation to work as intended.

Namely, a table file with sunrise and sunset times data for a whole year for a specific location needed. The times are basically the same, no matter which year the data is taken for. And whether the data is for a leap year or not, the script should work regardless. 

Additionally, weather service might be used to adjust the monitor also depending on whether it is currently sunny or cloudy outside. Just as with the sunrise and sunset times, it will require coordinates, but also an API key that can be received upon registration in the weather service.

More details are in the script itself.

The script uses [*Class Monitor* wrapper by jNizM](https://github.com/jNizM/Class_Monitor) for Microsoft's [Monitor Configuration API](https://learn.microsoft.com/en-us/windows/win32/api/_monitor/).
