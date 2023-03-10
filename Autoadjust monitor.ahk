; By DRSAgile, https://github.com/DRSAgile/Autoadjust-Monitor/

#Persistent
#SingleInstance force
#Include %a_scriptdir%
#Include *i Autoadjust monitor-configuration-%A_Username%.ahk
#include Class_Monitor.ahk ; from  https://github.com/jNizM/Class_Monitor

FileEncoding, UTF-8 ; means UTF-8 specifically with BOM
Global _configurationFileNameWithPath := A_Scriptdir "\Autoadjust monitor-configuration"
If (!_dataFileExtension) ; if the variable is not filled, then the configuration file for a current user does not exist
{
		FileCopy, %_configurationFileNameWithPath%.ahk, %_configurationFileNameWithPath%-%A_Username%.ahk, 1
		Reload
}
_configurationFileNameWithPath := _configurationFileNameWithPath "-" A_Username
Global _dataFileFullNameWithPath := a_scriptdir "\" StrReplace(A_ScriptName, ".ahk", _dataFileExtension)
Global _iconFileFullNameWithPath := a_scriptdir "\" StrReplace(A_ScriptName, ".ahk", ".png")
Global _weatherTypesArray := ["Clear", "Few", "Scattered"]
Global _lastWeatherCheckInMinutes := 0
Global _lastSuccessfulWeatherCheckInMinutes := 0
Global _lastContrastCoefficietFromWeather := [1, 1]
Global _lastCheckedWeather := ""
Global _lastSetContast := 0
Global _dataFileRowToSearch := 0
Global _sunriseTimeInMinutes := 0
Global _sunsetTimeInMinutes := 0
Global _currentTimeInMinutes := 0
Global _afterZenith := false
Global _sunriseTime := ""
Global _sunsetTime := ""
Global _zenithTime := ""
Global _lastIsFullscreen := isWindowFullScreen("A")
Global _unsavedChangesArray := []


arrayToString(arr, separator := ", ")
{
	arrStr := ""
	Loop % arr.Length()
		arrStr .= separator arr[A_Index]
	return LTrim(arrStr, separator)	
} ; end of arrayToString(arr, separator := ", ")

hasVal(haystack, needle)
{
	For index, value In haystack
		If (value = needle)
			return index
	If !IsObject(haystack)
		Throw Exception("Bad haystack!", -1, haystack)
	Return 0
} ; end of hasVal(haystack, needle)


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
processInputBox(ByRef value, typeOfValue, itemOrMenuName, prompt := " ") 
{
	title := StrReplace(itemOrMenuName, ": " value)
	InputBox, newValue, %title%, %prompt%,,,,,,,,%value%
	
	If (ErrorLevel Or newValue == value)
		return false
	Else If (typeOfValue = "IN>0<=100" and !(newValue ~= "^(?:100|)[0-9]{1,2}$"))
		return processInputBox(value, typeOfValue, itemOrMenuName, "The value should be an integer numeric between 0 and 100")
	Else If (typeOfValue = "FN>=1<2" and !(newValue ~= "^(?:1|1\.[0-9]{1,2})$"))
		return processInputBox(value, typeOfValue, itemOrMenuName, "The value should be a floating point numeric between 1 and 2")
	Else
	{
		value := newValue
		firstWord := StrReplace(StrSplit(itemOrMenuName, A_Space)[1], "*", "")
		If (!hasVal(_unsavedChangesArray, firstWord))
			_unsavedChangesArray.push(firstWord)
		return true
	}
} ; end of processInputBox(ByRef value, typeOfValue, itemOrMenuName, prompt := " ") 


