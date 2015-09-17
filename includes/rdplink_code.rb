# Returns and RDP link for the given server.
# This link can be provided as an output for a CAT and the user can select it to to get the
# RDP file just like in Cloud Management.
#
# The API 1.6 call requires knowing the shard and account number.
# Therefore at this time, those values have to be passed into the routine which likely means they
# are hard-coded in the CAT.
# If someone finds logic to get those values for a given instance of a running CAT, then that logic
# should be added to this routine and the parameters removed.
define get_rdp_link(@windows_server, $shard, $account_number) return $rdp_link do

  $rs_endpoint = "https://us-"+$shard+".rightscale.com"
    
  # Find the instance href for this server
  $instance_href = @windows_server.current_instance().href
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @windows_server, summary: to_s($instance_href), detail: ""})
 
  # Use the API 1.6 instances index call mainly to get the legacy ID which is what is used for the RDP link.
  $response = http_get(
    url: $rs_endpoint+"/api/instances",
    headers: { 
    "X-Api-Version": "1.6",
    "X-Account": $account_number
    }
   )
  
  # all the instances in the account
  $instances = $response["body"]
  
  # the instance that matches the server's instance href
  $instance_of_interest = select($instances, { "href" : $instance_href })[0]
  
  # the all important legacy id needed to create the RDP link
  $legacy_id = $instance_of_interest["legacy_id"]  
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @windows_server, summary: join(["legacy id: ", $legacy_id]), detail: ""})

  # get the instance's cloud ID also
  $cloud_id = $instance_of_interest["links"]["cloud"]["id"]
    
  # now build the rdp link of the form: https://my.rightscale.com/acct/ACCOUNT_NUMBER/clouds/CLOUD_ID/instances/INSTANCE_LEGACY_ID/rdp
  $rdp_link = "https://my.rightscale.com/acct/"+$account_number+"/clouds/"+$cloud_id+"/instances/"+$legacy_id+"/rdp"
  
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @windows_server, summary: "rdp link", detail: $rdp_link})

end