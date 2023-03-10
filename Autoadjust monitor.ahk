; By DRSAgile, https://github.com/DRSAgile/Autoadjust-Monitor/

#Persistent
#SingleInstance force
#Include %a_scriptdir%
#Include Autoadjust monitor-configuration.ahk
#include Class_Monitor.ahk ; from  https://github.com/jNizM/Class_Monitor

FileEncoding, UTF-8 ; means UTF-8 specifically with BOM
_configurationFileNameWithPath := a_scriptdir "\Autoadjust monitor-configuration"
_dataFileFullNameWithPath := a_scriptdir "\" StrReplace(A_ScriptName, ".ahk", _dataFileExtension)
_iconFileFullNameWithPath := a_scriptdir "\" StrReplace(A_ScriptName, ".ahk", ".png")
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
_lastIsFullscreen := isWindowFullScreen("A")
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


; a variant from https://www.autohotkey.com/board/topic/50876-isfullscreen-checks-if-a-window-is-in-fullscreen-mode/, even though more detailed, does NOT detect a video player working in full screen
; but this variant does work:   https://www.autohotkey.com/board/topic/38882-detect-fullscreen-application/ by Icarus:
isWindowFullScreen(winTitle)
{
	;checks if the specified window is full screen
	winID := WinExist(winTitle)

	If (!winID)
		Return false

	WinGet style, Style, ahk_id %WinID%
	WinGetPos ,,,winW,winH, %winTitle%
	; 0x800000 is WS_BORDER.
	; 0x20000000 is WS_MINIMIZE.
	; no border and not minimized
	Return ((style & 0x20800000) or winH < A_ScreenHeight or winW < A_ScreenWidth) ? false : true
} ; end of isWindowFullScreen(winTitle)


; prompt needs to be a space by default as otherwise InputBox shows garbage
processInputBox(ByRef value, typeOfValue, ItemName, prompt := " ") 
{
	Global _unsavedChangesArray
	
	title := StrReplace(ItemName, ": " value, "")
	InputBox, newValue, %title%, %prompt%,,,,,,,,%value%
	
	If (ErrorLevel Or newValue == value)
		return false
	Else If (typeOfValue = "IN>0<=100" and !(newValue ~= "^(?:100|)[0-9]{1,2}$"))
		return processInputBox(value, typeOfValue, ItemName, "The value should be an integer numeric between 0 and 100")
	Else If (typeOfValue = "FN>=1<2" and !(newValue ~= "^(?:1|1\.[0-9]{1,2})$"))
		return processInputBox(value, typeOfValue, ItemName, "The value should be a floating point numeric between 1 and 2")
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
	Global _unsavedChangesArray, _typeOfCurveArray, _typeOfCurveLeft, _typeOfCurveRight, _beforeSunriseOrAfterSunsetContrast, _zenithContrast, _сontrastCoefficientInFullscreen, _weatherContrastThresholds
	
	callMain := false
	firstWord := StrReplace(StrSplit(ItemName, A_Space)[1], "*")
	If (InStr(MenuName, "Left") And ItemName != _typeOfCurveLeft)
	{
		_typeOfCurveLeft := ItemName
		If (!HasVal(_unsavedChangesArray, "Up"))
			_unsavedChangesArray.push("Up")		
		callMain := true
	}
	Else If (InStr(MenuName, "Right") And ItemName != _typeOfCurveRight)
	{
		_typeOfCurveRight := ItemName
		If (!HasVal(_unsavedChangesArray, "Down"))
			_unsavedChangesArray.push("Down")		
		callMain := true
	}
	Else If (firstWord = "Before")
		callMain := processInputBox(_beforeSunriseOrAfterSunsetContrast, "IN>0<=100", ItemName)
	Else If (firstWord = "Zenith")
		callMain := processInputBox(_zenithContrast, "IN>0<=100", ItemName)
	Else If (firstWord = "Contrast")
		callMain := processInputBox(_сontrastCoefficientInFullscreen, "FN>=1<2", ItemName)
	Else If ((weatherArray := ["Clear","Few","Scattered"]) And (weatherIndex := HasVal(weatherArray, firstWord)))
		For k, v In _weatherContrastThresholds
			If (weatherIndex = A_Index And (callMain := processInputBox(v, "FN>=1<2", ItemName)) And (_weatherContrastThresholds[k] := Trim(v, "0")))
				Break
	If (callMain)
		main()
		
} ; end of edit(ItemName, ItemPos, MenuName)


; different menu items are identified by AHK by their text and, additionally in this script, by the first word, hence added menu items can not start with the same words
processMenuItem(str)
{
	global _unsavedChangesArray
	return (HasVal(_unsavedChangesArray, StrSplit(str, A_Space)[1]) ? "*" : "") str	
} ; end of processMenuItem(str)


