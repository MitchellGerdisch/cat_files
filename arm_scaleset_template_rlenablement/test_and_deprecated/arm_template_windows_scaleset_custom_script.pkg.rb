DOES NOT WORK

# ARM Template definition
# Basic Linux scaleset template.
#
# Key Features:
#   custom data supported.
#   custom script supported - NOT WORKING!!!


name 'LIB - Windows ARM Template Definition'
rs_ca_ver 20160622
short_description "Defines a Linux Scaleset that should include a custom script"

package "arm/windows/template"

# Build the message body with an in-line ARM template and applicable parameters.
define build_arm_template_launch_body($param_instance_type, $param_os_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password, $param_customdata) return $arm_template_launch_body do
  
  call get_arm_template() retrieve $arm_template
  
  $arm_template_launch_body = {
  "properties": {
    "template": $arm_template,
    "mode": "Incremental",
    "parameters": {
      "vmSku": {
        "value": $param_instance_type
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
      }
#      "mycustomData": {
#        "value": $param_customdata
#      }
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

$arm_template =   {
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "vmSku": {
      "type": "string",
      "defaultValue": "Standard_D1",
      "metadata": {
        "description": "Size of VMs in the VM Scale Set."
      }
    },
    "vmssName": {
      "type": "string",
      "metadata": {
        "description": "String used as a base for naming resources. Must be 3-61 characters in length and globally unique across Azure. A hash is prepended to this string for some resources, and resource-specific information is appended."
      },
      "maxLength": 61
    },
    "instanceCount": {
      "type": "int",
      "metadata": {
        "description": "Number of VM instances (100 or less)."
      },
      "defaultValue": 2,
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
    "_artifactsLocation": {
      "defaultValue": "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-vmss-windows-custom-script",
      "type": "string",
      "metadata": {
        "description": "The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated."
      }
    },
    "_artifactsLocationSasToken": {
      "defaultValue": "",
      "type": "securestring",
      "metadata": {
        "description": "The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated."
      }
    }
  },
  "variables": {
    "namingInfix": "[toLower(substring(concat(parameters('vmssName'), uniqueString(resourceGroup().id)), 0, 9))]",
    "storageAccountType": "Standard_LRS",
    "newStorageAccountSuffix": "[concat(variables('namingInfix'), 'sa')]",
    "uniqueStringArray": [
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '0')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '1')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '2')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '3')))]",
      "[concat(uniqueString(concat(resourceGroup().id, variables('newStorageAccountSuffix'), '4')))]"
    ],
    "saCount": "[length(variables('uniqueStringArray'))]",
    "vnetName": "vnet",
    "subnetName": "subnet",
    "vnetID": "[resourceId('Microsoft.Network/virtualNetworks',variables('vnetName'))]",
    "subnetRef": "[concat(variables('vnetID'),'/subnets/',variables('subnetName'))]",
    "publicIPAddressName": "pip",
    "loadBalancerName": "loadBalancer",
    "loadBalancerFrontEndName": "loadBalancerFrontEnd",
    "loadBalancerBackEndName": "loadBalancerBackEnd",
    "loadBalancerProbeName": "loadBalancerHttpProbe",
    "loadBalancerNatPoolName": "loadBalancerNatPool"
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "name": "[concat(variables('uniqueStringArray')[copyIndex()], variables('newStorageAccountSuffix'))]",
      "location": "[resourceGroup().location]",
      "apiVersion": "2015-06-15",
      "copy": {
        "name": "storageLoop",
        "count": "[variables('saCount')]"
      },
      "properties": {
        "accountType": "[variables('storageAccountType')]"
      }
    },
    {
      "type": "Microsoft.Compute/virtualMachineScaleSets",
      "name": "[parameters('vmssName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "2016-03-30",
      "dependsOn": [
        "storageLoop",
        "[concat('Microsoft.Network/virtualNetworks/', variables('vnetName'))]",
        "[resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName'))]"
      ],
      "sku": {
        "name": "[parameters('vmSku')]",
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
                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray')[0], variables('newStorageAccountSuffix')), '2015-06-15').primaryEndpoints.blob, 'vhds')]",
                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray')[1], variables('newStorageAccountSuffix')), '2015-06-15').primaryEndpoints.blob, 'vhds')]",
                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray')[2], variables('newStorageAccountSuffix')), '2015-06-15').primaryEndpoints.blob, 'vhds')]",
                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray')[3], variables('newStorageAccountSuffix')), '2015-06-15').primaryEndpoints.blob, 'vhds')]",
                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray')[4], variables('newStorageAccountSuffix')), '2015-06-15').primaryEndpoints.blob, 'vhds')]"
              ],
              "name": "osdisk",
              "createOption": "FromImage"
            },
            "imageReference": {
              "publisher": "MicrosoftWindowsServer",
              "offer": "WindowsServer",
              "sku": "2016-Datacenter",
              "version": "latest"
            }
          },
          "osProfile": {
            "computerNamePrefix": "[parameters('vmssName')]",
            "adminUsername": "[parameters('adminUsername')]",
            "adminPassword": "[parameters('adminPassword')]"
          },
          "networkProfile": {
            "networkInterfaceConfigurations": [
              {
                "name": "nic",
                "properties": {
                  "primary": "true",
                  "ipConfigurations": [
                    {
                      "name": "ipconfig",
                      "properties": {
                        "subnet": {
                          "id": "[variables('subnetRef')]"
                        },
                        "loadBalancerBackendAddressPools": [
                          {
                            "id": "[concat('/subscriptions/', subscription().subscriptionId,'/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Network/loadBalancers/', variables('loadBalancerName'), '/backendAddressPools/', variables('loadBalancerBackEndName'))]"
                          }
                        ],
                        "loadBalancerInboundNatPools": [
                          {
                            "id": "[concat('/subscriptions/', subscription().subscriptionId,'/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Network/loadBalancers/', variables('loadBalancerName'), '/inboundNatPools/', variables('loadBalancerNatPoolName'))]"
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
                  "publisher": "Microsoft.Compute",
                  "settings": {
                    "fileUris": [
                      "[concat(parameters('_artifactsLocation'), '/scripts/helloWorld.ps1')]"
                    ]
                  },
                  "typeHandlerVersion": "1.8",
                  "autoUpgradeMinorVersion": true,
                  "protectedSettings": {
                    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File helloWorld.ps1"
                  },
                  "type": "CustomScriptExtension"
                }
              }
            ]
          }
        }
      }
    },
    {
      "type": "Microsoft.Network/virtualNetworks",
      "name": "[variables('vnetName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "2016-03-30",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            "10.0.0.0/16"
          ]
        },
        "subnets": [
          {
            "name": "[variables('subnetName')]",
            "properties": {
              "addressPrefix": "10.0.0.0/24"
            }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Network/publicIPAddresses",
      "name": "[variables('publicIPAddressName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "2016-06-01",
      "properties": {
        "publicIPAllocationMethod": "Dynamic",
        "dnsSettings": {
          "domainNameLabel": "[toLower(parameters('vmssName'))]"
        }
      }
    },
    {
      "type": "Microsoft.Network/loadBalancers",
      "name": "[variables('loadBalancerName')]",
      "location": "[resourceGroup().location]",
      "apiVersion": "2016-06-01",
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('publicIPAddressName'))]"
      ],
      "properties": {
        "frontendIPConfigurations": [
          {
            "name": "[variables('loadBalancerFrontEndName')]",
            "properties": {
              "publicIPAddress": {
                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('publicIPAddressName'))]"
              }
            }
          }
        ],
        "backendAddressPools": [
          {
            "name": "[variables('loadBalancerBackendName')]"
          }
        ],
        "loadBalancingRules": [
          {
            "name": "roundRobinLBRule",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName')), '/frontendIPConfigurations/', variables('loadBalancerFrontEndName'))]"
              },
              "backendAddressPool": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName')), '/backendAddressPools/', variables('loadBalancerBackendName'))]"
              },
              "protocol": "tcp",
              "frontendPort": 80,
              "backendPort": 80,
              "enableFloatingIP": false,
              "idleTimeoutInMinutes": 5,
              "probe": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName')), '/probes/', variables('loadBalancerProbeName'))]"
              }
            }
          }
        ],
        "probes": [
          {
            "name": "[variables('loadBalancerProbeName')]",
            "properties": {
              "protocol": "tcp",
              "port": 80,
              "intervalInSeconds": "5",
              "numberOfProbes": "2"
            }
          }
        ],
        "inboundNatPools": [
          {
            "name": "[variables('loadBalancerNatPoolName')]",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName')), '/frontendIPConfigurations/', variables('loadBalancerFrontEndName'))]"
              },
              "protocol": "tcp",
              "frontendPortRangeStart": "50000",
              "frontendPortRangeEnd": "50019",
              "backendPort": "3389"
            }
          }
        ]
      }
    }
  ]
}
end
