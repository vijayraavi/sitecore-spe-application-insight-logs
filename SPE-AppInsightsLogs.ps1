# Application Insight ID and Keys
$aiAppID = "XXXXXXXXXXXXXXXXXXXXXXXXX" ## REPLACE 
$apikey = "XXXXXXXXXXXXXXXXXXXXXXXXX" ## REPLACE

<#
.SYNOPSIS
	View or download Sitecore logs from via Azure Application Insights  

.DESCRIPTION
	Gets defined roles from Application Insights.
	GUI to select Role, Recency, and Severity.
	Option to view logs in color-coded script output, SPE ListView, or download a raw txt file.

.NOTES
	Replace 'aiAppID' and 'apikey' variables.

.AUTHOR
	Gabe Streza
#>

# API information
$aiApiVersion = "v1"
$apiUrl = "https://api.applicationinsights.io/$($aiApiVersion)/apps/$($aiAppID)"
$UriHeader = @{ 'X-Api-Key' = $apikey }

# Global objects
$script:logs = ""
$script:logArray = @()
$script:queryType = ""

Write-Host "Communicating with Azure Application Insights..." -ForegroundColor Magenta

function Set-PostDialog {
	# Post dialog options - Script View, List View, or Download
	$postRunOptions = Show-ModalDialog -Control "ConfirmChoice" -Parameters @{ btn_0 = "Script View"; btn_1 = "List View"; btn_2 = "Download"; te = "Select how you want to view the results."; cp = "Report Conditions" } -Height 120 -Width 650

	if ($postRunOptions -eq "btn_0") {
		# Should color-coded script results 
		Show-Result -Text -Width 1024 -Height 640
	}
	elseif ($postRunOptions -eq "btn_1") {

		$listView = @()

		if($script:queryType -eq "traces"){
			# Regex pattern to match log level
			$logLevelRegex = "\WWARN\W|\WINFO\W|\WERROR\W|\WAUDIT\W"

			# Process each log entry and sanitize for listView array
			$script:logArray | ForEach-Object {
				# Get the raw date
				$rawDate = $_.log.split(" ")[0]
				
				# Convert the raw date to a datetime object 
				$dateObj = [datetime]($rawDate)

				# Get the log level
				$logLevel = Select-String -InputObject $_.log -Pattern $logLevelRegex -AllMatches | % { $_.Matches } | % { $_.Value } | Select-Object -First 1
				
				# Create the line object
				$lineObj = [pscustomobject]@{ dateObj = $dateObj; loglevel = $logLevel.Trim(' '); logLine = $_.log }

				# Add the line object to the listView array.
				$listView += $lineObj
			}

			# ListView dialog properties
			$tableProps = @{
				InfoTitle = "Azure Application Insight Log Viewer"
				InfoDescription = "View Sitecore logs from PaaS instances."
				PageSize = 100
			}

			# Display ListView with logs
			$listView | Show-ListView @tableProps -Property @{ Label = "Date / Time"; Expression = { $_.dateObj } },
			@{ Label = "Level"; Expression = { $_.loglevel } },
			@{ Label = "Entry"; Expression = { $_.logLine } }

			Close-Window

		}else{
			# Requests
			# Process each request entry and sanitize for listView array
			$script:logArray | ForEach-Object {
				#  Get the raw date
				$rawDate = $_.log[0]
				# Convert the raw date to a datetime object 
				$dateObj = [datetime]($rawDate)

				# Get the request code
				$requestCode = $_.log[1].split(' ')[0]
				
				# Get the request url
				$requestUrl = $_.log[2]
				
				# Get the response code
				$responseCode = $_.log[3]
				
				# Create the line object
				$lineObj = [pscustomobject]@{ dateObj = $dateObj; requestCode = $requestCode.Trim(' /'); requestUrl = $requestUrl; responseCode = $responseCode }
				
				# Add the line object to the listView array.
				$listView += $lineObj
			}

			# ListView dialog properties
			$tableProps = @{
				InfoTitle = "Azure Application Insight Requests Viewer"
				InfoDescription = "View Sitecore requests from PaaS instances."
				PageSize = 100
			}

			# Display ListView with logs
			$listView | Show-ListView @tableProps -Property @{ Label = "Date / Time"; Expression = { $_.dateObj } },
			@{ Label = "Request Code"; Expression = { $_.requestCode } },
			@{ Label = "Request URL"; Expression = { $_.requestUrl } },
			@{ Label = "Response Code"; Expression = { $_.responseCode } }

			Close-Window
		}

	} elseif ($postRunOptions -eq "btn_2") {
		# Download a copy of the script output to a txt file
		$fileDate = $(Get-Date -f "yyyyMMddThhmmssZ")
		$logName = "$($script:queryType)-$($fileDate).txt"
		Out-Download -InputObject $script:logs -ContentType "text" -Name $logName > $null

	}else{
		# No user action
		Write-Host "Exiting..." -ForegroundColor Yellow
	}
}

