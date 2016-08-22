name 'Plugin - AzureRM ARM Template API Functions'
rs_ca_ver 20160622
short_description "Functions for launching and managing ARM Template launches via ARM API"

package "plugin/arm_template"

import "common/functions"
import "plugin/arm_common"

define launch_arm_template($resource_group, $arm_deployment_name, $access_token) return $website_name, $db_server_name, $db_name do

  call arm_common.build_api_url_base() retrieve $api_url_base
  $arm_launch_uri = $api_url_base + "/resourceGroups/" + $resource_group + "/providers/microsoft.resources/deployments/" + $arm_deployment_name + "?api-version=2016-02-01"

  # Currently I'm using in-line template in the request. For one I couldn't get it to work with the stored template approach and didn't want to spend too much time figuring out why.
  # Also, this does let me tinker a bit with the values based on user inputs.
  # However, the right answer is to store the main body of the template somewhere and link to it (i.e. use templateLink in the body) and only use in-line specification for the parameters 
  call build_arm_template_launch_body() retrieve $arm_template_launch_body, $website_name, $db_server_name, $db_name

  # Launch the template
  $response = http_put(
    url: $arm_launch_uri,
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/json",
      "authorization": "Bearer " + $access_token
    },
    body: $arm_template_launch_body
  )
  
  call functions.log("ARM Template Launch Response", to_s($response))
     
  $deployment_not_ready = true
  while $deployment_not_ready do
    # Now wait until it has launched
    sleep(30)
    
    $response = http_get(    
      url: $arm_launch_uri,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      }
    )
    
    call functions.log("Deployment Status", to_s($response))

    $deployment_not_ready = logic_not(equals?($response["body"]["properties"]["provisioningState"], "Succeeded"))
  end

end

# Build the message body with an in-line ARM template and applicable parameters.
define build_arm_template_launch_body() return $arm_template_launch_body, $website_name, $db_server_name, $db_name do
  
  $deployment_id = last(split(@@deployment.href,"/"))
  $website_name = "website-" + $deployment_id
  $db_server_name = "sqlsrvr-" + $deployment_id
  $db_name = "sqldb-" + $deployment_id
  $hostingplan_name = "hostingplan-" + $deployment_id
  $appinsights_name = "appinsights-" + $deployment_id
  
  call get_arm_template($hostingplan_name, $website_name, $db_server_name, $appinsights_name) retrieve $arm_template
  
  $arm_template_launch_body = {
  "properties": {
    "template": $arm_template,
    "mode": "Incremental",
    "parameters": {
         "skuName": {
          "value": "F1"  # Free tier.
        },
        "skuCapacity": {
          "value": 1
        },
        "administratorLogin": {
          "value": "dbAdmin"
        },
        "administratorLoginPassword": {
          "value": "My419Pa55#1"
        },
        "databaseName": {
          "value": "pftexampledb"
        },
        "collation": {
          "value": "SQL_Latin1_General_CP1_CI_AS"
        },
        "edition": {
          "value": "Basic"
        },
        "maxSizeBytes": {
          "value": "1073741824"
        },
        "requestedServiceObjectiveName": {
          "value": "Basic"
        }
      },
      "debugSetting": {
        "detailLevel": "requestContent, responseContent"
      }
    }
  }
end

# Builds an in-line ARM template for launching.
# Could also reference an ARM template in github or somewhere, but this way it's highly portable.
define get_arm_template($hostingplan_name, $website_name, $db_server_name, $appinsights_name) return $arm_template do

