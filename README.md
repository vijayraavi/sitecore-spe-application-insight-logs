# Sitecore Application Insights: Logs and Requests Viewer using SPE

![`SPE-AppInsightsLogs.ps1`](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/spe-ai-demo.gif?raw=true)

## Installation
### Sitecore Package
 - Download and install the Sitecore package. 
 
 - Open the ***/sitecore/system/Modules/PowerShell/Script Library/Azure Application Insights Logs/Toolbox/Azure Application Insights Logs*** script and modify the **App ID** and **Key** variables. 
![`SPE Module`](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/contenteditor.png?raw=true)


### Manual
 - Copy the .ps1 script. (Modify the **App ID** and **Key** variables) 
 - Create a new SPE module (Toolbox).  Add the **PowerShell** script

## Usage
 Select Azure Application Insights from the Toolbox

!['Tool'](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/startmenu.png?raw=true)

Configure your options

![`Options`](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/main.png?raw=true)

Select how you want to view the results

![`Report Conditions`](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/results-1.png?raw=true)

Script view shows color-coded results

![`Script View`](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/results-2.png?raw=true)

ListView shows results in standard SPE ListView

![`List View`](https://github.com/strezag/sitecore-spe-application-insight-logs/blob/master/images/results-3.png?raw=true)