; the function can receive additional parameters with statements like this: boundEdit := Func("edit").Bind([vale to pass]) and then using it like "Menu, Tray, Add, Item name, % boundEdit
edit(menuText, ItemName, ItemPos, MenuName)
{	
	callMain := false
	firstWord := StrReplace(StrSplit(menuText ? menuText : ItemName, A_Space)[1], "*")
	If (weatherArrayIndex := hasVal(_weatherTypesArray, firstWord)) ; goes in the beginning of the function's code as submenus contain first words, used in menu names
		For k, v In _weatherContrastThresholds
			If (weatherArrayIndex = A_Index And (value := v[ItemPos]) And (callMain := processInputBox(value, "FN>=1<2", StrReplace(menuText, ":") ItemName)) And (_weatherContrastThresholds[k][ItemPos] := Trim(value, "0")))
				Break
	Else If (InStr(MenuName, "Left") And ItemName != _typeOfCurveLeft)
	{
		_typeOfCurveLeft := ItemName
		If (!hasVal(_unsavedChangesArray, "Up"))
			_unsavedChangesArray.push("Up")		
		callMain := true
	}
	Else If (InStr(MenuName, "Right") And ItemName != _typeOfCurveRight)
	{
		_typeOfCurveRight := ItemName
		If (!hasVal(_unsavedChangesArray, "Down"))
			_unsavedChangesArray.push("Down")		
		callMain := true
	}
	Else If (firstWord = "Before")
		callMain := processInputBox(_beforeSunriseOrAfterSunsetContrast, "IN>0<=100", ItemName)
	Else If (firstWord = "Zenith")
		callMain := processInputBox(_zenithContrast, "IN>0<=100", ItemName)
	Else If (firstWord = "Contrast")
		callMain := processInputBox(_сontrastCoefficientInFullscreen, "FN>=1<2", ItemName)
	If (callMain)
		main(true)		
} ; end of edit(menuText, ItemName, ItemPos, MenuName)


; different menu items are identified by AHK by their text and, additionally in this script, by the first word, hence added menu items can not start with the same words
processMenuItem(str)
{
	return (hasVal(_unsavedChangesArray, StrSplit(str, A_Space)[1]) ? "*" : "") str	
} ; end of processMenuItem(str)


; different menu items are identified by AHK by their text and, additionally in this script, by the first word, hence added menu items can not start with the same words
makeMenu(makeNewMenu := false)
{	
	If (_currentTimeInMinutes)
		outOfDaylight := _currentTimeInMinutes < _sunriseTimeInMinutes Or _currentTimeInMinutes > _sunsetTimeInMinutes ? "none; out of the daylight" : ""
		Menu, Tray, Tip, % "current contrast: " _lastSetContast ",`nactive curve: " (outOfDaylight ? outOfDaylight: (!_afterZenith ? _typeOfCurveLeft : _typeOfCurveRight)) ",`nactive weather coefficient: " (outOfDaylight ? outOfDaylight : _lastContrastCoefficietFromWeather[1 + _afterZenith] (_lastCheckedWeather ? " (" _lastCheckedWeather ")" : ""))
	
	if (!makeNewMenu)
		Return

	bEdit := Func("edit").Bind("")	
	Menu, Tray, DeleteAll	
	Menu, Tray, Add
	Menu, Tray, Add, Save changes, saveChanges
	If (!_unsavedChangesArray.Length())
		Menu, Tray, Disable, Save changes
	Menu, Tray, Add
	Menu, Tray, Add, % processMenuItem("Contrast coefficient in fullscreen mode: " _сontrastCoefficientInFullscreen), % bEdit
	
	menuNamesArray := ["Clear sky contrast coefficient: ", "Few clouds contrast coefficient: ", "Scattered clouds contrast coefficient: "]
	For k, v In _weatherContrastThresholds
	{
		boundEdit := Func("edit").Bind(menuNamesArray[A_Index])
		subMenuName := "WeatherSubmenu" _weatherTypesArray[A_Index]
		Try
			Menu, %subMenuName%, DeleteAll
		vStr := ""
		Loop % v.Length()
		{
			vStr .= ", " v[A_Index]
			Menu, %subMenuName%, Add, % (A_Index = 1 ? "before" : "after") " zenith: " v[A_Index], % boundEdit
		}
		vStr := LTrim(vStr, ", ")
		Menu, Tray, Add, % processMenuItem(menuNamesArray[A_Index] vStr), :%subMenuName%
	}
	For index, element In _typeOfCurveArray
	{
		Menu, typeOfCurveSubmenu_Left, Add, %element%, % bEdit
		If (element = _typeOfCurveLeft)
			Menu, typeOfCurveSubmenu_Left, Check, %element%
		Else
			Menu, typeOfCurveSubmenu_Left, Uncheck, %element%
		Menu, typeOfCurveSubmenu_Right, Add, %element%, % bEdit
		If (element = _typeOfCurveRight)
			Menu, typeOfCurveSubmenu_Right, Check, %element%
		Else
			Menu, typeOfCurveSubmenu_Right, Uncheck, %element%
	}
	Menu, Tray, Add, % processMenuItem("Up to zenith curve for interpolation: " _typeOfCurveLeft), :typeOfCurveSubmenu_Left
	Menu, Tray, Add, % processMenuItem("Down from zenith curve for interpolation: " _typeOfCurveRight), :typeOfCurveSubmenu_Right
	Menu, Tray, Add, % processMenuItem("Before sunrise (" _sunriseTime "), after sunset (" _sunsetTime ") contrast: " _beforeSunriseOrAfterSunsetContrast), % bEdit
	Menu, Tray, Add, % processMenuItem("Zenith (" _zenithTime ") contrast: " _zenithContrast), % bEdit
} ; end of makeMenu(makeNewMenu := false)


