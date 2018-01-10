# Experimenting with listing volumes across multiple RS accounts from a single CAT

name "List volumes across RS accounts"
rs_ca_ver 20161221
short_description  "CAT that gathers volume info across all child accounts' clouds."

import "sys_log"

# The user/password used here must be a RightScale user that has enterprise_manager and observer role in the
# organization's master (aka paren) account.
parameter "param_rs_email" do
    category "RightScale Account Information"
    label "Email"
    description "Enter your RightScale email address"
    type "string"
    min_length 1
end
  
parameter "param_rs_password" do
    category "RightScale Account Information"
    label "Password"
    description "Enter your RightScale password"
    type "string"
    no_echo true
    min_length 1
end

operation "launch" do
  definition "gather_info_from_other_accounts"
end

define gather_info_from_other_accounts($param_rs_email, $param_rs_password) do
  
  $child_accounts = rs_cm.child_accounts.index()
  $child_accounts = $child_accounts[0]
  
  call sys_log.detail("** child accounts:"+to_s($child_accounts))
  
  foreach $child_account in $child_accounts do
    $child_account_name = $child_account["name"]
    $child_account_href = $child_account["links"][0]["href"]
    $child_account_number = split($child_account_href,"/")[-1]
    $child_account_shard = split($child_account["links"][2]["href"],"/")[-1]
    
    call sys_log.detail("**Child Account ID: "+$child_account_number)
    call sys_log.detail("**Child Account Name: "+$child_account_name)

    # Retrieving cookie for this particular child account
    $label = $child_account_number + " : Getting Access Cookie"
    task_label($label)
    call find_my_cookie($param_rs_email, $param_rs_password, $child_account_number, $child_account_shard) retrieve $new_cookie_for_account
    
    # Retrieving all the clouds associated with this child account
    $label = $child_account_number + " : Getting all clouds"
    task_label($label)
    call find_my_clouds($child_account_shard, $new_cookie_for_account) retrieve $clouds
    
    foreach $cloud in $clouds do
      # Retrieving cloud name
       $cloudname = $cloud["name"]
       
       # Retreiving all intances associaed with that cloud in that account
       $label = $child_account_number + " : " + $cloudname + " : Getting volumes"
       task_label($label)
       call sys_log.detail($label)
       call find_my_volumes($child_account_shard, $new_cookie_for_account, $cloud) retrieve $volumes
       call sys_log.detail("** VOLUMES: :"+to_s($volumes))
    end
  end

end



# Finding the shard number for the cloud
define find_shard($account_number) return $shard_number do
  $account = rs_cm.get(href: "/api/accounts/" + $account_number)
  $shard_number = last(split(select($account[0]["links"], {"rel":"cluster"})[0]["href"],"/"))
end

# Generating the cookie associated with the email/password, and rightscale account
define find_my_cookie($email_id, $password_id, $account_id, $rs_shard) return $mycookie_information do
  $rightscale_endpoint = "https://us-" +$rs_shard +".rightscale.com"
  $the_body={
      "account_href":"/api/accounts/" + $account_id,
      "email": $email_id,
      "password": $password_id
  }
  $response = http_post(
      url: $rightscale_endpoint + "/api/session",
      headers: { "X_API_VERSION": "1.5" },
      body: $the_body
  )
  $mycookie_information = $response["cookies"]
end

# Finding all the child accounts associated with the master parent account
define find_my_child_accounts($rs_shard, $account_cookies) return $child_response do
  $rightscale_endpoint = "https://us-" +$rs_shard +".rightscale.com"
  $childrend_response = http_get(
      url: $rightscale_endpoint + "/api/child_accounts",
      headers: { "X_API_VERSION": "1.5" },
      cookies: $account_cookies
  )
  $child_response = $childrend_response["body"]
end

# Finding all the clouds assoicated with an account
define find_my_clouds($rs_shard, $account_cookies) return $clouds do
  $rightscale_endpoint = "https://us-" +$rs_shard +".rightscale.com"
  $cloud_response = http_get(
      url: $rightscale_endpoint + "/api/clouds",
      headers: { "X_API_VERSION": "1.5" },
      cookies: $account_cookies
  )
  $clouds = $cloud_response["body"]
end

define find_my_volumes($rs_shard, $account_cookies, $cloud) return $cloud_volumes do
    $rightscale_endpoint = "https://us-" + $rs_shard + ".rightscale.com"
    $cloud_href = $cloud["links"][0]["href"]
    $volumes_response = http_get(
        url: $rightscale_endpoint + $cloud_href + "/volumes?view=extended",
        headers: { "X_API_VERSION": "1.5" },
        cookies: $account_cookies
    )
    $cloud_volumes = $volumes_response["body"]
end