; By DRSAgile, https://github.com/DRSAgile/Autoadjust-Monitor/

#Persistent
#SingleInstance force
#Include %a_scriptdir%
#Include Autoadjust monitor-configuration.ahk
#include Class_Monitor.ahk ; from  https://github.com/jNizM/Class_Monitor

FileEncoding, UTF-8 ; means UTF-8 specifically with BOM
_configurationFileNameWithPath := a_scriptdir "\Autoadjust monitor-configuration"
_dataFileFullNameWithPath := a_scriptdir "\" StrReplace(A_ScriptName, ".ahk") _dataFileExtension
_lastWeatherCheckInMinutes := 0
_lastSuccessfulWeatherCheckInMinutes := 0
_lastContrastCoefficietFromWeather := 1
_lastSetContast := 0
_dataFileRowToSearch := 0
_sunriseTimeInMinutes := 0
_sunsetTimeInMinutes := 0
_sunriseTime := ""
_sunsetTime := ""
_zenithTime := ""
_unsavedChangesArray := []


HasVal(haystack, needle)
{
	for index, value in haystack
		if (value = needle)
			return index
	if !IsObject(haystack)
		throw Exception("Bad haystack!", -1, haystack)
	return 0	
} ; end of HasVal(haystack, needle)


; prompt needs to be a space by default as otherwise InputBox shows garbage
processInputBox(ByRef value, typeOfValue, ItemName, prompt := " ") 
{
	Global _unsavedChangesArray
	
	title := StrReplace(ItemName, ": " value, "")
	InputBox, newValue, %title%, %prompt%,,,,,,,,%value%
	
	If (ErrorLevel Or newValue == value)
		return false
	Else If (typeOfValue = "N100" and !(newValue ~= "^(?:100|)[0-9]{1,2}$"))
	{
		return processInputBox(value, typeOfValue, ItemName, "The value should be numeric between 0 and 100")
	}
	Else
	{
		value := newValue
		firstWord := StrReplace(StrSplit(ItemName, A_Space)[1], "*", "")
		If (!HasVal(_unsavedChangesArray, firstWord))
			_unsavedChangesArray.push(firstWord)
		main()
		return true
	}
} ; end of processInputBox(value, typeOfValue, title, prompt := "")


; the function can receive additional parameters with statements like this: edit1 := Func("edit").Bind("First", "Test one") and then using it like "Menu, Tray, Add, Item name, % edit1
edit(ItemName, ItemPos, MenuName)
{
	Global _unsavedChangesArray, _typeOfCurveArray, _typeOfCurve, _beforeSunriseOrAfterSunsetContrast, _zenithContrast
	
	If (StrSplit(ItemName, A_Space).Length() = 1)
	{
		If (ItemName != _typeOfCurve)
		{
			_typeOfCurve := ItemName
			If (!HasVal(_unsavedChangesArray, "Type"))
				_unsavedChangesArray.push("Type")		
			main()
		}
	}
	Else If (InStr(ItemName, "Before"))
	{
		processInputBox(_beforeSunriseOrAfterSunsetContrast, "N100", ItemName)
	}
	Else If (InStr(ItemName, "Zenith"))
	{
		processInputBox(_zenithContrast, "N100", ItemName)
	}	
} ; end of edit(ItemName, ItemPos, MenuName)


