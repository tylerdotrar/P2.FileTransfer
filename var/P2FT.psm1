<#
----------------------------------
AUTHOR:  Tyler McCann (@tyler.rar)
----------------------------------
This optional module has been added to expedite the process of loading scripts / repositories
into your PowerShell session via the $PROFILE.  Not necessary, but I figured I'd include it.

The code below is a small function I keep in my $PROFILE to quickly import repos into my
session regardless of my current directory, because I'm lazy. Just add a name and .psm1 path 
to the $Available hashtable for whatever repositories you want quick access to.

To import a module, use:          Import <name>
To hide terminal output, use:     Import <name> -Silent
To list available modules, use:   Import -List


$PROFILE SYNTAX:
------------------------------------------------------------------------------------------------
function Import ($Suite,[switch]$List,[switch]$Silent) {
    $Available = @{
	    'P2FT'     = $env:USERPROFILE + '\Documents\GitHub\P2.FileTransfer\var\P2FT.psm1'
        'Example1' = $env:USERPROFILE + '\Documents\GitHub\Example1\example.psm1'
        'Example2' = $env:USERPROFILE + '\Documents\GitHub\Example2\example.psm1'
    }
    if ($List) {
	    Write-Host "----------`nAvailable:`n----------" -NoNewLine -ForegroundColor Yellow
	    $Available | Select-Object -Property * | Format-List
    }
    elseif ($Suite) {
        foreach ($Option in $Suite) {
            if ($Available.Keys -contains $Option) { 
	    	    Import-Module $Available.$Option -DisableNameChecking
                if (!$Silent) {
	    	        Write-Host 'Successfully Imported: ' -NoNewLine -ForegroundColor Green
	    	        Write-Host "[$($Option.ToUpper())]"
                }
            }
	        else {
                if (!$Silent) {
	                Write-Host 'Unsuccessfully Imported: ' -NoNewLine -ForegroundColor Red
	                Write-Host "[$($Option.ToUpper())]"
                }
	        }
    	}
    }
    else { Write-Host 'No parameter specified.' -ForegroundColor Red }
}
------------------------------------------------------------------------------------------------
#>

. $PSScriptRoot\..\Invoke-FileTransfer.ps1
. $PSScriptRoot\..\Invoke-HybridServer.ps1