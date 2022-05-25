# TCERT-Cumulonimbus-UAL_Extractor
Cumulonimbus-UAL_Extractor is a PowerShell based script created by the Tesorion CERT team to help gather the Unified Audit Log of a Microsoft 365 environment.

This script was inspired by the Office-365-Extractor project of Joey Rentenaar and Korstiaan Stam:
- https://github.com/JoeyRentenaar/Office-365-Extractor

## Getting started
- Clone this repository onto a Windows machine with the possibility to run PowerShell scripts
- Run the 1-install_requirements.ps1 script to install the required dependencies
- Verify the Unified Audit Log is enabled
- Make sure you the Powershell ExecutionPolicy is set to “Unrestricted”:
> Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
- Microsoft 365 account with the required privileges, see below:

In order to use the Unified Audit Log, an account is required to be assigned the View-Only Audit Logs or Audit Logs role. By default, these roles are assigned to the Compliance Management and Organization Management role groups. Global administrators are automatically added as members of the Organization Management role group.

To run the script with the minimum level of privileges, a custom role group can be created with the Audit Logs role.

## Usage
Install the ExchangeOnlineManagement module with PowerShell:
> .\1-install_requirements.ps1

Run the script with PowerShell:
> .\2-Get-AuditData.ps1

Once done, disconnect the session:
> .\3-disconnect.ps1

## Parameters
The following parameters are supported by the script.

-StartDate (optional)
- The StartDate parameter specifies the start date of the date range for the acquisition.
<br>Default: Today -90 days

-EndDate (optional)
- The EndDate parameter specifies the end date of the date range for the acquisition.
<br>Default: Today

-IntervalMinutes (optional)
- The IntervalMinutes parameter specifies the interval in which the logs are being gathered.
<br>Default: 720 minutes, which is 12 hours

-UserIds (optional)
- The UserIds parameter filters the Unified Audit Log on the provided account(s). If providing multiple user accounts, make sure to put them between quotes.
<br>Default: By default, the Unified Audit Log for all users will be acquired

## Example
Running the script without any parameters will gather the Unified Audit Logs for the last 90 days for all user accounts:
> .\2-Get-AuditData.ps1

The following example will gather the Unified Audit Log between the 26th of February and the 26th of April for 3 user accounts with an interval of 12 hours.
> .\2-Get-AuditData.ps1 -StartDate 02/26/2022 -EndDate 04/26/2022 -IntervalMinutes 720 
-UserIds "account1@company.onmicrosoft.com, account2@company.onmicrosoft.com,account3@company.onmicrosoft.com"

The following example will gather the Unified Audit Log for the last 90 days for a specific user account:
> .\2-Get-AuditData.ps1 -UserIds account1@company.onmicrosoft.com

## Behaviour
- The script will write the Unified Audit Log output to the output folder located in the root of the repository. A new folder is created every time the script is executed. The name of the folder includes the execution timestamp. The script will create a new JSON file for every time interval gathered.
  - A log file called “Logfile.txt” of the console logging is maintained and stored.
  - An audit file called “AuditFile.csv” is maintained keeping track of the following properties of each Unified Audit Log output file:
    - start date
    - end date
    - number of stored events
- The script will download the full Unified Audit Log in blocks of a maximum 1000 records at a time. To guarantee all data is downloaded the script uses a retry counter. If no logs are found in the time window the script will try again. However, after three times the script will move to the next time window.
- The interval is lowered automatically if more than 50.000 records are returned for a given time interval. After gathering the logging of the specific interval, the interval will be reset to the provided interval (default 720 minutes).

## Logstash parser example
A Logstash pipeline configuration and Elasticsearch template file are provided as a start for ingesting the JSON data produced by the script into Elasticsearch for analysis.
