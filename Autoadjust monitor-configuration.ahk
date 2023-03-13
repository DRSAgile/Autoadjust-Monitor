; a text file with sunrise and sunset columns (in HH:MM format) for the whole year should be named exactly as this script, though have a different extension
; if the CSV file only has information for 365 days when the current year is a leap one, then the script for the 366th day will again use the information for the 365th day
; https://voshod-solnca.ru/sun/%D1%81%D0%B0%D0%BD%D0%BA%D1%82-%D0%BF%D0%B5%D1%82%D0%B5%D1%80%D0%B1%D1%83%D1%80%D0%B3
Global _dataFileExtension := ".csv"

Global _dataFileSeparator := ";"

Global _dataFileSunriseColumn := 2 ; starting from 1

Global _dataFileSunsetColumn := 4 ; starting from 1

Global _dataFileHeaderHeight := 1 ; starting from 1; to ignore it
Global _beforeSunriseOrAfterSunsetContrast := 17

Global _zenithContrast := 26

Global _сontrastCoefficientInFullscreen := 1.1

Global _updateEveryMilliseconds := 60 * 1000 ; 60 * 1000 = every minute

Global _typeOfCurveArray := ["linear", "circle", "parabola", "Bell"]

Global _typeOfCurveLeft := _typeOfCurveArray[1]

Global _typeOfCurveRight := _typeOfCurveArray[1]

Global _weatherURL := "https://api.openweathermap.org/data/2.5/forecast?lat=&lon=&cnt=1&appid="
; insert after each "=", consecutively, latitude, longitude and the ID you get after registering in the weather service
; &cnt=1 to only include current weather state with no future prognosis; should probably always include API key as there are no open, free of registration or charge weather services left that would allow non-interactive download of a HTML page with the weather data based on coordinates

Global _weatherRegExp := """description"":""(.*?)""" ; to search for data in a weather service response

Global _weatherContrastThresholds := {"clear sky": [1.9, 1.4], "few clouds": [1.3, 1.2], "scattered clouds": [1.1, 1.1]} ; strings are checked to be in the results of RegExp, the coefficients are in [before zenith, after zenith] pairs

Global _weatherCheckPeriodInMinutes := 5 ; weather services may refuse to provide data too often

Global _showNetworkErrors := false
