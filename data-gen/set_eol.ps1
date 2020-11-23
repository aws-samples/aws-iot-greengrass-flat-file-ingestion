# Source: https://ss64.com/ps/syntax-set-eol.html

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
    [ValidateSet("mac","unix","win")] 
    [string]$lineEnding,
  [Parameter(Mandatory=$True)]
    [string]$file
)

# Convert the friendly name into a PowerShell EOL character
Switch ($lineEnding) {
  "mac"  { $eol="`r" }
  "unix" { $eol="`n" }
  "win"  { $eol="`r`n" }
} 

# Replace CR+LF with LF
$text = [IO.File]::ReadAllText($file) -replace "`r`n", "`n"
[IO.File]::WriteAllText($file, $text)

# Replace CR with LF
$text = [IO.File]::ReadAllText($file) -replace "`r", "`n"
[IO.File]::WriteAllText($file, $text)

#  At this point all line-endings should be LF.

# Replace LF with intended EOL char
if ($eol -ne "`n") {
  $text = [IO.File]::ReadAllText($file) -replace "`n", $eol
  [IO.File]::WriteAllText($file, $text)
}
Echo "   ** Completed **" 