; different menu items are identified by AHK by their text and, additionally in this script, by the first word, hence added menu items can not start with the same words
makeMenu(makeNewMenu = false, currentTimeInMinutes = 0, beforeZenith = 0)
{
	Global _lastSetContast, _sunriseTime, _zenithTime, _sunsetTime, _sunriseTimeInMinutes, _sunsetTimeInMinutes, _сontrastCoefficientInFullscreen, _typeOfCurveArray, _typeOfCurveLeft, _typeOfCurveRight, _beforeSunriseOrAfterSunsetContrast, _zenithContrast, _weatherContrastThresholds, _lastContrastCoefficietFromWeather, _unsavedChangesArray
	
	If (currentTimeInMinutes)
		Menu, Tray, Tip, % "current contrast: " _lastSetContast ",`nactive curve: " (currentTimeInMinutes < _sunriseTimeInMinutes Or currentTimeInMinutes > _sunsetTimeInMinutes ? "none; out of the daylight" : (beforeZenith ? _typeOfCurveLeft : _typeOfCurveRight)) ",`nweather coefficient: " _lastContrastCoefficietFromWeather
	
	if (!makeNewMenu)
		Return

	Menu, Tray, DeleteAll	
	Menu, Tray, Add
	Menu, Tray, Add, Save changes, saveChanges
	If (!_unsavedChangesArray.Length())
		Menu, Tray, Disable, Save changes
	Menu, Tray, Add
	Menu, Tray, Add, % processMenuItem("Contrast coefficient in fullscreen mode: " _сontrastCoefficientInFullscreen), edit
	For k, v In _weatherContrastThresholds
	{
		If (A_Index = 1)
			Menu, Tray, Add, % processMenuItem("Clear skies contrast coefficient: " v), edit
		Else If (A_Index = 2)
			Menu, Tray, Add, % processMenuItem("Few clouds contrast coefficient: " v), edit
		Else If (A_Index = 3)
			Menu, Tray, Add, % processMenuItem("Scattered clouds contrast coefficient: " v), edit
	}
	For index, element In _typeOfCurveArray
	{
		Menu, typeOfCurveSubmenuLeft, Add, %element%, edit
		If (element = _typeOfCurveLeft)
			Menu, typeOfCurveSubmenuLeft, Check, %element%
		Else
			Menu, typeOfCurveSubmenuLeft, Uncheck, %element%
		Menu, typeOfCurveSubmenuRight, Add, %element%, edit
		If (element = _typeOfCurveRight)
			Menu, typeOfCurveSubmenuRight, Check, %element%
		Else
			Menu, typeOfCurveSubmenuRight, Uncheck, %element%
	}
	Menu, Tray, Add, % processMenuItem("Up to zenith curve for interpolation: " _typeOfCurveLeft), :typeOfCurveSubmenuLeft
	Menu, Tray, Add, % processMenuItem("Down from zenith curve for interpolation: " _typeOfCurveRight), :typeOfCurveSubmenuRight
	Menu, Tray, Add, % processMenuItem("Before sunrise (" _sunriseTime "), after sunset (" _sunsetTime ") contrast: " _beforeSunriseOrAfterSunsetContrast), edit
	Menu, Tray, Add, % processMenuItem("Zenith (" _zenithTime ") contrast: " _zenithContrast), edit
} ; end of makeMenu(makeNewMenu = false, currentTimeInMinutes = 0, beforeZenith = 0)


saveChanges()
{
	Global _configurationFileNameWithPath, _typeOfCurveArray, _typeOfCurveLeft, _typeOfCurveRight, _zenithContrast, _beforeSunriseOrAfterSunsetContrast, _сontrastCoefficientInFullscreen, _weatherContrastThresholds, _unsavedChangesArray, _showNetworkErrors
	
	weatherRegExpArray := ["(_weatherContrastThresholds :=\s*{[^:]+:)[^,]+(,.+)$", "(_weatherContrastThresholds :=\s*?{[^,]+[^:]+:)[^,]+(,.+?)$", "(_weatherContrastThresholds :=\s*?{[^,]+[^:]+:[^,]+[^:]+:)[^,]+(}.*?)$"]
	
	configuration := ""
	Loop, read, %_configurationFileNameWithPath%.ahk
	{
		processedLine := RegExReplace(A_LoopReadLine, "(_typeOfCurveLeft := _typeOfCurveArray\[).*$", "$1" HasVal(_typeOfCurveArray, _typeOfCurveLeft) "]")		
		processedLine := RegExReplace(processedLine, "(_typeOfCurveRight := _typeOfCurveArray\[).*$", "$1" HasVal(_typeOfCurveArray, _typeOfCurveRight) "]")
		processedLine := RegExReplace(processedLine, "(_zenithContrast :=).*$", "$1 " _zenithContrast) 
		processedLine := RegExReplace(processedLine, "(_beforeSunriseOrAfterSunsetContrast :=).*$", "$1 " _beforeSunriseOrAfterSunsetContrast)
		processedLine := RegExReplace(processedLine, "(_сontrastCoefficientInFullscreen :=).*$", "$1 " _сontrastCoefficientInFullscreen)
		If (InStr(processedLine, "_weatherContrastThresholds"))
			For k, v in _weatherContrastThresholds
					processedLine := RegExReplace(processedLine, weatherRegExpArray[A_Index], "$1 " v "$2")
		configuration .= processedLine "`n"
	}
	Try
	{
		FileCopy, %_configurationFileNameWithPath%.ahk,%_configurationFileNameWithPath%.bak, 1
		FileDelete, %_configurationFileNameWithPath%.ahk
		FileAppend, %configuration%, %_configurationFileNameWithPath%.ahk
		_unsavedChangesArray := []
		makeMenu(true)
		configuration := ""
	}
	catch exc
		If (_showNetworkErrors)
			MsgBox, 1 ;MsgBox, %A_ScriptName%:`n`r`n`r%exc%
		
} ; end of saveChanges()


