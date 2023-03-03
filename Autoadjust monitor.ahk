; By DRSAgile, https://github.com/DRSAgile/Autoadjust-Monitor/

#Persistent
#SingleInstance force
#Include %a_scriptdir%
#Include Autoadjust monitor-configuration.ahk
#include Class_Monitor.ahk ; from  https://github.com/jNizM/Class_Monitor

_dataFileFullNameWithPath := a_scriptdir "\" StrReplace(A_ScriptName, ".ahk") _dataFileExtension
_lastWeatherCheckInMinutes := 0
_lastSuccessfulWeatherCheckInMinutes := 0
_lastContrastCoefficietFromWeather := 1
_lastSetContast := 0
_dataFileRowToSearch := 0
_sunriseTimeInMinutes := 0
_sunsetTimeInMinutes := 0

; fills _sunriseTimeInMinutes and _sunsetTimeInMinutes for a current day
;
; IMPORTANT: sunrise and sunset times can also be retrieved from weather data (e.g. "sunrise":1677819183,"sunset":1677857341), so there will be no need for a table file for this. However, the information within the weather may not be present in every case, and taking weather into account is optional in this script (and it may not even work reliably, depending on circumstances), so it is not implemented in this case
getSunriseAndSunsetTimes(leapYearDataAvailable := true)
{
	global _dataFileFullNameWithPath, _dataFileRowToSearch, _dataFileSeparator, _dataFileSunriseColumn, _dataFileSunsetColumn, _sunriseTimeInMinutes, _sunsetTimeInMinutes
	
	_sunriseTimeInMinutes := 0
	_sunsetTimeInMinutes := 0
	
	Loop, read, %_dataFileFullNameWithPath%
	{
		If (A_Index <= _dataFileRowToSearch + (leapYearDataAvailable ? 0 : -1))
		{
			Continue
		}
		Loop, parse, A_LoopReadLine, %_dataFileSeparator%
		{
			If (A_Index = _dataFileSunriseColumn)
			{
				sunriseTimeArray := StrSplit(A_LoopField, ":")
				_sunriseTimeInMinutes := sunriseTimeArray[1] * 60 + sunriseTimeArray[2]
			}
			If (A_Index = _dataFileSunsetColumn)
			{
				sunsetTimeArray := StrSplit(A_LoopField, ":")
				_sunsetTimeInMinutes := sunsetTimeArray[1] * 60 + sunsetTimeArray[2]
			}
		}
		Break
	}
	if (!_sunriseTimeInMinutes and leapYearDataAvailable)
	{
		getSunriseAndSunsetTimes(false)
	}
	else if (!_sunriseTimeInMinutes)
	{
		MsgBox, No sunset and/or sunrise time found in the "%_dataFileFullNameWithPath%" file
		ExitApp
	}
}

main()
{
	global Monitor, _typeOfCurve, _weatherURL, _weatherRegExp, _weatherContrastThresholds, _weatherCheckPeriodInMinutes, _showNetworkErrors, _lastWeatherCheckInMinutes, _lastSuccessfulWeatherCheckInMinutes, _lastContrastCoefficietFromWeather, _dataFileRowToSearch, _dataFileHeaderHeight, _sunriseTimeInMinutes, _sunsetTimeInMinutes, _beforeSunriseOrAfterSunsetContrast,_zenithContrast, _lastSetContast
	
	if (_dataFileRowToSearch != _dataFileHeaderHeight + A_YDay)
	{
		_dataFileRowToSearch := _dataFileHeaderHeight + A_YDay
		getSunriseAndSunsetTimes()
		_lastWeatherCheckInMinutes := 0
	}
	currentTimeInMinutes := A_Hour * 60 + A_Min
	;MsgBox, sunrise: %_sunriseTimeInMinutes%, sunset: %_sunsetTimeInMinutes%, current time: %A_Hour%:%A_Min% = %currentTimeInMinutes%

 	If ((currentTimeInMinutes <= _sunriseTimeInMinutes Or currentTimeInMinutes >= _sunsetTimeInMinutes) )
	{
		if (_lastSetContast != _beforeSunriseOrAfterSunsetContrast)
		{
			_lastSetContast := _beforeSunriseOrAfterSunsetContrast
			Monitor.SetContrast(_lastSetContast)
		}
		return
	}
	netCurrentTimeInMinutes := currentTimeInMinutes - _sunriseTimeInMinutes ; x
	mean := (_sunsetTimeInMinutes - _sunriseTimeInMinutes) / 2
	
	If (_typeOfCurve = "circle")
	{
		contrastCoefficient := Sqrt(1 - ((-mean + netCurrentTimeInMinutes) / mean)**2) ; a circle with radius 1 and centre in 0 formula: y = sqrt(1 - x^2)
	}
	else if (_typeOfCurve = "parabola")
	{
		contrastCoefficient := -((-mean + netCurrentTimeInMinutes) / mean) **2 + 1 ; upside-down parabola with top at 1 and branched going to -1 and +1 formula: y = -x^2 + 1
	}
	else if (_typeOfCurve = "Bell") ; not finalized
	{	; currentTimeInMinutes := 13 * 60 + 0 ; for testing
		e := 2.718281828459045
		pi := 3.141592653589793
		sigma := mean / 4
		contrastCoefficient := (1 / (sigma * Sqrt(2 * pi))) * (e ** (-(netCurrentTimeInMinutes - mean)**2/(2 * sigma ** 2))) ; y
		; MsgBox, % currentTimeInMinutes " " e " " pi " " mean " " sigma " " netCurrentTimeInMinutes " " contrastCoefficient
	}	
	;MsgBox, % _typeOfCurve " " contrastCoefficient " " _sunriseTimeInMinutes " " currentTimeInMinutes " " _sunsetTimeInMinutes
		
	If (_weatherURL and currentTimeInMinutes > _lastWeatherCheckInMinutes + _weatherCheckPeriodInMinutes)
	{
		_lastWeatherCheckInMinutes := currentTimeInMinutes
		Try
		{
			WinHttpRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
			WinHttpRequest.Open("GET", _weatherURL, true)
			WinHttpRequest.Send() ; Using 'true' above and the call below allows the script to remain responsive.
			WinHttpRequest.WaitForResponse()
				
			RegExMatch(WinHttpRequest.ResponseText, _weatherRegExp, matchedGroups) ; there are will be automaticly generated matchedGroups1, matchedGroups2 ... variables

			If (_weatherContrastThresholds[matchedGroups1])
			{
				_lastContrastCoefficietFromWeather := _weatherContrastThresholds[matchedGroups1]
			}
			_lastSuccessfulWeatherCheckInMinutes := currentTimeInMinutes
		}
		catch exc
		{
			If (_showNetworkErrors)
			{
				MsgBox, %A_ScriptName%:`n`r`n`r%exc%
			}
		}
	}
	contrastCoefficient := contrastCoefficient * _lastContrastCoefficietFromWeather
		
	_lastSetContast := Round(_beforeSunriseOrAfterSunsetContrast + contrastCoefficient * (_zenithContrast - _beforeSunriseOrAfterSunsetContrast))
	If (Monitor.GetContrast() != _lastSetContast)
	{
		Monitor.SetContrast(_lastSetContast)
	}
}

main()
SetTimer, main, %_updateEveryMilliseconds%
