# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
 
 $file_path = 'z:\iotdata.csv'

 New-Item -ItemType Directory -Force -Path C:\temp

if (-NOT (test-path $file_path)) {
    echo "id,location,temperature,time,humidity,weight,size,fatcontent,density,defects,plant,belt,station,employee,rating" >> $file_path
} else {
    return
}

function buildString() {
    $sizes = "small","medium","large"
    $levels = "low","medium","high"
    $employees = "101245","208673"
    
    $newString = ''
    $newString += (get-random -Maximum 999999 -Minimum 100000) # id
    $newString += ","
    $newString += "arkansas," # Location
    $newString += (get-random -Maximum 75 -Minimum 50) # Temperature
    $newString += ","
    $newString += (Get-Date -Format "MM/dd/yyyy-HH:mm:ss") # Timestamp
    $newString += ","
    $newString += (get-random -Maximum 50 -Minimum 30) # Humidity
    $newString += ","
    $newString += (get-random -Maximum 40 -Minimum 5) # Weight
    $newString += ","
    $newString += (get-random -InputObject $sizes) # Size
    $newString += ","
    $newString += (get-random -InputObject $levels) # Fat content
    $newString += ","
    $newString += (get-random -InputObject $levels) # Density
    $newString += ","
    $newString += (get-random -Maximum 5 -Minimum 0) # defects
    $newString += ","
    $newString += "plant1," # Plant
    $newString += "4," # Belt
    $newString += "2," # Station
    $newString += (get-random -InputObject $employees) # Employee
    $newString += ","
    $newString += (get-random -Maximum 9 -Minimum 0) # Rating

    return $newString
}

for ($i=0;$i -lt 10;$i++) {
    buildString >> $file_path
    Start-Sleep -Seconds 1
}

C:\temp\set-eol.ps1 -lineEnding unix -file $file_path