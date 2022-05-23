param
(
[Parameter(Mandatory = $False)]
[datetime]$StartDate = $(Get-Date).AddDays(-89),
#[datetime]$StartDate = "2/1/2021 00:00:00",

[Parameter(Mandatory = $False)]
[datetime]$EndDate = $(Get-Date),
#[datetime]$EndDate = "3/1/2021 00:00:00",

[Parameter(Mandatory = $False)]
[int]$IntervalMinutes = 720,

[Parameter(Mandatory = $False)]
[string[]]$UserIds = "*"
)

. "$PSScriptRoot\..\Functions\Get-Timestamp.ps1"
. "$PSScriptRoot\..\Functions\Write-log.ps1"

$logo = @'


        __ _.--..--._ _
     .-' _/   _/\_   \_'-.               /$$$$$$$$       /$$$$$$  /$$$$$$$$ /$$$$$$$  /$$$$$$$$
    |__ /   _/\__/\_   \__|             |__  $$__/      /$$__  $$| $$_____/| $$__  $$|__  $$__/
       |___/\_\__/  \___|                  | $$        | $$  \__/| $$      | $$  \ $$   | $$   
              \__/                         | $$ /$$$$$$| $$      | $$$$$   | $$$$$$$/   | $$   
              \__/                         | $$|______/| $$      | $$__/   | $$__  $$   | $$   
               \__/                        | $$        | $$    $$| $$      | $$  \ $$   | $$   
                \__/                       | $$        |  $$$$$$/| $$$$$$$$| $$  | $$   | $$   
             ____\__/___                   |__/         \______/ |________/|__/  |__/   |__/   
       . - '             ' -.       
      /                      \      
~~~~~~~  ~~~~~ ~~~~~  ~~~ ~~~  ~~~~~ ~~~~~~~  ~~~~~ ~~~~~  ~~~  ~~~  ~~~~~ ~~~~~~~  ~~~~

'@

$logo

$tmpIntervalMinutes = $IntervalMinutes
$CurrentStart       = $StartDate
$CurrentEnd         = $StartDate.AddMinutes($IntervalMinutes)
$SessionIDBase      = "UAL-"
$SessionIDStr       = $CurrentStart.ToString("yyyyMMddHHmmss")
$CurrentSessID      = $SessionIDBase + $SessionIDStr
$OutputDir          = "Output-" + $(Get-Date -Format "yyyyMMddHHmmss")
$OutputLog          = "./$OutputDir/Logfile.txt"
$AuditFile          = "./$OutputDir/AuditFile.csv"
$RetryCounter		= 0

New-Item -Name $OutputDir -ItemType "directory" | Out-Null
New-Item -Name "$OutputDir/Failed" -ItemType "directory" | Out-Null
Write-Log -Message "Create output directory" -Severity Info

$Sessions    = Get-PSSession | Select-Object -Property Name, State
If (-not ($Sessions.Name -like 'ExchangeOnlineInternalSession*' -and  $Sessions.State -eq 'Opened'))
{
	Write-Log -Message "No active session found. Establishing new session with Exchange Online..." -Severity Info
	write-Host ""
	if (-not $Sessions -eq $null)
	{
		Disconnect-ExchangeOnline -Confirm:$false
	}
	Connect-ExchangeOnline -Showbanner:$false -ShowProgress:$true
}
Else
{
	Write-Log -Message "Current active sessions:" -Severity Info
	Write-Log -Message $Sessions -Severity Info
	write-Host ""
}

$ExpectedResultsCount = Search-UnifiedAuditLog -UserIds $UserIds -StartDate $StartDate -EndDate $EndDate -ResultSize 1 | Select-Object -ExpandProperty ResultCount

Write-Log -Message "Logs will be downloaded between $StartDate and $EndDate" -Severity Info
Write-Log -Message "The default download interval in minutes is: $IntervalMinutes" -Severity Info
Write-Log -Message "A total of $ExpectedResultsCount logs have been found between $StartDate & $Enddate" -Severity Info

function NextTimeWindow
{
		$AuditData = [PsCustomObject]@{
			Timestamp = Get-Timestamp
			StatDate = $CurrentStart
			EndDate = $CurrentEnd
			Filename = "./$OutputDir/$CurrentSessID.json"
			ResultCount = $ResultCount
		}
		$AuditData | Export-Csv -Append -Path $AuditFile
		
        If ($tmpIntervalMinutes -lt $IntervalMinutes)
        {
           Write-Log -Message "Resetting the interval minutes to the default of $IntervalMinutes minutes." -Severity Rst
           $script:tmpIntervalMinutes = $IntervalMinutes
        }
        
        $script:CurrentStart	= $CurrentEnd
        $script:CurrentEnd		= $CurrentStart.AddMinutes($IntervalMinutes)
		
        $script:SessionIDStr	= $CurrentStart.ToString("yyyyMMddHHmmss")
        $script:CurrentSessID	= $SessionIDBase + $SessionIDStr
		
		$script:RetryCounter	= 0
}

