param (
$assignmentID,
$creator
)
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
import-module ActiveDirectory

## Declare variables
#Comma separated list of email addresses to send warning to, update this for your organization.
$EmailAddresses = $creatoremail, "user@domain.com", "user2@domain.com"

#Email server, update this for your organization.
$EmailServer = "smtp.emailserver.com"

#Email server port
$EmailPort = "25"

#Email address to use as the sender
$emailsender = "DeploymentWarning@domain.com"

#SCCM Site Code for your SCCM site
$CMSiteCode = "ABC:"

#SCCM Site Server
$SiteServer = "ConfigMgr.domain.com"

#Number of computers to be the warning threshold. If the deployment goes to more than this number of computers/users, warning will be sent
$WarningThreshold = 500

#Parse the value supplied as the creator parameter to determine the name of the user and their email.
$creatorEmail = $Creator.Split("\")
$creatorName = (get-aduser -Identity $creatorEmail[1] -Server $creatorEmail[0] -Properties name | Select-Object -ExpandProperty name)
$creatorEmail = (get-aduser -Identity $creatorEmail[1] -Server $creatorEmail[0] -Properties mail | Select-Object -ExpandProperty mail)

#Switch to the CMSite PSDrive
Set-location $CMSiteCode

#Modify the maximum number of ConfigMgr query results to return, in case you have a very large number of deployments.
Set-CMQueryResultMaximum 5000

$AssignmentUniqueID = $assignmentID
$Deployment = Get-CMDeployment -DeploymentId $AssignmentUniqueID

#Get the application name
$Application = $Deployment.SoftwareName

#Get the config type (required or available)
$DesiredConfigType = $Deployment.DesiredConfigType

#Get the deployment start time
$AvailableTime = Get-CMPackageDeployment -DeploymentId $AssignmentUniqueID
if($AvailableTime.PresentTimeIsGMT -eq $false)
{
$AvailableTime = $AvailableTime.PresentTime
}
else {$AvailableTime = $AvailableTime.tolocaltime()}

#Get the deadline time
$Schedule = (Get-CMPackageDeployment -DeploymentId $AssignmentUniqueID).AssignedSchedule
if ($Schedule.isgmt -eq $false)
{$DeadlineTime = $Schedule.starttime}
else {$DeadlineTime = $schedule.starttime.tolocaltime()}

#Get the comments for the deployment
$Comment = (Get-WmiObject -ComputerName $SiteServer -Namespace Root\SMS\Site_$sitecode -class SMS_Advertisement  -Filter "AdvertisementID = '$($AssignmentUniqueID)'").Comment

#Switch for the desired config (Install or Uninstall)
Switch ($DesiredConfigType)
    {
     1{$DesiredConfigType = "Installed"}
     2{$DesiredConfigType = "Uninstalled"}
    }

#Switch for the deployment intent (Available or Required)
$DeploymentIntent = $Deployment.DeploymentIntent

Switch ($DeploymentIntent)
    {
     1{$DeploymentIntent = "Required"}
     2{$DeploymentIntent = "Available"}
    }
#Get the collection that is targeted
$TargetCollection = $Deployment.CollectionName

#Get the member count of the collection after testing whether it is a user or device collection
$MemberCount = (Get-CMCollection -name "$TargetCollection").MemberCount

If ((Get-CMCollection -Name "$TargetCollection").Collectiontype -eq "1")
    {
        
        $ClientType = "Users"
    }
Else
    {
        $ClientType = "Computers"
    }

If ($MemberCount -ge $WarningThreshold)
    {

        if ($DeploymentIntent -eq "Required")
        {
        Send-MailMessage -SmtpServer $EmailServer -Port $EmailPort -Priority High -From $emailsender -To $EmailAddresses -Subject "Deployment Warning - Required to $MemberCount $clienttype" -Body  "$Application is being $DesiredConfigType on $MemberCount assets in the collection $Targetcollection by user $creatorname.`n`nThe deployment type is $DeploymentIntent and will become available at $AvailableTime Pacific Time and has an install deadline of $DeadlineTime Pacific Time.`n The Assignment ID is $AssignmentUniqueID. The comments on the deployment are: `n $Comment `n `n Documentation for this script is available at: www.configmatt.com"
        }

        elseif ($DeploymentIntent -eq "Available")
        {
        Send-MailMessage -SmtpServer $EmailServer -Port $EmailPort -Priority Low -From $emailsender -To $EmailAddresses -Subject "Deployment Warning - Available to $MemberCount $clienttype" -Body  "$Application is being $DesiredConfigType on $MemberCount assets in the collection $Targetcollection by user $creatorname.`n`nThe deployment type is $DeploymentIntent and will become available at $AvailableTime.`n The Assignment ID is $AssignmentUniqueID. The comments on the deployment are: `n $Comment `n `n Documentation for this script is available at:`n www.configmatt.com"
        }


    } 

