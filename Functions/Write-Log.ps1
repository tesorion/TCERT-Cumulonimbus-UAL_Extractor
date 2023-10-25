function Write-Log 
{
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
 
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Info','Warn','Err','Upd','Rst')]
        [string]$Severity = 'Info'
    )
    
        $Time = Get-Timestamp

        if ($Severity -eq 'Info') 
        {
            Write-Host "[$Time] $($Severity.ToUpper()): $Message" -ForegroundColor Cyan
        }
        elseif ($Severity -eq 'Warn') 
        {
            Write-Host "[$Time] $($Severity.ToUpper()): $Message" -ForegroundColor Yellow
        }
        elseif ($Severity -eq 'Err')
        {
            Write-Host "[$Time] $($Severity.ToUpper()): $Message" -ForegroundColor Red
        }
        elseif ($Severity -eq 'Upd')
        {
            Write-Host "[$Time] $($Severity.ToUpper()): $Message" -ForegroundColor Magenta
        }
        elseif ($Severity -eq 'Rst')
        {
            Write-Host "[$Time] $($Severity.ToUpper()): $Message" -ForegroundColor Green
        }

        Write-Output "[$Time] $($Severity.ToUpper()): $Message" | Out-file $OutputLog -append
}