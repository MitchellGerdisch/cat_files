name 'Set AWS VPC Names'
rs_ca_ver 20161221
short_description "Updates (discovered) AWS VPCs so they have a name value."
long_description "Discovered AWS VPCs do not have the name field set. 
This CAT sets the name field to the resource ID so that the VPC can then be referenced in CATs.

TO-DO: Use the AWS VPC plugin to find the name as it appears in AWS and use that."

operation 'launch' do
  description 'Launch the application'
  definition 'launch'
end

define launch() do
  
  # Get Amazon clouds - some have AWS in the name and some have EC2 in the name
  @aws_clouds = rs_cm.clouds.get(filter:["name==AWS"])
  @ec2_clouds = rs_cm.clouds.get(filter:["name==EC2"])
  @clouds = @aws_clouds + @ec2_clouds
  
  foreach @cloud in @clouds do
    # get the networks in the given cloud
    @networks = rs_cm.networks.get(filter: ["cloud_href=="+@cloud.href])
      
    foreach @network in @networks do
      # if the VPC does not have a name, set it to the resource UID
      if logic_not(@network.name)
        @network.name = @network.resource_uid
      end
    end
  end
end