while ($CurrentStart -lt $EndDate)
{
    Write-Log -Message "The current session id is: $CurrentSessID, the log contains results between $CurrentStart and $CurrentEnd" -Severity Info

    $currentExpectedCount = Search-UnifiedAuditLog -UserIds $UserIds -StartDate $CurrentStart -EndDate $CurrentEnd -ResultSize 1 | Select-Object -First 1 -ExpandProperty ResultCount
	If ($currentExpectedCount -eq $null)
	{
		$currentExpectedCount = 0
	}
	
	Write-Log -Message "A total of $CurrentExpectedCount logs are expected for $CurrentSessID" -Severity Info
	
	If ($CurrentExpectedCount -eq 0 -and $RetryCounter -lt 3)
	{
		$RetryCounter = $RetryCounter + 1 
		Write-Log -Message "ExpectedCount is NULL or 0, sleep for 5 sec before retry. RetryCounter: $RetryCounter" -Severity Warn
		Start-Sleep -s 5		
	}
	ElseIf ($RetryCounter -ge 3)
	{
		Write-Log -Message "No results for the given period, moving on." -Severity Warn
		$ResultCount = 0
		NextTimeWindow		
	}
    ElseIf ($currentExpectedCount -gt 50000)
    {
	    $tmpIntervalMinutes = [math]::Round($tmpIntervalMinutes/($currentExpectedCount/40000))
	    $CurrentEnd      = $CurrentStart.AddMinutes($tmpIntervalMinutes)
	    Write-Log -Message "More than 50000 results found. Temporarily lowering interval to: $tmpIntervalMinutes minutes" -Severity Upd
	    If ($tmpIntervalMinutes -eq 0)
	    {
            Write-Log -Message "Too many results, interval minutes has reached zero." -Severity Err
		    Throw "IntervalMinutes is Zero"
	    }
    }
    Else
    {
		$RetryCounter	 = 0
		$PrevResultIndex = 0
		
	    Do
        {
		    Write-Log -Message "Searching Unified AuditLog.." -Severity Info
		    $AuditSearch = Search-UnifiedAuditLog -UserIds $UserIds -StartDate $CurrentStart -EndDate $CurrentEnd -SessionID $CurrentSessID -SessionCommand ReturnLargeSet -Resultsize 1000
			If (($AuditSearch -ne $null) -and ($AuditSearch.ResultIndex[-1] -ne $null) -and ($AuditSearch.ResultIndex[-1] -ne $null) -and ($AuditSearch.ResultIndex[-1] -gt $PrevResultIndex))
			{
				Write-Log -Message "Expanding AuditData.." -Severity Info
				$AuditData = $Auditsearch | Select-Object -ExpandProperty AuditData
				
				Write-Log -Message "Appending AuditData to $CurrentSessId.json" -Severity Info
				$AuditData | Out-File -Append -Encoding ASCII ./$OutputDir/$CurrentSessID.json
				
				$PrevResultIndex = $AuditSearch.ResultIndex[-1]
				
				Write-Log -Message "The current ResultIndex: $($AuditSearch.ResultIndex[-1]) / ResultCount: $($AuditSearch.ResultCount[-1])" -Severity Info
			}
			Else
			{
				$RetryCounter = $RetryCounter + 1
				
				Write-Log -Message "Something went wrong while downloading the next page. File $CurrentSessID.json might be incomplete." -Severity Err
				
				If ($AuditSearch -ne $null)
				{
					Write-Log -Message "The current ResultIndex: $($AuditSearch.ResultIndex[-1])" -Severity Err
					Write-Log -Message "The current ResultCount: $($AuditSearch.ResultCount[-1])" -Severity Err
					Write-Log -Message "The PrevResultIndex: $PrevResultIndex" -Severity Err
				}
				Else
				{
					Write-Log -Message "Search-UnifiedAuditLog returned NULL." -Severity Info
				}
				
				Get-Pssession | Select-Object -Property Name, State
				Write-Log -Message "Sleep 10s before we try the download again" -Severity Info
				Start-Sleep -s 10
				
				Write-Log -Message "RetryCounter: $RetryCounter" -Severity Info
				
				If (Test-Path -Path "./$OutputDir/$CurrentSessID.json")
				{
					Move-Item -Path "./$OutputDir/$CurrentSessID.json" -Destination "./$OutputDir/Failed/$CurrentSessID.json"
				}

				$CurrentSessID = $SessionIDBase + $SessionIDStr + "-" + $RetryCounter
				$PrevResultIndex = 0
			}
	    }
	    Until(($AuditSearch -ne $null) -and ($AuditSearch.ResultIndex[-1] -ge $AuditSearch.ResultCount[-1]))
		
		$ResultCount = $AuditSearch.ResultCount[-1]
		NextTimeWindow
		
    }
    Write-Host ""
}

Write-Host ""
Write-Log -Message "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -Severity Upd
Write-Log -Message "Finished. Don't forget to disconnect the PSSession using ./3-disconnect.ps1 if it's no longer needed." -Severity Warn
Write-Log -Message "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -Severity Upd
