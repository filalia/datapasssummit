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

######## Create query to get workspace name ######

$uri = "$rooturl$subscriptionId/resourceGroups/$rgname/providers/Microsoft.Synapse/workspaces/$($wsname)?$apiversion"

$contentType = "application/json" 

$result = Invoke-RestMethod -Method GET -Uri $uri -ContentType $contentType -Headers $headers;

$result |ConvertTo-Json

########### update a property ########

$result.tags = @{"usage"= "Demo"}

$body = $result |ConvertTo-Json

Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headers -body $body;


########### create a linked service to an Azure Key Vault #########
$lkAKVname = "DemoAKV"
$description="This an automated creation "
$annotation="AdventureworksLT"
$baseUrl="https://.vault.azure.net/"

$uri =  "https://$($endpoint).dev.azuresynapse.net/linkedservices/$($lkAKVname)?api-version=2020-12-01"

$body =@{'properties'= @{
                'description'= "$description "
                'annotations'= @(
                    "$annotation"
                )
                "type"= "AzureKeyVault"
                "typeProperties"= @{
                    "baseUrl"= "$baseUrl"
                }
            }} | ConvertTo-Json;

            
$contentType = "application/json" 

$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result

#######  Create linked service Azure DB #######
$DBlinkedservice="LKDBADVW"
$description="This an automated creation "
$annotation="AdventureworksLT"
$dbname="dbtestcandy"
$urldb="serverdbafi.database.windows.net"
$userid="CloudSA8ad6e3a7"
$secretname="dbdemopass"

$uri =  "https://$($endpoint).dev.azuresynapse.net/linkedservices/$($DBlinkedservice)?api-version=2020-12-01"
$body =@{'properties'= @{
                    'description'= "$description "
                    'annotations'= @(
                     "$annotation"
                    )
            "type"= "AzureSqlDatabase"
            "typeProperties"= @{
                
                "connectionString"= "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=$($urldb);Initial Catalog=$($dbname);User ID=$($userid)"
                "password"= @{
                    "type"= "AzureKeyVaultSecret"
                    "store"= @{
                        "referenceName"= "$lkAKVname"
                        "type"= "LinkedServiceReference"
                    }
                    "secretName"= "$secretname"
                }
            }
            "connectVia"= @{
                "referenceName"= "AutoResolveIntegrationRuntime"
                "type"= "IntegrationRuntimeReference"
            }
        }} | ConvertTo-Json;  

$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result


##########################  Create Azure SQL DB Dataset  #########################
$DBDatasetname="AZDBSource"
$description="This an automated creation "
$annotation="AdventureworksLT"
$uri =  "https://$($endpoint).dev.azuresynapse.net/datasets/$($DBDatasetname)?api-version=2020-12-01"

$body =@{'properties'= @{
                        "linkedServiceName"= @{
                            "referenceName"= "$($DBlinkedservice)"
                            "type"= "LinkedServiceReference"
                                            }
                        "parameters"= @{
                            "schema"= @{
                                "type"= "string"
                                    }
                            "table"= @{
                                "type"= "string"
                            }
                        }
                    'description'= "$description "
                    'annotations'= @(
                                    "$annotation"
                                    )
                    "type"= "AzureSqlTable"
                    "schema"= @{}
                    "typeProperties"= @{
                    "schema"= @{
                        "value"= "@dataset().schema"
                        "type"= "Expression"
                    }
                    "table"=  @{
                        "value"= "@dataset().table"
                        "type"= "Expression"
                            }          
                    }
                    }} | ConvertTo-Json -Depth 3;  

                    
$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result

##########################  Create ADLS Linkedservice  #########################
$ADLSLKName= "PassDemoADLS"
$ADLSUrl="https://datapassdemo.dfs.core.windows.net/"
$description="This an automated creation "
$annotation="Demopass ADLS LK"

$uri =  "https://$($endpoint).dev.azuresynapse.net/linkedservices/$($ADLSLKName)?api-version=2020-12-01"

$body = @{
                
                "properties"= @{
                    'description'= "$description "
                    "annotations"= @($annotation)
                    "type"= "AzureBlobFS"
                    "typeProperties"= @{
                        "url"= "$ADLSUrl"
                    }
                    "connectVia"= @{
                        "referenceName"= "AutoResolveIntegrationRuntime"
                        "type"= "IntegrationRuntimeReference"
                    }
                }
            }| ConvertTo-Json

$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result

