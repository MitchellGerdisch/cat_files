# Required prolog
name 'LIB - Common functions'
rs_ca_ver 20160622
short_description "Common functions"

package "common/functions"

# Used to get a credential
# Requires admin permission
define get_cred($cred_name) return $cred_value do
  @cred = rs_cm.credentials.get(filter: "name=="+$cred_name, view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = ""
  foreach $detail in $cred_hash["details"] do
    if $detail["name"] == $cred_name
      $cred_value = $detail["value"]
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