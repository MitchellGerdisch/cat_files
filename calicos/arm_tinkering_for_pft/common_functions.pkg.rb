# Required prolog
name 'LIB - Common functions'
rs_ca_ver 20160622
short_description "Common functions"

package "common/functions"

# Used to get a credential
# Requires admin permission
# TO-DO add logic that raises an error stating if cred name is not found
define get_cred($cred_name) return $cred_value do
  @cred = rs_cm.credentials.get(filter: "name=="+$cred_name, view: "sensitive") 
  $cred_hash = to_object(@cred)
  $found_cred = false
  $cred_value = ""
  foreach $detail in $cred_hash["details"] do
    if $detail["name"] == $cred_name
      $found_cred = true
      $cred_value = $detail["value"]
    end
  end
  
  if logic_not($found_cred)
    raise "Credential with name, " + $cred_name + ", was not found. Credentials are added in Cloud Management on the Design -> Credentials page."
  end
end

# Creates CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define createCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs_cm.credentials.get(filter: join(["name==",$cred_name]))
    if empty?(@cred) 
      $cred_value = join(split(uuid(), "-"))[0..14] # max of 16 characters for mysql username and we're adding a letter next.
      $cred_value = "a" + $cred_value # add an alpha to the beginning of the value - just in case.
      @task=rs_cm.credentials.create({"name":$cred_name, "value": $cred_value})
    end
  end
end

# replaces spaces and things with url encoding characters
define url_encode($string) return $encoded_string do
  $encoded_string = gsub($string, " ", "%20")
end


# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end

# log info
define log($summary, $detail) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: to_s($summary), detail: to_s($detail)})
end

# Checks if the account supports the selected cloud
define checkCloudSupport($cloud_name, $param_location) do
  # Gather up the list of clouds supported in this account.
  @clouds = rs_cm.clouds.get()
  $supportedClouds = @clouds.name[] # an array of the names of the supported clouds
  
  # Check if the selected/mapped cloud is in the list and yell if not
  if logic_not(contains?($supportedClouds, [$cloud_name]))
    raise "Your trial account does not support the "+$param_location+" cloud. Contact RightScale for more information on how to enable access to that cloud."
  end
end

# Imports the server templates found in the given map.
# It assumes a "name" and "rev" mapping
define importServerTemplate($stmap) do
  foreach $st in keys($stmap) do
    $server_template_name = map($stmap, $st, "name")
    $server_template_rev = map($stmap, $st, "rev")
    @pub_st=rs_cm.publications.index(filter: ["name=="+$server_template_name, "revision=="+$server_template_rev])
    @pub_st.import()
  end
end

define getUserLogin() return $userlogin do

  $deployment_description_array = lines(@@deployment.description)
  $userid="tbd"
  foreach $entry in $deployment_description_array do
    if include?($entry, "Author")
      $userid = split(split(lstrip(split(split($entry, ":")[1], "(")[0]), '[`')[1],'`]')[0]
    end
  end

  $userlogin = rs_cm.users.get(filter: "email=="+$userid).login_name

end

define getDeploymentId() return $deployment_id do
  $deployment_id = last(split(@@deployment.href,"/"))
end

define get_server_ssh_link($invSphere, $inAzure, $inArm) return $server_ip_address do
  
  # Find the instance in the deployment
  @linux_server = @@deployment.servers()
    
    # Get the appropriate IP address depending on the environment.
    if $invSphere
      # Wait for the server to get the IP address we're looking for.
      while equals?(@linux_server.current_instance().private_ip_addresses[0], null) do
        sleep(10)
      end
      $server_addr =  @linux_server.current_instance().private_ip_addresses[0]
    else
      # Wait for the server to get the IP address we're looking for.
      while equals?(@linux_server.current_instance().public_ip_addresses[0], null) do
        sleep(10)
      end
      $server_addr =  @linux_server.current_instance().public_ip_addresses[0]
    end 
    
    $username = "rightscale"
    if $inArm
      call getUserLogin() retrieve $username
    end

    $server_ip_address = "ssh://"+ $username + "@" + $server_addr
    
    # If in Azure classic then there are some port bindings that need to be reflected in the SSH link
    if $inAzure
       @bindings = rs_cm.clouds.get(href: @linux_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @linux_server.current_instance().href])
       @binding = select(@bindings, {"private_port":22})
       $server_ip_address = $server_ip_address + ":" + @binding.public_port
    end
end 