function Get-LogsOrRequests {
	[CmdletBinding()]
	param(
        [Parameter(Mandatory = $true)]
		[string]$QueryType,
        
		[Parameter(Mandatory = $true)]
		[string]$Role,

		[Parameter(Mandatory = $true)]
		[string]$Recency,

		[Parameter(Mandatory = $true)]
		[string[]]$Severity,

		[Parameter(Mandatory = $true)]
		[string]$Limit
	)

	try
	{
		$queryType = $QueryType 
		$script:queryType = $QueryType 

		
		$rolesForQueryPrefix = " | where tostring(customDimensions.Role) == '$Role'"
		$additional = ""

		if($QueryType -eq "requests"){

			$queryType += $rolesForQueryPrefix
			$queryType += " | where substring(resultCode,0,1) == '1' or substring(resultCode,0,1) == '2' or substring(resultCode,0,1) == '3' or substring(resultCode,0,1) == '4' or substring(resultCode,0,1) == '5'"
			$additional = " | project timestamp, name, url, resultCode, duration"

		}elseif($QueryType -eq "traces"){
            
            $SeverityQuery = ""
			# 0 = Infos
			# 1 = Warnings
            # 2 = Errors
            
            if($Severity.Count -eq 3){
                $SeverityQuery = " | where severityLevel == '3' or severityLevel == '2' or severityLevel == '1' or severityLevel == '0'"
            }
            else{

                $Severity | ForEach-Object { 
                 $SeverityQuery = " | where"
                    if($_ -eq "0"){
                        $SeverityQuery += " or severityLevel == '1' or severityLevel == '0' "
                    }elseif($_ -eq "1"){
                        $SeverityQuery += " or severityLevel == '2' "
                    }elseif($_ -eq "2"){
                        $SeverityQuery += " or severityLevel == '3'  or severityLevel == '4' "
                    }
                }
                $SeverityQuery = $SeverityQuery -Replace "where or", "where"
            }

			$queryType += $SeverityQuery
			$queryType += $rolesForQueryPrefix
			$additional = " | project timestamp, message"

		}
		
		$defaultRecency = " | where timestamp > now(-$Recency)"
        $sort = " | sort by timestamp desc"
        if($Limit -eq "0"){
            $limit = "" 
        }else{
            $limit = " | limit $Limit" 
        }
		
		$query = "/query?query=$($QueryType)$($defaultRecency)$($sort)$($additional)$($limit)"

        Write-Host "API URL: " $apiUrl$($query)
		# Call the API to get the logs
		$result = Invoke-WebRequest `
 			-Method Get `
 			-ContentType:"application/json" `
 			-Headers $UriHeader `
 			-UseBasicParsing `
 			-Uri $apiUrl$($query) | Select-Object -Expand Content | ConvertFrom-Json

		# Process each log/request entry and color code them within the host
		$result.tables.rows | ForEach-Object {
			if ($_ -match "error") {
				Write-Host $_ -ForegroundColor Red
				Write-Host
			}
			elseif ($_ -match "warn")
			{
				Write-Host $_ -ForegroundColor Yellow
				Write-Host
			} else {
				Write-Host $_ -ForegroundColor Green
				Write-Host
			}
			
			# Add to global object for script view output 
			$script:logs += "$_ `n `n"

			# Define a new line object with each object
			$lineObj = [pscustomobject]@{ log = $_ }

			# Add the line object to the global array for ListView.
			$script:logArray += $lineObj

		}
	}
	catch [System.Net.WebException]
	{
		# An error occured calling the API
		Write-Host 'Error getting Roles from Application Insights.' -ForegroundColor Red
		Write-Host $Error[0] -ForegroundColor Red
		return $null
	}

	Set-PostDialog

}

function Get-AppInsightRoles {
	# Standard query to retrieve Roles from Application Insights
	$rolesUrl = "$apiUrl/query?query=traces | where timestamp > now(-5d) | distinct tostring(customDimensions.Role)"

    try{
	# Call the API to get the roles
	$rolesResult = Invoke-WebRequest `
 		-Method Get `
 		-ContentType:"application/json" `
 		-Headers $UriHeader `
 		-UseBasicParsing `
         -Uri $rolesUrl | Select-Object -Expand Content | ConvertFrom-Json
         
        }
        catch [System.Net.WebException]
        {
            # An error occured calling the API
            Write-Host 'Error getting Roles from Application Insights.' -ForegroundColor Red
            Write-Host $Error[0] -ForegroundColor Red
            return $null
        }

	# Add roles to an array and retun it
	$rolesList = New-Object System.Collections.ArrayList
	$rolesResult.tables.rows | ForEach-Object { $rolesList.Add($_) > $null }
	$rolesList
}

