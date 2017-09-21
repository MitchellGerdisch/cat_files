# This CAT scans an account and identifies images that are currently in use.
# Where "currently in use" means used by a running or stopped instance, inactive server, custom MCI or custom ServerTemplate.

name "Governance - Identify Images In Use"
rs_ca_ver 20161221
short_description "Identfies images currently in use by running or stopped instances, inactive servers, and custom MCIs and ServerTemplates."

operation "launch" do
  description "List Images"
  definition "list_images"
end

define list_images() do

  call instance_images() retrieve $instance_images
  call server_images() retrieve $server_images
  call mci_images() retrieve $mci_images
  call st_images() retrieve $st_images
  
end

define instance_images() return $instance_images do
  # get list of connected clounds
  @clouds = rs_cm.clouds.get() #TEST filter: [ "name==EC2 us-east-1" ])
  
  # build collection of all the running-ish instances in all the clouds
  @instances = @clouds.instances(filter: [ "state<>inactive" ])
  
  
  
end

define server_images() return $server_images do
end

define mci_images() return $mci_images do
end

define st_images() return $st_images do
end
