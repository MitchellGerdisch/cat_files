
  
####################
# Helper functions #
####################
# Helper definition, runs a recipe on given server, waits until recipe completes or fails
# Raises an error in case of failure
define run_recipe(@target, $recipe_name) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

# Helper definition, runs a script on given server, waits until script completes or fails
# Raises an error in case of failure
define run_script(@target, $right_script_href) do
  @task = @target.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

# Helper definition, runs a script on all instances in the array.
# waits until script completes or fails
# Raises an error in case of failure
define multi_run_script(@target, $right_script_href) do
  @task = @target.multi_run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

####
# Author: Ryan Geyer
###
define get_array_of_size($size) return $array do
  $qty = 1
  $qty_ary = []
  while $qty <= to_n($size) do
    $qty_ary << $qty
    $qty = $qty + 1
  end

  $array = $qty_ary
end

####
# Loggers
# 
# Author: Ryan Geyer
####

define log_this($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end
 
###
# $notify acceptable values: None|Notification|Security|Error
###
define log($message, $notify) do
  rs.audit_entries.create(notify: $notify, audit_entry: {auditee_href: @@deployment.href, summary: $message})
end

define log_with_details($summary, $details, $notify) do
  rs.audit_entries.create(notify: $notify, audit_entry: {auditee_href: @@deployment.href, summary: $summary, detail: $details})
end

####
# get clouds
#
# Author: Ryan Geyer
####
define get_clouds_by_rel($rel) return @clouds do
  @@clouds = rs.clouds.empty()
  concurrent foreach @cloud in rs.clouds.get() do
    $rels = select(@cloud.links, {"rel": $rel})
    if size($rels) > 0
      @@clouds = @@clouds + @cloud
    end
  end
  @clouds = @@clouds
end

define get_execution_id() return $execution_id do
  #selfservice:href=/api/manager/projects/12345/executions/54354bd284adb8871600200e
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
  $href_tag = concurrent map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(selfservice:href)"
      $tag = $current_tag
    end
  end

  if type($href_tag) == "array" && size($href_tag) > 0
    $tag_split_by_value_delimiter = split(first($href_tag), "=")
    $tag_value = last($tag_split_by_value_delimiter)
    $value_split_by_slashes = split($tag_value, "/")
    $execution_id = last($value_split_by_slashes)
  else
    $execution_id = "N/A"
  end

end

# Author: Ryan Geyer
#
# Converts a server to an rs.servers.create(server: $return_hash) compatible hash
#
# @param @server [ServerResourceCollection] a Server collection containing one
#   server (what happens if it contains more than one?) to be converted
#
# @return [Hash] a hash compatible with rs.servers.create(server: $return_hash)
define server_definition_to_media_type(@server) return $media_type do
  $top_level_properties = [
    "deployment_href",
    "description",
    "name",
    "optimized"
  ]
  $definition_hash = to_object(@server)
  $media_type = {}
  $instance_hash = {}
  foreach $key in keys($definition_hash["fields"]) do
    call log_with_details("Key "+$key, $key+"="+to_json($definition_hash["fields"][$key]), "None")
    if contains?($top_level_properties, [$key])
      $media_type[$key] = $definition_hash["fields"][$key]
    else
      $instance_hash[$key] = $definition_hash["fields"][$key]
    end
  end
  # TODO: Should be able to assign this directly in the "else" block above once
  # https://bookiee.rightscale.com/browse/SS-739 is fixed
  $media_type["instance"] = $instance_hash
end