########  Create ADLS GEN2 Dataset ##########
$ADLSLKName= "PassDemoADLS"
$datasetname="DSADLSTarget"
$ADLSUrl="https://datapassdemo.dfs.core.windows.net/"
$description="This an automated creation "
$annotation="Demopass ADLS DS"

$uri =  "https://$($endpoint).dev.azuresynapse.net/datasets/$($datasetname)?api-version=2020-12-01"

$body = @{"properties"= @{
                "linkedServiceName"= @{
                                    "referenceName"= "$ADLSLKName"
                                    "type"= "LinkedServiceReference"
                                    }
                "parameters"= @{
                    "Directory"= @{
                        "type"= "string"
                    }
                }
                "folder"= @{
                    "name"= "Target"
                }
                "annotations"=@($annotation)
                "description"="$description"
                "type"= "Parquet"
                "typeProperties"= @{
                    "location"= @{
                        "type"= "AzureBlobFSLocation"
                        "folderPath"= @{
                            "value"= "@dataset().Directory"
                            "type"= "Expression"
                        }
                        "fileSystem"= "datapassedemofs"
                    }
                    "compressionCodec"= "snappy"
                }
                "schema"=@()
            }
        }| ConvertTo-Json -Depth 4;  

$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result

############  Pipeline ###########################
$PipelineName= "Extract"
$schema = "SalesLT"
$tables=@("Address" 
            "Product")
$description="This an automated creation "
$annotation="Demopass ADLS DS"
#$TargetDirectory ="@concat('Bronze/',item(),'/',utcnow('yyyy-MM-dd'))"
$TargetDirectory ="@concat('Gold/',item()"


$uri =  "https://$($endpoint).dev.azuresynapse.net/pipelines/$($PipelineName)?api-version=2020-12-01"
$body=@{
    
    "properties"= @{
        "activities"= @(
                        @{
                            "name"= "ForEach Table"
                            "description"= "desc"
                            "type"= "ForEach"
                            "dependsOn"= @()
                            "userProperties"= @()
                            "typeProperties"= @{
                                "items"= @{
                                    "value"= "@variables('sourcetables')"
                                    "type"= "Expression"
                                }
                                "activities"= @(
                                    @{
                                        "name"= "Copy data"
                                        "description"= "desc copy"
                                        "type"= "Copy"
                                        "dependsOn"= @()
                                        "policy"= @{
                                            "timeout"= "0.12:00:00"
                                            "retry"= 0
                                            "retryIntervalInSeconds"= 30
                                            "secureOutput"= $false
                                            "secureInput"= $false
                                        }
                                        "userProperties"= @()
                                        "typeProperties"= @{
                                            "source"= @{
                                                "type"= "AzureSqlSource"
                                                "queryTimeout"= "00:02:00"
                                                "partitionOption"= "None"
                                            }
                                            "sink"= @{
                                                "type"= "ParquetSink"
                                                "storeSettings"= @{
                                                    "type"= "AzureBlobFSWriteSettings"
                                                }
                                                "formatSettings"= @{
                                                    "type"= "ParquetWriteSettings"
                                                }
                                            }
                                            "enableStaging"= $false
                                            "translator"= @{
                                                "type"= "TabularTranslator"
                                                "typeConversion"= $true
                                                "typeConversionSettings"= @{
                                                    "allowDataTruncation"= $true
                                                    "treatBooleanAsNumber"= $false
                                                }
                                            }
                                        }
                                        "inputs"= @(
                                            @{
                                                "referenceName"= "AZDBSource"
                                                "type"= "DatasetReference"
                                                "parameters"= @{
                                                    "table"= @{
                                                        "value"= "@item()"
                                                        "type"= "Expression"
                                                    }
                                                    "schema"= @{
                                                        "value"= "@variables('schema')"
                                                        "type"= "Expression"
                                                    }
                                                }
                                            }
                                        )
                                        "outputs"= @(
                                            @{
                                                "referenceName"= "$datasetname"
                                                "type"= "DatasetReference"
                                                "parameters"= @{
                                                    "Directory"= @{
                                                        "value"= "$TargetDirectory"
                                                        "type"= "Expression"
                                                    }
                                                }
                                            }
                                        )
                                    }
                                )
                            }
                        }
        )
        "variables"= @{
            "sourcetables"= @{
                "type"= "Array"
                "defaultValue"= @(
                    $tables
                )
            }
            "schema"= @{
                "type"= "String"
                "defaultValue"= "$schema"
            }
        }
        "annotations"= @($annotation)
    }
} | ConvertTo-Json -Depth 10


