name 'LIB - AzureRM Common API Functions'
rs_ca_ver 20160622
short_description "Functions for interacting with ARM API"

package "arm/api_common"

import "general/functions"

# Authenticate to AzureRM and get the access token.
define get_access_token() return $access_token do
  
  # TO-DO check if the creds exist and if not, raise an error explaining the names of the creds needed and what 
  # should be in them. 
  # Domain Name - the AD domain name used by the subscription. This is the bit before "onmicrosoft.com
  # Service Principal - App ID
  # Service Principal - Password that was set up for the SP when created.
  call functions.get_cred("RS_ARM_DOMAIN_NAME") retrieve $domain_name
  call functions.get_cred("RS_ARM_APPLICATION_ID") retrieve $client_id
  call functions.get_cred("RS_ARM_APPLICATION_PASSWORD") retrieve $client_secret
  
  $body_string = "grant_type=client_credentials&resource=https://management.core.windows.net/&client_id="+$client_id+"&client_secret="+$client_secret

  $auth_response = http_post(
    url: "https://login.microsoftonline.com/" + $domain_name + ".onmicrosoft.com/oauth2/token?api-version=1.0",
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/x-www-form-urlencoded"
     # "Content-Type":"application/json"

    },
    body:$body_string
  )
  
  $auth_response_body = $auth_response["body"]
  $access_token = $auth_response_body["access_token"]
   
end


# helper function to build base URI
define build_api_url_base() return $api_url_base do
  call get_subscription_id() retrieve $subscription_id
  
  $api_url_base = "https://management.azure.com/subscriptions/"+$subscription_id
end

define create_resource_group($location, $resource_group, $tags_hash, $access_token) do

  call build_api_url_base() retrieve $api_url_base
  $resource_group_uri = $api_url_base + "/resourcegroups/" + $resource_group + "?api-version=2015-01-01"
    
  $response = http_put(
    url: $resource_group_uri,
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/json",
      "authorization": "Bearer " + $access_token
    },
    body: {
          "location": $location,
          "tags": $tags_hash
      }
  )
  
  call functions.log("Resource Group Creation Response", to_s($response))
end

define check_and_remove_resource_group($resource_group, $access_token) do

  call get_resource_group_info($resource_group, $access_token) retrieve $response
  
  if empty?($response["value"])
    call delete_resource_group($resource_group, $access_token)
  end
end


# Not used for anything other than some testing
define get_resource_group_info($resource_group_name, $access_token) return $response do
    
  # build the api url base using the correct subscription ID
  call build_api_url_base() retrieve $api_url_base
  
  $resourcegroup_api_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "/resources?api-version=2015-01-01"

  $response = http_get(
    url: $resourcegroup_api_url,
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/json",
      "authorization": "Bearer " + $access_token
    }
  )
  
end

define delete_resource_group($resource_group_name, $access_token) return $response do
    
  # build the api url base using the correct subscription ID
  call build_api_url_base() retrieve $api_url_base
  
  $resourcegroup_api_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "?api-version=2015-01-01"

  $response = http_delete(
    url: $resourcegroup_api_url,
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/json",
      "authorization": "Bearer " + $access_token
    }
  )
  
end

define get_subscription_id() return $subscription_id do
  call functions.get_cred("RS_ARM_SUBSCRIPTION_ID") retrieve $subscription_id
end

