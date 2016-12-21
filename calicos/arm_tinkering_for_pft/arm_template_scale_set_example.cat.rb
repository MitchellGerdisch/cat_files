# Uses an ARM template to launch an ARM scale set.
#
# RightScale Account Prerequisites:
#   ARM account: An ARM account needs to be connected to the RightScale account.
#   Service Principal: A service principal needs to exist for the given ARM subscription and the password for that service principal must be available.
#   The following CREDENTIALS need to be defined in the RightScale account. (Cloud Management: Design -> Credentials)
#     ARM_DOMAIN_NAME: The domain name for the ARM account connected to the RightScale account. This will be the first part of the onmicrosoft.com AD domain name.
#     ARM_PFT_APPLICATION_ID: The "APP ID" for the Service Principal being used.
#     ARM_PFT_APPLICATION_PASSWORD: The password created for the Service Principal being used.
#     ARM_PFT_SUBSCRIPTION_ID: The subscription ID for the ARM account connected to the given RightScale account. Can be found in Settings -> Clouds -> select an ARM cloud

# TO-DOs:
# Retrieve and show the scaling set VMs' NAT ports and IP addresses.
#   Need to grab the NAT info from the scaling set's load balancer which will have the resource group name.
#   Shouldn't be hard.
# Implement automatic RL enablement. 
#   I have been able to do this manually so I know RL enablement of these scaling set VMs is possible.
#   Currently requires a UCA - no biggie.
#   Would likely need a utility server to execute the remote RL enablement via ssh.
#   


name 'Launch ARM Scale Set'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/azure.png)

Launch ARM scale set"
long_description "Uses an ARM template to launch an App scale set."


import "plugin/arm_common"
import "plugin/arm_template"
import "common/functions"

# User launch time inputs
parameter "param_scaleset_name" do
  category "User Inputs"
  label "Scale Set Name" 
  type "string" 
  description "Name of Scale Set." 
end

parameter "param_instance_type" do
  category "User Inputs"
  label "Instance Type" 
  type "string" 
  description "Instance type to use for scale set VMs" 
  default "Standard_A1"
  allowed_values "Standard_A1", "Standard_A2"
end

parameter "param_ubuntu_version" do
  category "User Inputs"
  label "Ubuntu Version" 
  type "string" 
  description "Version of Unbuntu to use for scale set VMs." 
  default "14.04.4-LTS"
  allowed_values "15.10", "14.04.4-LTS"
end

parameter "param_instance_count" do
  category "User Inputs"
  label "Number of Instances" 
  type "number" 
  description "Initial number of instances in the Scale Set." 
  default 2
  min_value 1
  max_value 8
end

parameter "param_server_username" do
  category "User Inputs"
  label "Server Username" 
  type "string" 
  description "Username to configure on the scale set servers." 
  default "ubuntu"
  allowed_pattern '^[a-zA-Z]+[a-zA-Z0-9\_]*$'
  constraint_description "Must start with a letter and then can be any combination of letters, numerals or \"_\""
end

parameter "param_server_password" do
  category "User Inputs"
  label "Server Password" 
  type "string" 
  description "Password to configure on the scale set servers." 
  allowed_pattern '^[a-zA-Z]+[a-zA-Z0-9\_#]*$'
  constraint_description "Must start with a letter and then can be any combination of letters, numerals or \"_\" or \"#\""
  no_echo true
end

# Outputs

# Operations
operation "launch" do 
  description "Launch the deployment based on ARM template."
  definition "arm_deployment_launch"
  
end

operation "terminate" do 
  description "Terminate the deployment"
  definition "arm_deployment_terminate"
end

define arm_deployment_launch($param_instance_type, $param_ubuntu_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password) do
  
  $param_resource_group = "default"

  # Get the properly formatted or specified info needed for the launch
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
  
  # Get an access token
  call arm_common.get_access_token() retrieve $access_token
  
  # Create the resource group in which to place the deployment
  # if it already exists, no harm no foul
  $param_location = "South Central US"
  call arm_common.create_resource_group($param_location, $resource_group, $tags_hash, $access_token)
  
  # Currently I'm using in-line template in the request. For one I couldn't get it to work with the stored template approach and didn't want to spend too much time figuring out why.
  # Also, this does let me tinker a bit with the values based on user inputs.
  # However, the right answer is to store the main body of the template somewhere and link to it (i.e. use templateLink in the body) and only use in-line specification for the parameters 
  call build_arm_template_launch_body($param_instance_type, $param_ubuntu_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password) retrieve $arm_template_launch_body

  
  # launch the ARM template
  call arm_template.launch_arm_template($arm_template_launch_body, $resource_group, $arm_deployment_name, $access_token)
  
  call arm_common.get_subscription_id() retrieve $subscription_id

end


define arm_deployment_terminate() do
  
  $param_resource_group = "default"
  
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
    
  # Get an access token
  call arm_common.get_access_token() retrieve $access_token

  # At this time, since the template is launched in its own resource group, we'll just delete the resource group on termination
  call arm_common.delete_resource_group($resource_group, $access_token)

end


define get_launch_info($param_resource_group) return $arm_deployment_name, $resource_group do
  # Use the created deployment name with out spaces
  $arm_deployment_name = gsub(@@deployment.name, " ", "")
  
  if equals?($param_resource_group, "default")
    $resource_group = $arm_deployment_name
  else
    $resource_group = $param_resource_group
  end
end


# Build the message body with an in-line ARM template and applicable parameters.
define build_arm_template_launch_body($param_instance_type, $param_ubuntu_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password) return $arm_template_launch_body do
  
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
          }
        }
      }
    }
  ]
}
end