function Set-Dialog {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.ArrayList]$RolesList
	)

    # Query Type options
    $queryTypeOptions = [ordered]@{ "Logs" = "traces"; "Requests" = "requests" }

	# Recency options
	$recencyOptions = [ordered]@{ "1 hour" = "1h"; "5 hours" = "5h"; "1 day" = "1d"; "3 days" = "3d"; "7 days" = "7d"; "30 days" = "30d"; }

	# Severity options
    $severityOptions = [ordered]@{ "Infos" = "0"; "Warnings" = "1"; "Errors" = "2"; }

	# Role options from RolesList array
	$roleOptions = New-Object System.Collections.Specialized.OrderedDictionary
	for ($i = 0; $i -lt $RolesList.Count; $i++) {
		$roleOptions.Add($($RolesList[$i]),$($RolesList[$i]))
	}

	# Dialog properties
	$props = @{
		Parameters = @(
			@{ Name = "selectedQueryType"; Value = "traces";  Title = "Query"; Options = $queryTypeOptions; editor = "radio"},
            @{ Name = "selectedSeverity"; Title = "Severity (Logs)"; Value = "0|1|2"; Options = $severityOptions; editor = "check";  Height= "130"},
			@{ Name = "selectedRoleOption"; Value = "$($roleOptions[0])"; Title = "Role"; Options = $roleOptions; editor = "radio"; Columns = "6"; Height= "115" },
			@{ Name = "selectedRecency"; Value = "1h"; Title = "Recency"; Options = $recencyOptions; editor = "radio"; Columns = "6";  },
			@{ Name = "selectedLogLimit"; Title = "Log Limit"; Value = "100"; editor = "number"; Mandatory = $true } 
		)
		Title = "Azure Application Insight Log Viewer"
		Description = "Select options to view Sitecore logs from PaaS instances."
		Icon = "/~/icon/people/32x32/chrystal_ball.png"
		Width = 475
		Height = 300
		ShowHints = $true
	}
	
	# Display dialog options and wait for user input
	$result = Read-Variable @props 

	if($result -ne "cancel"){
		Write-Host "Getting logs..." -ForegroundColor Green

        if($selectedSeverity.Count -eq 0){
            $selectedSeverity = "0","1","2"
        }

		# Call Get-LogsOrRequests function - passing in selected options.
		Get-LogsOrRequests -QueryType $selectedQueryType -Role $selectedRoleOption -Recency $selectedRecency -Severity $selectedSeverity -Limit $selectedLogLimit

	}else{
		Write-Host "Exiting..." -ForegroundColor Yellow
	}
}

if([string]::IsNullOrEmpty($aiAppID) -or ($aiAppID -eq "XXXXXXXXXXXXXXXXXXXXXXXXX")){
	Write-Host "Please configure APPLICATION ID in the script." -ForegroundColor Red
	Exit
}
elseif([string]::IsNullOrEmpty($apikey) -or ($apikey -eq "XXXXXXXXXXXXXXXXXXXXXXXXX")){
	Write-Host "Please configure API KEY in the script." -ForegroundColor Red
	Exit
}

# Get Roles from AppInsights
$roles = Get-AppInsightRoles

# Set the dialog options - passing in selected roles
Set-Dialog -RolesList $roles