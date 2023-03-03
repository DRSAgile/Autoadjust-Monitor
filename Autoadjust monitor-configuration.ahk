; a text file with sunrise and sunset columns (in HH:MM format) for the whole year should be named exactly as this script, though have a different extension
; if the CSV file only has information for 365 days when the current year is a leap one, then the script for the 366th day will again use information for the 365th day
; https://voshod-solnca.ru/sun/%D1%81%D0%B0%D0%BD%D0%BA%D1%82-%D0%BF%D0%B5%D1%82%D0%B5%D1%80%D0%B1%D1%83%D1%80%D0%B3
_dataFileExtension := ".csv"
_dataFileSeparator := ";"
_dataFileSunriseColumn := 2 ; starting from 1
_dataFileSunsetColumn := 4 ; starting from 1
_dataFileHeaderHeight := 1 ; starting from 1; to ignore it
_beforeSunriseOrAfterSunsetContrast := 17
_zenithContrast := 27
_updateEveryMilliseconds := 60 * 1000 ; 60 * 1000 = every minute
_typeOfCurve := ["linear", "circle", "parabola", "Bell"][2] ; starting from 1
_weatherURL := "https://api.openweathermap.org/data/2.5/forecast?lat=59.960481&lon=30.294613&cnt=1&appid=" ; &cnt=1 to only include current weather state with no future prognosis; should probably always include API key as there are no open, free of registration or charge weather services left that would allow non-interactive download of a HTML page with the weather data based on coordinates
_weatherRegExp := """description"":""(.*?)"""
_weatherContrastThresholds := {"clear sky": 1.5, "few clouds": 1.25} ; strings are checked to be in the results of RegExp
_weatherCheckPeriodInMinutes := 5 ; weather services may refuse to provide data too often
_showNetworkErrors := false