$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result


###################### Update source tables ##############

$PipelineName= "Extract"
$schema = "SalesLT"
$tables=@("Address" 
            "ProductDescription"
            "Product")
$description="This an automated creation "
$annotation="Demopass ADLS DS"

$uri =  "https://$($endpoint).dev.azuresynapse.net/pipelines/$($PipelineName)?api-version=2020-12-01"


$contentType = "application/json" 
$pipeline = Invoke-RestMethod -Method Get -Uri $uri -ContentType $contentType -Headers $headersDataPlane;

$pipeline.properties.variables.sourcetables.defaultValue = $tables

if( -not $pipeline.properties.folder){
    $folder = New-Object -TypeName psobject
    $folder | Add-Member -MemberType NoteProperty -Name name -Value 'Extraction'
    
    $pipeline.properties | Add-Member -NotePropertyName folder -NotePropertyValue $folder
}else{
    $pipeline.properties.folder.name ="Extraction"
}

$body = $pipeline | ConvertTo-Json -Depth 10

$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result

############  Pipeline Data mart ###########################
$PipelineName= "Datamart"
$schema = "DM"
$tables=@("Sales" 
            "Product")
$description="This an automated creation "
$annotation="Demopass ADLS DS"

$TargetDirectory ="@concat('Gold/',item(),'/')"


$uri =  "https://$($endpoint).dev.azuresynapse.net/pipelines/$($PipelineName)?api-version=2020-12-01"
$body=@{
    
    "properties"= @{
        "activities"= @(
                        @{
                            "name"= "ForEach Table"
                            "description"= "desc"
                            "type"= "ForEach"
                            "dependsOn"= @()
                            "userProperties"= @()
                            "typeProperties"= @{
                                "items"= @{
                                    "value"= "@variables('sourcetables')"
                                    "type"= "Expression"
                                }
                                "activities"= @(
                                    @{
                                        "name"= "Copy data"
                                        "description"= "desc copy"
                                        "type"= "Copy"
                                        "dependsOn"= @()
                                        "policy"= @{
                                            "timeout"= "0.12:00:00"
                                            "retry"= 0
                                            "retryIntervalInSeconds"= 30
                                            "secureOutput"= $false
                                            "secureInput"= $false
                                        }
                                        "userProperties"= @()
                                        "typeProperties"= @{
                                            "source"= @{
                                                "type"= "AzureSqlSource"
                                                "queryTimeout"= "00:02:00"
                                                "partitionOption"= "None"
                                            }
                                            "sink"= @{
                                                "type"= "ParquetSink"
                                                "storeSettings"= @{
                                                    "type"= "AzureBlobFSWriteSettings"
                                                }
                                                "formatSettings"= @{
                                                    "type"= "ParquetWriteSettings"
                                                }
                                            }
                                            "enableStaging"= $false
                                            "translator"= @{
                                                "type"= "TabularTranslator"
                                                "typeConversion"= $true
                                                "typeConversionSettings"= @{
                                                    "allowDataTruncation"= $true
                                                    "treatBooleanAsNumber"= $false
                                                }
                                            }
                                        }
                                        "inputs"= @(
                                            @{
                                                "referenceName"= "AZDBSource"
                                                "type"= "DatasetReference"
                                                "parameters"= @{
                                                    "table"= @{
                                                        "value"= "@item()"
                                                        "type"= "Expression"
                                                    }
                                                    "schema"= @{
                                                        "value"= "@variables('schema')"
                                                        "type"= "Expression"
                                                    }
                                                }
                                            }
                                        )
                                        "outputs"= @(
                                            @{
                                                "referenceName"= "$datasetname"
                                                "type"= "DatasetReference"
                                                "parameters"= @{
                                                    "Directory"= @{
                                                        "value"= "$TargetDirectory"
                                                        "type"= "Expression"
                                                    }
                                                }
                                            }
                                        )
                                    }
                                )
                            }
                        }
        )
        "variables"= @{
            "sourcetables"= @{
                "type"= "Array"
                "defaultValue"= @(
                    $tables
                )
            }
            "schema"= @{
                "type"= "String"
                "defaultValue"= "$schema"
            }
        }
        "annotations"= @($annotation)
    }
} | ConvertTo-Json -Depth 10


$contentType = "application/json" 
$result = Invoke-RestMethod -Method PUT -Uri $uri -ContentType $contentType -Headers $headersDataPlane -Body $body;
$result