; fills _sunriseTimeInMinutes and _sunsetTimeInMinutes for a current day
;
; IMPORTANT: sunrise and sunset times can also be retrieved from weather data (e.g. "sunrise":1677819183,"sunset":1677857341), so there will be no need for a table file for this. However, the information within the weather may not be present in every case, and taking weather into account is optional in this script (and it may not even work reliably, depending on circumstances), so it is not implemented in this case
getSunriseAndSunsetTimes(leapYearDataAvailable := true)
{
	Global _dataFileFullNameWithPath, _dataFileRowToSearch, _dataFileSeparator, _dataFileSunriseColumn, _dataFileSunsetColumn, _sunriseTimeInMinutes, _sunsetTimeInMinutes, _sunriseTime, _sunsetTime, _zenithTime, _showNetworkErrors
	
	_sunriseTimeInMinutes := 0
	_sunsetTimeInMinutes := 0
	
	Loop, read, %_dataFileFullNameWithPath%
	{
		If (A_Index <= _dataFileRowToSearch + (leapYearDataAvailable ? 0 : -1))
			Continue
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
		getSunriseAndSunsetTimes(false)
	Else If (!_sunriseTimeInMinutes)
	{
		If (_showNetworkErrors)
			MsgBox, 2 ;MsgBox, No sunset and/or sunrise time found in the %_dataFileFullNameWithPath% file
		ExitApp
	}
	zenithTime := Round((_sunriseTimeInMinutes + _sunsetTimeInMinutes) / 2, 0)
	zenithTimeH := Round(zenithTime // 60, 0)
	_zenithTime := zenithTimeH ":" (zenithTime - zenithTimeH * 60)
} ; end of getSunriseAndSunsetTimes(leapYearDataAvailable := true)


checkFullScreen()
{
	global _lastIsFullscreen
	isFullscreen := isWindowFullScreen("A") 
	if (isFullscreen <> _lastIsFullscreen)
	{
		_lastIsFullscreen := isFullscreen
		main()
	}
	
} ; end checkFullScreen()


main()
{
	Global Monitor, _typeOfCurveLeft, _typeOfCurveRight, _weatherURL, _weatherRegExp, _weatherContrastThresholds, _weatherCheckPeriodInMinutes, _lastWeatherCheckInMinutes, _lastSuccessfulWeatherCheckInMinutes, _lastContrastCoefficietFromWeather, _dataFileRowToSearch, _dataFileHeaderHeight, _sunriseTimeInMinutes, _sunsetTimeInMinutes, _beforeSunriseOrAfterSunsetContrast,_zenithContrast, _сontrastCoefficientInFullscreen, _lastSetContast, _showNetworkErrors
	
	fullscreenContrastCoefficient := isWindowFullScreen("A") ? _сontrastCoefficientInFullscreen : 1
	
	If (_dataFileRowToSearch != _dataFileHeaderHeight + A_YDay)
	{
		_dataFileRowToSearch := _dataFileHeaderHeight + A_YDay
		getSunriseAndSunsetTimes()
		_lastWeatherCheckInMinutes := 0
	}
	currentTimeInMinutes := A_Hour * 60 + A_Min

	makeNewMenu := _lastSetContast ? false : true
	netCurrentTimeInMinutes := currentTimeInMinutes - _sunriseTimeInMinutes ; X
	mean := (_sunsetTimeInMinutes - _sunriseTimeInMinutes) / 2
	normalizedNetCurrentTimeInMinutes := (-mean + netCurrentTimeInMinutes) / mean ; X from -1 to 1
	beforeZenith := netCurrentTimeInMinutes < mean ? true : false

 	If ((currentTimeInMinutes <= _sunriseTimeInMinutes Or currentTimeInMinutes >= _sunsetTimeInMinutes) )
	{
		contrastToSet := Round(fullscreenContrastCoefficient * _beforeSunriseOrAfterSunsetContrast)
		If (_lastSetContast != contrastToSet)
		{
			_lastSetContast := contrastToSet
			Monitor.SetContrast(_lastSetContast)
			makeNewMenu := true
		}
		makeMenu(makeNewMenu, currentTimeInMinutes, beforeZenith)		
		return
	}	
	Else If ((_typeOfCurveLeft = "linear" And beforeZenith) Or (_typeOfCurveRight = "linear" And !beforeZenith))
		contrastCoefficient := (netCurrentTimeInMinutes < mean ? netCurrentTimeInMinutes : (2 * mean - netCurrentTimeInMinutes)) / mean
	If ((_typeOfCurveLeft = "circle" And beforeZenith) Or (_typeOfCurveRight = "circle" And !beforeZenith))
		contrastCoefficient := Sqrt(1 - normalizedNetCurrentTimeInMinutes**2) ; a circle with radius 1 and centre in 0 formula: Y = sqrt(1 - X^2)
	If ((_typeOfCurveLeft = "parabola" And beforeZenith) Or (_typeOfCurveRight = "parabola" And !beforeZenith))
		contrastCoefficient := -normalizedNetCurrentTimeInMinutes **2 + 1 ; upside-down parabola with top at 1 and branched going to -1 and +1 formula: Y = -X^2 + 1
	If ((_typeOfCurveLeft = "Bell" And beforeZenith) Or (_typeOfCurveRight = "Bell" And !beforeZenith))
	{	
		mean := 0 ; redefined for the formula as it requires 0 to be in the middle
		sigma := 0.3
		e := 2.718281828459045
		pi := 3.141592653589793
		contrastCoefficient := (1 / (sigma * Sqrt(2 * pi))) * (e ** (-(normalizedNetCurrentTimeInMinutes - mean)**2/(2 * sigma ** 2))) ; Y - a two-tailed normal distribution curve that goes from -1 to 1 on the X axis and from 0 to about 1.4 on the Y axis when X = 0. Since contrastCoefficient variable has to go only up to 1, the result has to be normalized:
		
		contrastCoefficient := contrastCoefficient / ((1 / (sigma * Sqrt(2 * pi))) * (e ** (-(0 - mean)**2/(2 * sigma ** 2)))) ; the normalization is when X = 0
		
		;MsgBox, % "normalizedNetCurrentTimeInMinutes: " normalizedNetCurrentTimeInMinutes ", mean: " mean ", sigma: " sigma ", contrastCoefficient: " contrastCoefficient
	}	
		
	If (_weatherURL and currentTimeInMinutes > _lastWeatherCheckInMinutes + _weatherCheckPeriodInMinutes)
	{
		_lastWeatherCheckInMinutes := currentTimeInMinutes
		Try
		{
			_lastContrastCoefficietFromWeather := 1
			WinHttpRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
			WinHttpRequest.Open("GET", _weatherURL, true)
			WinHttpRequest.Send() ; Using 'true' above and the call below allows the script to remain responsive.
			WinHttpRequest.WaitForResponse()
				
			RegExMatch(WinHttpRequest.ResponseText, _weatherRegExp, matchedGroups) ; there are will be automaticly generated matchedGroups1, matchedGroups2 ... variables
			;FileAppend,% matchedGroups1 "`n`r" _weatherContrastThresholds[matchedGroups1] "`n`r" WinHttpRequest.ResponseText "`n`r", %A_ScriptDir%\Test.txt
			If (_weatherContrastThresholds[matchedGroups1])
				_lastContrastCoefficietFromWeather := _weatherContrastThresholds[matchedGroups1]
			_lastSuccessfulWeatherCheckInMinutes := currentTimeInMinutes
		}
		catch exc
			If (_showNetworkErrors)
				MsgBox, 3 ; MsgBox, %A_ScriptName%:`n`r`n`r%exc%
	}
		
	_lastSetContast := Round((_beforeSunriseOrAfterSunsetContrast + contrastCoefficient * (_zenithContrast - _beforeSunriseOrAfterSunsetContrast)) * _lastContrastCoefficietFromWeather * fullscreenContrastCoefficient)
	If (Monitor.GetContrast() != _lastSetContast)
	{
		Monitor.SetContrast(_lastSetContast)
		makeNewMenu := true
	}
	makeMenu(makeNewMenu, currentTimeInMinutes, beforeZenith)
} ; end of main()

Menu, Tray, Icon, %_iconFileFullNameWithPath%
Menu, Tray, Add
Menu, Tray, Add, Processing..., HasVal
Menu, Tray, Disable, Processing...
main()
SetTimer, main, %_updateEveryMilliseconds%
SetTimer, checkFullScreen, 50