saveChanges()
{	
	configuration := ""
	Loop, read, %_configurationFileNameWithPath%.ahk
	{
		processedLine := RegExReplace(A_LoopReadLine, "(_typeOfCurveLeft := _typeOfCurveArray\[).*$", "$1" hasVal(_typeOfCurveArray, _typeOfCurveLeft) "]")		
		processedLine := RegExReplace(processedLine, "(_typeOfCurveRight := _typeOfCurveArray\[).*$", "$1" hasVal(_typeOfCurveArray, _typeOfCurveRight) "]")
		processedLine := RegExReplace(processedLine, "(_zenithContrast :=).*$", "$1 " _zenithContrast) 
		processedLine := RegExReplace(processedLine, "(_beforeSunriseOrAfterSunsetContrast :=).*$", "$1 " _beforeSunriseOrAfterSunsetContrast)
		processedLine := RegExReplace(processedLine, "(_сontrastCoefficientInFullscreen :=).*$", "$1 " _сontrastCoefficientInFullscreen)
		If (InStr(processedLine, "_weatherContrastThresholds"))
			For k, v in _weatherContrastThresholds
				processedLine := RegExReplace(processedLine, "(_weatherContrastThresholds :=\s*?{(?:[^\[]+\[){" A_Index "})[^\]]+(\].+)$", "$1" arrayToString(v) "$2")
		configuration .= processedLine "`n"
	}
	Try
	{
		FileCopy, %_configurationFileNameWithPath%.ahk, %_configurationFileNameWithPath%.bak, 1
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
	zenithTimeM := zenithTime - zenithTimeH * 60
	_zenithTime := zenithTimeH ":" zenithTimeM
	_zenithTimeInMinues := zenithTimeH * 60 + zenithTimeM
} ; end of getSunriseAndSunsetTimes(leapYearDataAvailable := true)


checkFullScreen()
{
	isFullscreen := isWindowFullScreen("A") 
	If (isFullscreen <> _lastIsFullscreen)
	{
		_lastIsFullscreen := isFullscreen
		main()
	}	
} ; end checkFullScreen()


main(makeNewMenu := "")
{
	makeNewMenu := makeNewMenu != "" ? makeNewMenu : (_lastSetContast ? false : true)
	
	fullscreenContrastCoefficient := isWindowFullScreen("A") ? _сontrastCoefficientInFullscreen : 1
	
	If (_dataFileRowToSearch != _dataFileHeaderHeight + A_YDay)
	{
		_dataFileRowToSearch := _dataFileHeaderHeight + A_YDay
		getSunriseAndSunsetTimes()
		_lastWeatherCheckInMinutes := 0
	}
	_currentTimeInMinutes := A_Hour * 60 + A_Min

	net_currentTimeInMinutes := _currentTimeInMinutes - _sunriseTimeInMinutes ; X
	mean := (_sunsetTimeInMinutes - _sunriseTimeInMinutes) / 2
	normalizedNetCurrentTimeInMinutes := (-mean + net_currentTimeInMinutes) / mean ; X from -1 to 1
	_afterZenith := net_currentTimeInMinutes >= mean ? true : false

 	If ((_currentTimeInMinutes <= _sunriseTimeInMinutes Or _currentTimeInMinutes >= _sunsetTimeInMinutes) )
	{
		contrastToSet := Round(fullscreenContrastCoefficient * _beforeSunriseOrAfterSunsetContrast)
		If (_lastSetContast != contrastToSet)
		{
			_lastSetContast := contrastToSet
			Monitor.SetContrast(_lastSetContast)
			makeNewMenu := true
		}
		makeMenu(makeNewMenu)		
		return
	}	
	Else If ((_typeOfCurveLeft = "linear" And !_afterZenith) Or (_typeOfCurveRight = "linear" And _afterZenith))
		contrastCoefficient := (!_afterZenith ? net_currentTimeInMinutes : (2 * mean - net_currentTimeInMinutes)) / mean
	If ((_typeOfCurveLeft = "circle" And !_afterZenith) Or (_typeOfCurveRight = "circle" And _afterZenith))
		contrastCoefficient := Sqrt(1 - normalizedNetCurrentTimeInMinutes**2) ; a circle with radius 1 and centre in 0 formula: Y = sqrt(1 - X^2)
	If ((_typeOfCurveLeft = "parabola" And !_afterZenith) Or (_typeOfCurveRight = "parabola" And _afterZenith))
		contrastCoefficient := -normalizedNetCurrentTimeInMinutes **2 + 1 ; upside-down parabola with top at 1 and branched going to -1 and +1 formula: Y = -X^2 + 1
	If ((_typeOfCurveLeft = "Bell" And !_afterZenith) Or (_typeOfCurveRight = "Bell" And _afterZenith))
	{	
		mean := 0 ; redefined for the formula as it requires 0 to be in the middle
		sigma := 0.3
		e := 2.718281828459045
		pi := 3.141592653589793
		contrastCoefficient := (1 / (sigma * Sqrt(2 * pi))) * (e ** (-(normalizedNetCurrentTimeInMinutes - mean)**2/(2 * sigma ** 2))) ; Y - a two-tailed normal distribution curve that goes from -1 to 1 on the X axis and from 0 to about 1.4 on the Y axis when X = 0. Since contrastCoefficient variable has to go only up to 1, the result has to be normalized:
		
		contrastCoefficient := contrastCoefficient / ((1 / (sigma * Sqrt(2 * pi))) * (e ** (-(0 - mean)**2/(2 * sigma ** 2)))) ; the normalization is when X = 0
	}	
		
	If (_weatherURL and _currentTimeInMinutes > _lastWeatherCheckInMinutes + _weatherCheckPeriodInMinutes)
	{
		_lastWeatherCheckInMinutes := _currentTimeInMinutes
		Try
		{
			_lastContrastCoefficietFromWeather := [1, 1]
			WinHttpRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
			WinHttpRequest.Open("GET", _weatherURL, true)
			WinHttpRequest.Send() ; Using 'true' above and the call below allows the script to remain responsive.
			WinHttpRequest.WaitForResponse()
				
			RegExMatch(WinHttpRequest.ResponseText, _weatherRegExp, matchedGroups) ; there are will be automaticly generated matchedGroups1, matchedGroups2 ... variables
			;FileAppend,% matchedGroups1 "`n`r" _weatherContrastThresholds[matchedGroups1] "`n`r" WinHttpRequest.ResponseText "`n`r", %A_ScriptDir%\Test.txt
			_lastCheckedWeather := matchedGroups1
			If (_weatherContrastThresholds[_lastCheckedWeather])
				_lastContrastCoefficietFromWeather := _weatherContrastThresholds[_lastCheckedWeather]
			_lastSuccessfulWeatherCheckInMinutes := _currentTimeInMinutes
		}
		catch exc
			If ((_lastCheckedWeather := exc) _showNetworkErrors)
				MsgBox, %A_ScriptName%:`n`r`n`r%exc%
	}
	Else If (_weatherContrastThresholds[_lastCheckedWeather] And _lastContrastCoefficietFromWeather != _weatherContrastThresholds[_lastCheckedWeather])
	{
		_lastContrastCoefficietFromWeather := _weatherContrastThresholds[_lastCheckedWeather]
	}
		
	_lastSetContast := Round((_beforeSunriseOrAfterSunsetContrast + contrastCoefficient * (_zenithContrast - _beforeSunriseOrAfterSunsetContrast)) * _lastContrastCoefficietFromWeather[1 + _afterZenith] * fullscreenContrastCoefficient)
	If (Monitor.GetContrast() != _lastSetContast)
	{
		Monitor.SetContrast(_lastSetContast)
		makeNewMenu := true
	}
	makeMenu(makeNewMenu)
} ; end of main(makeNewMenu := "")


Menu, Tray, Icon, %_iconFileFullNameWithPath%
Menu, Tray, Add
Menu, Tray, Add, Processing..., hasVal
Menu, Tray, Disable, Processing...
main()
SetTimer, main, %_updateEveryMilliseconds%
SetTimer, checkFullScreen, 50