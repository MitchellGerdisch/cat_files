# ARM Template definition
# Basic Linux scaleset template with RightLink enablement - WORK IN PROGRESS
#
# Key Features:
#   calls rightlink enablement script.


name 'LIB - Linux ARM Template Definition'
rs_ca_ver 20160622
short_description "Defines a Linux Scaleset that should include a custom script"

package "arm/linux/template"

# Build the message body with an in-line ARM template and applicable parameters.
define build_arm_template_launch_body($refresh_token, $uca_name, $servertemplate_href, $deployment_href, $param_instance_type, $param_ubuntu_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password) return $arm_template_launch_body do
  
  call get_arm_template() retrieve $arm_template
  
  $arm_template_launch_body = {
  "properties": {
    "template": $arm_template,
    "mode": "Incremental",
    "parameters": {
      "vmSku": {
        "value": $param_instance_type
      },
      "ubuntuOSVersion": {
        "value": $param_ubuntu_version
      },
      "vmssName":{
        "value": $param_scaleset_name
      },
      "instanceCount": {
        "value": $param_instance_count
      },
      "adminUsername": {
        "value": $param_server_username
      },
      "adminPassword": {
        "value": $param_server_password
      },
      "refresh_token": {
        "value": $refresh_token
      },
      "uca_name": {
        "value": $uca_name
      },
      "servertemplate_href": {
        "value": $servertemplate_href
      },
      "deployment_href": {
        "value": $deployment_href
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
define get_arm_template() return $arm_template do

$arm_template = {
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "vmSku": {
      "type": "string",
      "defaultValue": "Standard_A1",
      "metadata": {
        "description": "Size of VMs in the VM Scale Set."
      }
    },
    "ubuntuOSVersion": {
      "type": "string",
      "defaultValue": "14.04.4-LTS",
      "allowedValues": [
        "15.10",
        "14.04.4-LTS"
      ],
      "metadata": {
        "description": "The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version. Allowed values are: 15.10, 14.04.4-LTS."
      }
    },
    "vmssName":{
      "type":"string",
      "metadata":{
        "description":"String used as a base for naming resources. Must be 3-61 characters in length and globally unique across Azure. A hash is prepended to this string for some resources, and resource-specific information is appended."
      },
      "maxLength": 61
    },
    "instanceCount": {
      "type": "int",
      "metadata": {
        "description": "Number of VM instances (100 or less)."
      },
      "maxValue": 100
    },
    "adminUsername": {
      "type": "string",
      "metadata": {
        "description": "Admin username on all VMs."
      }
    },
    "adminPassword": {
      "type": "securestring",
      "metadata": {
        "description": "Admin password on all VMs."
      }
    },
    "refresh_token": {
      "type": "securestring",
      "metadata": {
        "description": "RightScale refresh token to use for RL enablement."
      }
    },
    "uca_name": {
      "type":"string",
      "metadata":{
        "description":"Name of the UCA for RL enablement."
      }
    },
    "servertemplate_href": {
      "type":"string",
      "metadata":{
        "description":"HREF for the ServerTemplate to use for RL enablement."
      }
    },
    "deployment_href": {
      "type":"string",
      "metadata":{
        "description":"HREF for the Deployment to use for RL enablement."
      }
    }
  },
  "variables": {
    "storageAccountType": "Standard_LRS",
    "namingInfix": "[toLower(substring(concat(parameters('vmssName'), uniqueString(resourceGroup().id)), 0, 9))]",
    "longNamingInfix": "[toLower(parameters('vmssName'))]",
    "newStorageAccountSuffix": "[concat(variables('namingInfix'), 'sa')]",
    "uniqueStringArray": [
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '0')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '1')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '2')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '3')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '4')))]"
    ],
    "saCount": "[length(variables('uniqueStringArray'))]",
    "vhdContainerName": "[concat(variables('namingInfix'), 'vhd')]",
    "osDiskName": "[concat(variables('namingInfix'), 'osdisk')]",
    "addressPrefix": "10.0.0.0/16",
    "subnetPrefix": "10.0.0.0/24",
    "virtualNetworkName": "[concat(variables('namingInfix'), 'vnet')]",
    "publicIPAddressName": "[concat(variables('namingInfix'), 'pip')]",
    "subnetName": "[concat(variables('namingInfix'), 'subnet')]",
    "loadBalancerName": "[concat(variables('namingInfix'), 'lb')]",
    "publicIPAddressID": "[resourceId('Microsoft.Network/publicIPAddresses',variables('publicIPAddressName'))]",
    "lbID": "[resourceId('Microsoft.Network/loadBalancers',variables('loadBalancerName'))]",
    "natPoolName": "[concat(variables('namingInfix'), 'natpool')]",
    "bePoolName": "[concat(variables('namingInfix'), 'bepool')]",
    "natStartPort": 50000,
    "natEndPort": 50119,
    "natBackendPort": 22,
    "nicName": "[concat(variables('namingInfix'), 'nic')]",
    "ipConfigName": "[concat(variables('namingInfix'), 'ipconfig')]",
    "frontEndIPConfigID": "[concat(variables('lbID'),'/frontendIPConfigurations/loadBalancerFrontEnd')]",
    "osType": {
      "publisher": "Canonical",
      "offer": "UbuntuServer",
      "sku": "[parameters('ubuntuOSVersion')]",
      "version": "latest"
    },
    "imageReference": "[variables('osType')]",
    "computeApiVersion": "2016-03-30",
    "networkApiVersion": "2016-03-30",
    "storageApiVersion": "2015-06-15"
  },
  "resources": [
    {
      "type": "Microsoft.Network/virtualNetworks",
      "name": "[variables('virtualNetworkName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "[variables('networkApiVersion')]",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            "[variables('addressPrefix')]"
          ]
        },
        "subnets": [
          {
            "name": "[variables('subnetName')]",
            "properties": {
              "addressPrefix": "[variables('subnetPrefix')]"
            }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Storage/storageAccounts",
      "name": "[concat(variables('uniqueStringArray')[copyIndex()], variables('newStorageAccountSuffix'))]",
      "location": "[resourceGroup().location]",
      "apiVersion": "[variables('storageApiVersion')]",
      "copy": {
        "name": "storageLoop",
        "count": "[variables('saCount')]"
      },
      "properties": {
        "accountType": "[variables('storageAccountType')]"
      }
    },
    {
      "type": "Microsoft.Network/publicIPAddresses",
      "name": "[variables('publicIPAddressName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "[variables('networkApiVersion')]",
      "properties": {
        "publicIPAllocationMethod": "Dynamic",
        "dnsSettings": {
          "domainNameLabel": "[variables('longNamingInfix')]"
        }
      }
    },
    {
      "type": "Microsoft.Network/loadBalancers",
      "name": "[variables('loadBalancerName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "[variables('networkApiVersion')]",
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('publicIPAddressName'))]"
      ],
      "properties": {
        "frontendIPConfigurations": [
          {
            "name": "LoadBalancerFrontEnd",
            "properties": {
              "publicIPAddress": {
                "id": "[variables('publicIPAddressID')]"
              }
            }
          }
        ],
        "backendAddressPools": [
          {
            "name": "[variables('bePoolName')]"
          }
        ],
        "inboundNatPools": [
          {
            "name": "[variables('natPoolName')]",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[variables('frontEndIPConfigID')]"
              },
              "protocol": "tcp",
              "frontendPortRangeStart": "[variables('natStartPort')]",
              "frontendPortRangeEnd": "[variables('natEndPort')]",
              "backendPort": "[variables('natBackendPort')]"
            }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Compute/virtualMachineScaleSets",
      "name": "[variables('namingInfix')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "[variables('computeApiVersion')]",
      "dependsOn": [
        "storageLoop",
        "[concat('Microsoft.Network/loadBalancers/', variables('loadBalancerName'))]",
        "[concat('Microsoft.Network/virtualNetworks/', variables('virtualNetworkName'))]"
      ],
      "sku": {
        "name": "[parameters('vmSku')]",
        "tier": "Standard",
        "capacity": "[parameters('instanceCount')]"
      },
      "properties": {
        "overprovision": "true",
        "upgradePolicy": {
          "mode": "Manual"
        },
        "virtualMachineProfile": {
          "storageProfile": {
            "osDisk": {
              "vhdContainers": [
                "[concat('https://', variables('uniqueStringArray')[0], variables('newStorageAccountSuffix'), '.blob.core.windows.net/', variables('vhdContainerName'))]",
                "[concat('https://', variables('uniqueStringArray')[1], variables('newStorageAccountSuffix'), '.blob.core.windows.net/', variables('vhdContainerName'))]",
                "[concat('https://', variables('uniqueStringArray')[2], variables('newStorageAccountSuffix'), '.blob.core.windows.net/', variables('vhdContainerName'))]",
                "[concat('https://', variables('uniqueStringArray')[3], variables('newStorageAccountSuffix'), '.blob.core.windows.net/', variables('vhdContainerName'))]",
                "[concat('https://', variables('uniqueStringArray')[4], variables('newStorageAccountSuffix'), '.blob.core.windows.net/', variables('vhdContainerName'))]"
              ],
              "name": "[variables('osDiskName')]",
              "caching": "ReadOnly",
              "createOption": "FromImage"
            },
            "imageReference": "[variables('imageReference')]"
          },
          "osProfile": {
            "computerNamePrefix": "[variables('namingInfix')]",
            "adminUsername": "[parameters('adminUsername')]",
            "adminPassword": "[parameters('adminPassword')]"
          },
          "networkProfile": {
            "networkInterfaceConfigurations": [
              {
                "name": "[variables('nicName')]",
                "properties": {
                  "primary": "true",
                  "ipConfigurations": [
                    {
                      "name": "[variables('ipConfigName')]",
                      "properties": {
                        "subnet": {
                          "id": "[concat('/subscriptions/', subscription().subscriptionId,'/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Network/virtualNetworks/', variables('virtualNetworkName'), '/subnets/', variables('subnetName'))]"
                        },
                        "loadBalancerBackendAddressPools": [
                          {
                            "id": "[concat('/subscriptions/', subscription().subscriptionId,'/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Network/loadBalancers/', variables('loadBalancerName'), '/backendAddressPools/', variables('bePoolName'))]"
                          }
                        ],
                        "loadBalancerInboundNatPools": [
                          {
                            "id": "[concat('/subscriptions/', subscription().subscriptionId,'/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Network/loadBalancers/', variables('loadBalancerName'), '/inboundNatPools/', variables('natPoolName'))]"
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            ]
          },
          "extensionProfile": {
            "extensions": [
              {
                "name": "customScript",
                "properties": {
                  "publisher": "Microsoft.Azure.Extensions",
                  "settings": {
                    "fileUris": [
                      "https://rightlink.rightscale.com/rll/10/rightlink.enable.sh"
                    ],
                    "commandToExecute": "[concat('./rightlink.enable.sh -l -k \"', parameters('refresh_token'), '\" -r \"', parameters('servertemplate_href'), '\" -f \"', parameters('uca_name'), '\" -e \"', parameters('deployment_href'), '\" -n `hostname`')]"
                  },
                  "type": "CustomScript",
                  "typeHandlerVersion": "2.0",
                  "autoUpgradeMinorVersion": true
                }
              }
            ]
          }
        }
      }
    }
  ]
}

#  "protectedSettings": {
#    "commandToExecute": "./rightlink.enable.sh -l -k \'[parameters('refresh_token')]\' -r '/api/server_templates/391055003' -f 'UCA AzureRM' -e '/api/deployments/837414003'"
#  }
end