$arm_template = {
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "skuName": {
      "type": "string",
      "defaultValue": "F1",
      "allowedValues": [
        "F1",
        "D1",
        "B1",
        "B2",
        "B3",
        "S1",
        "S2",
        "S3",
        "P1",
        "P2",
        "P3",
        "P4"
      ],
      "metadata": {
        "description": "Describes plan's pricing tier and instance size. Check details at https://azure.microsoft.com/en-us/pricing/details/app-service/"
      }
    },
    "skuCapacity": {
      "type": "int",
      "defaultValue": 1,
      "minValue": 1,
      "metadata": {
        "description": "Describes plan's instance count"
      }
    },
    "administratorLogin": {
      "type": "string",
      "metadata": {
        "description": "The admin user of the SQL Server"
      }
    },
    "administratorLoginPassword": {
      "type": "securestring",
      "metadata": {
        "description": "The password of the admin user of the SQL Server"
      }

    },
    "databaseName": {
      "type": "string",
      "defaultValue": "sampledb",
      "metadata": {
        "description": "The name of the new database to create."
      }
    },
    "collation": {
      "type": "string",
      "defaultValue": "SQL_Latin1_General_CP1_CI_AS",
      "metadata": {
        "description": "The database collation for governing the proper use of characters."
      }
    },
    "edition": {
      "type": "string",
      "defaultValue": "Basic",
      "allowedValues": [
        "Basic",
        "Standard",
        "Premium"
      ],
      "metadata": {
        "description": "The type of database to create."
      }
    },
    "maxSizeBytes": {
      "type": "string",
      "defaultValue": "1073741824",
      "metadata": {
        "description": "The maximum size, in bytes, for the database"
      }
    },
    "requestedServiceObjectiveName": {
      "type": "string",
      "defaultValue": "Basic",
      "allowedValues": [
        "Basic",
        "S0",
        "S1",
        "S2",
        "P1",
        "P2",
        "P3"
      ],
      "metadata": {
        "description": "Describes the performance level for Edition"
      }
    }
  },
  "variables": {
    "hostingPlanName": $hostingplan_name,
    "webSiteName": $website_name,
    "sqlserverName": $db_server_name,
    "appInsightsName" : $appinsights_name
  },
  "resources": [
    {
      "name": "[variables('sqlserverName')]",
      "type": "Microsoft.Sql/servers",
      "location": "[resourceGroup().location]",
      "tags": {
        "displayName": "SqlServer"
      },
      "apiVersion": "2014-04-01-preview",
      "properties": {
        "administratorLogin": "[parameters('administratorLogin')]",
        "administratorLoginPassword": "[parameters('administratorLoginPassword')]",
        "version": "12.0"
      },
      "resources": [
        {
          "name": "[parameters('databaseName')]",
          "type": "databases",
          "location": "[resourceGroup().location]",
          "tags": {
            "displayName": "Database"
          },
          "apiVersion": "2014-04-01-preview",
          "dependsOn": [
            "[variables('sqlserverName')]"
          ],
          "properties": {
            "edition": "[parameters('edition')]",
            "collation": "[parameters('collation')]",
            "maxSizeBytes": "[parameters('maxSizeBytes')]",
            "requestedServiceObjectiveName": "[parameters('requestedServiceObjectiveName')]"
          }
        },
        {
          "type": "firewallrules",
          "apiVersion": "2014-04-01-preview",
          "dependsOn": [
            "[variables('sqlserverName')]"
          ],
          "location": "[resourceGroup().location]",
          "name": "AllowAllWindowsAzureIps",
          "properties": {
            "endIpAddress": "0.0.0.0",
            "startIpAddress": "0.0.0.0"
          }
        }
      ]
    },
    {
      "apiVersion": "2015-08-01",
      "name": "[variables('hostingPlanName')]",
      "type": "Microsoft.Web/serverfarms",
      "location": "[resourceGroup().location]",
      "tags": {
        "displayName": "HostingPlan"
      },
      "sku": {
        "name": "[parameters('skuName')]",
        "capacity": "[parameters('skuCapacity')]"
      },
      "properties": {
        "name": "[variables('hostingPlanName')]"
      }
    },
    {
      "apiVersion": "2015-08-01",
      "name": "[variables('webSiteName')]",
      "type": "Microsoft.Web/sites",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[variables('hostingPlanName')]"
      ],
      "tags": {
        "[concat('hidden-related:', resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName')))]": "empty",
        "displayName": "Website"
      },
      "properties": {
        "name": "[variables('webSiteName')]",
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName'))]"
      },
      "resources": [
        {
          "apiVersion": "2015-08-01",
          "type": "config",
          "name": "connectionstrings",
          "dependsOn": [
            "[variables('webSiteName')]"
          ],
          "properties": {
            "DefaultConnection": {
              "value": "[concat('Data Source=tcp:', reference(concat('Microsoft.Sql/servers/', variables('sqlserverName'))).fullyQualifiedDomainName, ',1433;Initial Catalog=', parameters('databaseName'), ';User Id=', parameters('administratorLogin'), '@', variables('sqlserverName'), ';Password=', parameters('administratorLoginPassword'), ';')]",
              "type": "SQLServer"
            }
          }
        }
      ]
    },
    {
      "apiVersion": "2014-04-01",
      "name": "[concat(variables('hostingPlanName'), '-', resourceGroup().name)]",
      "type": "Microsoft.Insights/autoscalesettings",
      "location": "[resourceGroup().location]",
      "tags": {
        "[concat('hidden-link:', resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName')))]": "Resource",
        "displayName": "AutoScaleSettings"
      },
      "dependsOn": [
        "[variables('hostingPlanName')]"
      ],
      "properties": {
        "profiles": [
          {
            "name": "Default",
            "capacity": {
              "minimum": 1,
              "maximum": 2,
              "default": 1
            },
            "rules": [
              {
                "metricTrigger": {
                  "metricName": "CpuPercentage",
                  "metricResourceUri": "[resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName'))]",
                  "timeGrain": "PT1M",
                  "statistic": "Average",
                  "timeWindow": "PT10M",
                  "timeAggregation": "Average",
                  "operator": "GreaterThan",
                  "threshold": 80.0
                },
                "scaleAction": {
                  "direction": "Increase",
                  "type": "ChangeCount",
                  "value": 1,
                  "cooldown": "PT10M"
                }
              },
              {
                "metricTrigger": {
                  "metricName": "CpuPercentage",
                  "metricResourceUri": "[resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName'))]",
                  "timeGrain": "PT1M",
                  "statistic": "Average",
                  "timeWindow": "PT1H",
                  "timeAggregation": "Average",
                  "operator": "LessThan",
                  "threshold": 60.0
                },
                "scaleAction": {
                  "direction": "Decrease",
                  "type": "ChangeCount",
                  "value": 1,
                  "cooldown": "PT1H"
                }
              }
            ]
          }
        ],
        "enabled": false,
        "name": "[concat(variables('hostingPlanName'), '-', resourceGroup().name)]",
        "targetResourceUri": "[resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName'))]"
      }
    },
    {
      "apiVersion": "2014-04-01",
      "name": "[concat('ServerErrors ', variables('webSiteName'))]",
      "type": "Microsoft.Insights/alertrules",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[variables('webSiteName')]"
      ],
      "tags": {
        "[concat('hidden-link:', resourceId('Microsoft.Web/sites', variables('webSiteName')))]": "Resource",
        "displayName": "ServerErrorsAlertRule"
      },
      "properties": {
        "name": "[concat('ServerErrors ', variables('webSiteName'))]",
        "description": "[concat(variables('webSiteName'), ' has some server errors, status code 5xx.')]",
        "isEnabled": false,
        "condition": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.ThresholdRuleCondition",
          "dataSource": {
            "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleMetricDataSource",
            "resourceUri": "[resourceId('Microsoft.Web/sites', variables('webSiteName'))]",
            "metricName": "Http5xx"
          },
          "operator": "GreaterThan",
          "threshold": 0.0,
          "windowSize": "PT5M"
        },
        "action": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleEmailAction",
          "sendToServiceOwners": true,
          "customEmails": []
        }
      }
    },
    {
      "apiVersion": "2014-04-01",
      "name": "[concat('ForbiddenRequests ', variables('webSiteName'))]",
      "type": "Microsoft.Insights/alertrules",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[variables('webSiteName')]"
      ],
      "tags": {
        "[concat('hidden-link:', resourceId('Microsoft.Web/sites', variables('webSiteName')))]": "Resource",
        "displayName": "ForbiddenRequestsAlertRule"
      },
      "properties": {
        "name": "[concat('ForbiddenRequests ', variables('webSiteName'))]",
        "description": "[concat(variables('webSiteName'), ' has some requests that are forbidden, status code 403.')]",
        "isEnabled": false,
        "condition": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.ThresholdRuleCondition",
          "dataSource": {
            "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleMetricDataSource",
            "resourceUri": "[resourceId('Microsoft.Web/sites', variables('webSiteName'))]",
            "metricName": "Http403"
          },
          "operator": "GreaterThan",
          "threshold": 0,
          "windowSize": "PT5M"
        },
        "action": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleEmailAction",
          "sendToServiceOwners": true,
          "customEmails": []
        }
      }
    },
    {
      "apiVersion": "2014-04-01",
      "name": "[concat('CPUHigh ', variables('hostingPlanName'))]",
      "type": "Microsoft.Insights/alertrules",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[variables('hostingPlanName')]"
      ],
      "tags": {
        "[concat('hidden-link:', resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName')))]": "Resource",
        "displayName": "CPUHighAlertRule"
      },
      "properties": {
        "name": "[concat('CPUHigh ', variables('hostingPlanName'))]",
        "description": "[concat('The average CPU is high across all the instances of ', variables('hostingPlanName'))]",
        "isEnabled": false,
        "condition": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.ThresholdRuleCondition",
          "dataSource": {
            "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleMetricDataSource",
            "resourceUri": "[resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName'))]",
            "metricName": "CpuPercentage"
          },
          "operator": "GreaterThan",
          "threshold": 90,
          "windowSize": "PT15M"
        },
        "action": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleEmailAction",
          "sendToServiceOwners": true,
          "customEmails": []
        }
      }
    },
    {
      "apiVersion": "2014-04-01",
      "name": "[concat('LongHttpQueue ', variables('hostingPlanName'))]",
      "type": "Microsoft.Insights/alertrules",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[variables('hostingPlanName')]"
      ],
      "tags": {
        "[concat('hidden-link:', resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName')))]": "Resource",
        "displayName": "AutoScaleSettings"
      },
      "properties": {
        "name": "[concat('LongHttpQueue ', variables('hostingPlanName'))]",
        "description": "[concat('The HTTP queue for the instances of ', variables('hostingPlanName'), ' has a large number of pending requests.')]",
        "isEnabled": false,
        "condition": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.ThresholdRuleCondition",
          "dataSource": {
            "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleMetricDataSource",
            "resourceUri": "[concat(resourceGroup().id, '/providers/Microsoft.Web/serverfarms/', variables('hostingPlanName'))]",
            "metricName": "HttpQueueLength"
          },
          "operator": "GreaterThan",
          "threshold": 100.0,
          "windowSize": "PT5M"
        },
        "action": {
          "odata.type": "Microsoft.Azure.Management.Insights.Models.RuleEmailAction",
          "sendToServiceOwners": true,
          "customEmails": []
        }
      }
    },
    {
      "apiVersion": "2014-04-01",
      "name": "[variables('appInsightsName')]",
      "type": "Microsoft.Insights/components",
      "location": "Central US",
      "dependsOn": [
        "[variables('webSiteName')]"
      ],
      "tags": {
        "[concat('hidden-link:', resourceId('Microsoft.Web/sites', variables('webSiteName')))]": "Resource",
        "displayName": "AppInsightsComponent"
      },
      "properties": {
        "ApplicationId": "[variables('webSiteName')]"
      }
    }
  ],
  "outputs": {
    "siteUri": {
      "type": "string",
      "value": "[reference(concat('Microsoft.Web/sites/', variables('webSiteName')), '2015-08-01').hostnames[0]]"
    },
    "sqlSvrFqdn": {
      "type": "string",
      "value": "[reference(concat('Microsoft.Sql/servers/', variables('sqlserverName'))).fullyQualifiedDomainName]"
    }
  }
}

end
