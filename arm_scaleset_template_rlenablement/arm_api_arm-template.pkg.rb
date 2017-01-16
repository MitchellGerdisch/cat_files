name 'LIB - AzureRM ARM Template API Functions'
rs_ca_ver 20160622
short_description "Functions for launching and managing ARM Template launches via ARM API"

package "arm/api_template"

import "general/functions"
import "arm/api_common"

define launch_arm_template($arm_template_launch_body, $resource_group, $arm_deployment_name, $access_token) do

  call api_common.build_api_url_base() retrieve $api_url_base
  $arm_launch_uri = $api_url_base + "/resourceGroups/" + $resource_group + "/providers/microsoft.resources/deployments/" + $arm_deployment_name + "?api-version=2016-02-01"
    
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
    
    call functions.log("Launch Status", to_s($response))
    
    if $response["body"]["properties"]["provisioningState"] == "Failed"
      raise "ARM template launch failed. See Launch Status entry in the Audit Entries for more info."
    end
    
    $deployment_not_ready = logic_not(equals?($response["body"]["properties"]["provisioningState"], "Succeeded"))
  end

end