; different menu items are identified by AHK by their text and, additionally in this script, by the first word, hence added menu items can not start with the same words
makeMenu()
{
	Global _sunriseTime, _zenithTime, _sunsetTime, _typeOfCurveArray, _typeOfCurve, _beforeSunriseOrAfterSunsetContrast, _zenithContrast, _unsavedChangesArray
	
	editTypeOfCurve := "Type of curve to interpolate the contrast: " _typeOfCurve
	editTypeOfCurve := (HasVal(_unsavedChangesArray, StrSplit(editTypeOfCurve, A_Space)[1]) ? "*" : "") editTypeOfCurve	
	
	editSunriseSunsetContrast := "Before sunrise (" _sunriseTime "), after sunset (" _sunsetTime ") contrast: " _beforeSunriseOrAfterSunsetContrast	
	editSunriseSunsetContrast := (HasVal(_unsavedChangesArray, StrSplit(editSunriseSunsetContrast, A_Space)[1]) ? "*" : "") editSunriseSunsetContrast
	
	editZenithContrast := "Zenith (" _zenithTime ") contrast: " _zenithContrast
	editZenithContrast := (HasVal(_unsavedChangesArray, StrSplit(editZenithContrast, A_Space)[1]) ? "*" : "") editZenithContrast
	
	Menu, Tray, DeleteAll	
	Menu, Tray, Add
	Menu, Tray, Add, Save changes, saveChanges
	If (!_unsavedChangesArray.Length())
		Menu, Tray, Disable, Save changes
	Menu, Tray, Add
	
	For index, element in _typeOfCurveArray
	{
		Menu, typeOfCurveSubmenu, Add, %element%, edit
		If (element = _typeOfCurve)
			Menu, typeOfCurveSubmenu, Check, %element%
		Else
			Menu, typeOfCurveSubmenu, Uncheck, %element%
	}
	Menu, Tray, Add, %editTypeOfCurve%, :typeOfCurveSubmenu
	
	Menu, Tray, Add, %editSunriseSunsetContrast%, edit
	Menu, Tray, Add, %editZenithContrast%, edit
} ; end of makeMenu()


saveChanges()
{
	Global _configurationFileNameWithPath, _typeOfCurveArray, _typeOfCurve, _zenithContrast, _beforeSunriseOrAfterSunsetContrast, _unsavedChangesArray
	
	configuration := ""
	Loop, read, %_configurationFileNameWithPath%.ahk
	{
		processedLine := RegExReplace(A_LoopReadLine, "(_typeOfCurve := _typeOfCurveArray\[).*$", "$1" HasVal(_typeOfCurveArray, _typeOfCurve) "]")
		processedLine := RegExReplace(processedLine, "(_zenithContrast :=).*$", "$1 " _zenithContrast) 
		processedLine := RegExReplace(processedLine, "(_beforeSunriseOrAfterSunsetContrast :=).*$", "$1 " _beforeSunriseOrAfterSunsetContrast)
		configuration .= processedLine "`n"
	}
	Try
	{
		FileCopy, %_configurationFileNameWithPath%.ahk,%_configurationFileNameWithPath%.bak, 1
		FileDelete, %_configurationFileNameWithPath%.ahk
		FileAppend, %configuration%, %_configurationFileNameWithPath%.ahk
		_unsavedChangesArray := []
		makeMenu()
		configuration := ""
	}
	catch exc
	{
		If (_showNetworkErrors)
		{
			MsgBox, %A_ScriptName%:`n`r`n`r%exc%
		}
	}
		
} ; end of saveChanges()


; fills _sunriseTimeInMinutes and _sunsetTimeInMinutes for a current day
;
; IMPORTANT: sunrise and sunset times can also be retrieved from weather data (e.g. "sunrise":1677819183,"sunset":1677857341), so there will be no need for a table file for this. However, the information within the weather may not be present in every case, and taking weather into account is optional in this script (and it may not even work reliably, depending on circumstances), so it is not implemented in this case
getSunriseAndSunsetTimes(leapYearDataAvailable := true)
{
	Global _dataFileFullNameWithPath, _dataFileRowToSearch, _dataFileSeparator, _dataFileSunriseColumn, _dataFileSunsetColumn, _sunriseTimeInMinutes, _sunsetTimeInMinutes, _sunriseTime, _sunsetTime, _zenithTime
	
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
				_sunriseTime := A_LoopField
				sunriseTimeArray := StrSplit(_sunriseTime, ":")
				_sunriseTimeInMinutes := sunriseTimeArray[1] * 60 + sunriseTimeArray[2]
				
			}
			If (A_Index = _dataFileSunsetColumn)
			{
				_sunsetTime := A_LoopField
				sunsetTimeArray := StrSplit(_sunsetTime, ":")
				_sunsetTimeInMinutes := sunsetTimeArray[1] * 60 + sunsetTimeArray[2]
			}
		}
		Break
	}
	If (!_sunriseTimeInMinutes and leapYearDataAvailable)
	{
		getSunriseAndSunsetTimes(false)
	}
	Else If (!_sunriseTimeInMinutes)
	{
		MsgBox, No sunset and/or sunrise time found in the "%_dataFileFullNameWithPath%" file
		ExitApp
	}
	zenithTime := Round((_sunriseTimeInMinutes + _sunsetTimeInMinutes) / 2, 0)
	zenithTimeH := Round(zenithTime // 60, 0)
	_zenithTime := zenithTimeH ":" (zenithTime - zenithTimeH * 60)
} ; end of getSunriseAndSunsetTimes(leapYearDataAvailable := true)


