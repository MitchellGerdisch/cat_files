name 'Plugin - AzureRM SQL API Functions'
rs_ca_ver 20160622
short_description "Functions for interacting with ARM SQL service API"

package "plugin/arm_sql"

import "plugin/arm_common"
import "common/functions"


define create_sql_server($access_token, $resource_group_name, $server_name, $location, $tags_hash) return $sqlsrvr_id do
  
  # Create the creds we'll use
  call functions.getDeploymentId() retrieve $deployment_id
  $arm_sql_admin_login = "ARM_SQL_ADMIN_LOGIN-"+$deployment_id
  $arm_sql_admin_password = "ARM_SQL_ADMIN_PASSWORD-"+$deployment
  call createCreds([$arm_sql_admin_login, $arm_sql_admin_password])

  call functions.get_cred($arm_sql_admin_login) retrieve $sqladminLogin
  call functions.get_cred($arm_sql_admin_password) retrieve $sqladminPassword
  
  # build the api url base using the correct subscription ID
  call arm_common.build_api_url_base() retrieve $api_url_base
  
  $sqlserver_create_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "/providers/Microsoft.Sql/servers/" + $server_name + "?api-version=2014-04-01-preview"
  call functions.log("SQL DB server create URL string", $sqlserver_create_url)

  $response = http_put(
    url: $sqlserver_create_url,
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/json",
      "authorization": "Bearer " + $access_token
    },
    body: {
          "location": $location,
          "tags": $tags_hash,
          "properties": {
              "version": "12.0",
              "administratorLogin": $sqladminLogin,
              "administratorLoginPassword": $sqladminPassword
          }
      }
  )
  
  call functions.log("SQL DB server create response", to_s($response))
  
  $sqlsrv_id = $response
  
end

define create_sql_db($access_token, $resource_group_name, $server_name, $db_name, $location, $tags_hash) return $sqldb_id do
    
  # build the api url base using the correct subscription ID
  call arm_common.build_api_url_base() retrieve $api_url_base
  
  $sqldb_create_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "/providers/Microsoft.Sql/servers/" + $server_name + "/databases/" + $db_name + "?api-version=2014-04-01-preview"
  call functions.log("SQL DB create URL string", $sqldb_create_url)
  
  # sql db creation returns a poorly formatted response 
  sub on_error: skip do
    $response = http_put(
      url: $sqldb_create_url,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      },
      body: {
            "location": $location,
            "tags": $tags_hash,
            "properties": {  
                "createMode": "Default",   
                "edition": "Standard",    
                "collation": "SQL_Latin1_General_CP1_CI_AS",    
                "requestedServiceObjectiveName": "S0"
            } 
        }
    )
    
    call functions.log("SQL DB create response", to_s($response))

  end
  
  # it takes a bit for the DB to get created, so sleep a bit before returning.
  # to-do loop on getting the DB info until it's created
  sleep(60)
  
  $get_response = http_get(
      url: $sqldb_create_url,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      }
    )
  
  call functions.log("SQL DB info", to_s($get_response))
    
  $sqldb_id = $db_name + ".database.windows.net"
  
end

define change_service_plan($access_token, $resource_group_name, $server_name, $db_name, $location) return $sqldb_id do

  # build the api url base using the correct subscription ID
  call arm_common.build_api_url_base() retrieve $api_url_base

  $sqldb_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "/providers/Microsoft.Sql/servers/" + $server_name + "/databases/" + $db_name + "?api-version=2014-04-01-preview"
  call functions.log("SQL DB update URL string", $sqldb_url)

  # sql db creation returns a poorly formatted response
  sub on_error: skip do
    $response = http_put(
      url: $sqldb_url,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      },
      body: {
        "location": $location,
         "properties": {
                "requestedServiceObjectiveName": "P2"
            }
        }
    )

    call functions.log("SQL DB update response", to_s($response))

  end

  # it takes a bit for the DB to get updated, so sleep a bit before returning.
  # to-do loop on getting the DB info until it's created
  sleep(60)

  $get_response = http_get(
      url: $sqldb_url,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      }
    )

  call functions.log("SQL DB info", to_s($get_response))

  $sqldb_id = $db_name + ".database.windows.net"

end


define terminate_sql_db($access_token, $resource_group_name, $server_name, $db_name) do
  
  # build the api url base using the correct subscription ID
  call arm_common.build_api_url_base() retrieve $api_url_base
  
  $sqldb_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "/providers/Microsoft.Sql/servers/" + $server_name + "/databases/" + $db_name + "?api-version=2014-04-01-preview"

  # sql db creation returns a poorly formatted response 
  sub on_error: skip do
    $response = http_delete(
      url: $sqldb_url,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      }
    )
  end
    
end

define terminate_sql_server($access_token, $resource_group_name, $server_name) do
  
  # build the api url base using the correct subscription ID
  call arm_common.build_api_url_base() retrieve $api_url_base
  
  $sqlserver_url = $api_url_base + "/resourcegroups/" + $resource_group_name + "/providers/Microsoft.Sql/servers/" + $server_name + "?api-version=2014-04-01-preview"

  $response = http_delete(
    url: $sqlserver_url,
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/json",
      "authorization": "Bearer " + $access_token
    }
  )
  
  # Delete the creds we created for the sql service
  call functions.getDeploymentId() retrieve $deployment_id
  $arm_sql_admin_login = "ARM_SQL_ADMIN_LOGIN-"+$deployment_id
  $arm_sql_admin_password = "ARM_SQL_ADMIN_PASSWORD-"+$deployment
  call createCreds([$arm_sql_admin_login, $arm_sql_admin_password])    
end
