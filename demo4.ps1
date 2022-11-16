if (Get-Module -ListAvailable -Name az) {
    Write-Host "Module exists"
}else {
    Install-Module -Name az
}
import-module az

#### Connect to Azure 
$tenantId= ""
$Appid=""
$SecureStringPwd = Read-Host -assecurestring "Please enter your password"
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Appid, $SecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

##### Get Token ######
$synapseManagementToken = (Get-AzAccessToken -Resource "https://management.core.windows.net").Token
$headers = @{
    Authorization = "Bearer $synapseManagementToken"
}
$synapseDataPlaneToken = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
$headersDataPlane = @{
    Authorization = "Bearer $synapseDataPlaneToken"
}

########## Endpoint info #####
$rooturl = "https://management.azure.com/subscriptions/"
$subscriptionId=""
$rgname ="PassSummitDemo"
$wsname ="datapassdemo"
$apiversion="api-version=2021-06-01"
$endpoint= ""


########get piplines run #######
$startdate="2022-10-15T00:36:44.3345758Z"
$enddate ="2022-10-17T00:49:48.3686473Z"
$PipelineName ="Extract"

$body = @{
            "lastUpdatedAfter"= "$startdate"
            "lastUpdatedBefore"= "$enddate"
            "filters"= @(
            @{
                "operand"= "PipelineName"
                "operator"= "Equals"
                "values"= @(
                "$PipelineName"
                )
            }
            )
            "orderBy"=@(@{
                "order"="DESC"
                "orderBy"="RunStart"
            }
            )
        } | ConvertTo-Json -Depth 3
   
$uri = "https://$($endpoint).dev.azuresynapse.net/queryPipelineRuns?api-version=2020-12-01"
$contentType = "application/json" 
$result = Invoke-RestMethod -Method POST -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result


############# Get roles ############
$uri = "https://$($endpoint).dev.azuresynapse.net/roleAssignments?api-version=2020-12-01"
$contentType = "application/json" 
$assignements = Invoke-RestMethod -Method GET -Uri $uri -ContentType $contentType -Headers $headersDataPlane;
foreach($assignement in $assignements.value){
    $uri = "https://$($endpoint).dev.azuresynapse.net/roleDefinitions/$($assignement.roleDefinitionId)?api-version=2020-12-01"
    $role = Invoke-RestMethod -Method GET -Uri $uri -ContentType $contentType -Headers $headersDataPlane;
    $assignement.principalId
    $assignement.principalType
    $role.name
    $role.description
}