main()
{
	Global Monitor, _typeOfCurve, _weatherURL, _weatherRegExp, _weatherContrastThresholds, _weatherCheckPeriodInMinutes, _showNetworkErrors, _lastWeatherCheckInMinutes, _lastSuccessfulWeatherCheckInMinutes, _lastContrastCoefficietFromWeather, _dataFileRowToSearch, _dataFileHeaderHeight, _sunriseTimeInMinutes, _sunsetTimeInMinutes, _beforeSunriseOrAfterSunsetContrast,_zenithContrast, _lastSetContast
	
	If (_dataFileRowToSearch != _dataFileHeaderHeight + A_YDay)
	{
		_dataFileRowToSearch := _dataFileHeaderHeight + A_YDay
		getSunriseAndSunsetTimes()
		_lastWeatherCheckInMinutes := 0
	}
	currentTimeInMinutes := A_Hour * 60 + A_Min
	;MsgBox, sunrise: %_sunriseTimeInMinutes%, sunset: %_sunsetTimeInMinutes%, current time: %A_Hour%:%A_Min% = %currentTimeInMinutes%

 	If ((currentTimeInMinutes <= _sunriseTimeInMinutes Or currentTimeInMinutes >= _sunsetTimeInMinutes) )
	{
		If (_lastSetContast != _beforeSunriseOrAfterSunsetContrast)
		{
			_lastSetContast := _beforeSunriseOrAfterSunsetContrast
			Monitor.SetContrast(_lastSetContast)
		}
		return
	}
	netCurrentTimeInMinutes := currentTimeInMinutes - _sunriseTimeInMinutes ; x
	mean := (_sunsetTimeInMinutes - _sunriseTimeInMinutes) / 2
	
	If (_typeOfCurve = "linear")
	{
		contrastCoefficient := (netCurrentTimeInMinutes < mean ? netCurrentTimeInMinutes : (2 * mean - netCurrentTimeInMinutes)) / mean
	}
	Else If (_typeOfCurve = "circle")
	{
		contrastCoefficient := Sqrt(1 - ((-mean + netCurrentTimeInMinutes) / mean)**2) ; a circle with radius 1 and centre in 0 formula: y = sqrt(1 - x^2)
	}
	Else If (_typeOfCurve = "parabola")
	{
		contrastCoefficient := -((-mean + netCurrentTimeInMinutes) / mean) **2 + 1 ; upside-down parabola with top at 1 and branched going to -1 and +1 formula: y = -x^2 + 1
	}
	Else If (_typeOfCurve = "Bell") ; not finalized
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
		
	makeNewMenu := _lastSetContast ? false : true
	_lastSetContast := Round(_beforeSunriseOrAfterSunsetContrast + contrastCoefficient * (_zenithContrast - _beforeSunriseOrAfterSunsetContrast))
	If (Monitor.GetContrast() != _lastSetContast)
	{
		Monitor.SetContrast(_lastSetContast)
		makeNewMenu := true
	}
	If (makeNewMenu)
	{
		makeMenu()
	}
} ; end of main()


main()
SetTimer, main, %_updateEveryMilliseconds%
