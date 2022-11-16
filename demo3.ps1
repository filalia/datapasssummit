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

######### Create SQL Database #######
$Serverinstance = "-ondemand.sql.azuresynapse.net"
$Database ="DataPassDM"

$Query = "    IF NOT EXISTS 
                (SELECT name
                FROM master.sys.databases
                WHERE name = '$Database')
            BEGIN
                CREATE DATABASE $Database ;
                print('Database $Database created')
            END
            else 
                print('Database $Database already exixts')

                                GO "
try{
    $SqlToken = (Get-AzAccessToken -Resource "https://sql.azuresynapse.net").Token
    $result =  Invoke-Sqlcmd -ServerInstance $Serverinstance -Database "master" -AccessToken $SqlToken  -query $Query
    return $result
}catch{
    return $_.Exception.Message

}


######### Create External Data source #######
$ExternalSourceName ="Gold_DM"
$AccountStorageName ="datapassedemofs"
$AccountStorageContaineName = "datapassedemofs"

$Query = " IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = '$ExternalSourceName') 
                                CREATE EXTERNAL DATA SOURCE [$ExternalSourceName] 
                                WITH ( 
                                    LOCATION = 'abfss://$($AccountStorageContaineName)@$($AccountStorageName).dfs.core.windows.net' 
                                ) 
                            GO "
    try{
    $SqlToken = (Get-AzAccessToken -Resource "https://sql.azuresynapse.net").Token
    
    $result =  Invoke-Sqlcmd -ServerInstance $Serverinstance -Database $Database -AccessToken $SqlToken  -query $Query
    return "Query executed with success"
    }catch{
        return $_.Exception.Message

    }
############ Create external File Format ###############

$FileFormat ="PARQUET"

$Query = " IF NOT EXISTS (SELECT * FROM sys.external_file_formats WHERE name = '$($FileFormat)Format') 
                CREATE EXTERNAL FILE FORMAT [$($FileFormat)Format] 
                WITH ( FORMAT_TYPE = $FileFormat) 
            GO "
try{
$SqlToken = (Get-AzAccessToken -Resource "https://sql.azuresynapse.net").Token

$result =  Invoke-Sqlcmd -ServerInstance $Serverinstance -Database $Database -AccessToken $SqlToken  -query $Query
return "Query executed with success"
}catch{
    return $_.Exception.Message

}

########## Create External  table ##################

#### Generate createion script from metadata #####
$path = "C:\Users\abderrahmane.filali\Documents\Projects\Pass Demo\structure.csv"
$Structure = Import-Csv -Path $path -Delimiter ';'
$tablelist 
if (-not $tablename ){
$tablelist = $Structure | Foreach-Object { $_.tableSource } | Select-Object -unique
}else{
    $tablelistwf = $Structure | Foreach-Object { $_.tableSource } | Select-Object -unique 
    
    $tablelist = $tablelistwf | Where-Object {$_  -eq $tablename }
  
}
$types = @{
    string = 'varchar(400)'
    nvarchar = 'varchar(400)'
    int   = 'int'
    bigint  = 'bigint'
    timestamp = 'datetime2(7)'
    boolean ='bit'
    double ='float'
}
$script = ""
foreach ($table in $tablelist) {
        $StructureTable = $Structure | Where-Object {$_.tablesource -eq $table -and $_.CreateinSqlDB -eq 'O' }  
        $script  += " IF exists ( select 1 from INFORMATION_SCHEMA.TABLES where TABLE_NAME ='$table' ) `n Drop EXTERNAL TABLE $table `n GO `n "
        $script  += " CREATE EXTERNAL TABLE $table ( `n"
        foreach($field in $StructureTable){
           
            if($null -ne $types[$field.dataType] ){
                $script  +=$field.field+" "  + $types[$field.dataType]
                if ($field -ne $StructureTable[-1] ){
                    $script  += " , "
                }
            }
            if ($field -eq $StructureTable[-1] ){
                $script  += ") `n"
                $script +="WITH ( `n
                    LOCATION = '$($field.location)',   `n
                    DATA_SOURCE = [$ExternalSourceName],  `n 
                    FILE_FORMAT = [$($FileFormat)Format]   
                        )     ;     `n"
                    }
        }



}
$result =  Invoke-Sqlcmd -ServerInstance $Serverinstance -Database $Database -AccessToken $SqlToken  -query $script
return "Query executed with success"


