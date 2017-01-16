name "RS API Testing"
rs_ca_ver 20131202
short_description "some api testing"

operation "launch" do
  definition "create_user"
end




define create_user() do
  $first_name = "Mitch"
  $last_name = "Gerdisch"
  $company_name = "jesslex"
  $email_address = "rstest10@jesslex.com"
  $phone_number = "6305551212"
  $password = "Gerdisch1"
  
#  $response = http_post(
#    url: "https://us-4.rightscale.com/api/users",
#    body: {
#      first_name: $first_name,
#      last_name: $last_name,
#      company: $company_name,
#      email: $email_address,
#      phone: $phone_number,
#      password: $password
#    },
#    headers: { 
#      "X_API_VERSION": "1.5"
#    }
#  )
  
  $response = http_get(
    url: "https://us-4.rightscale.com/api/deployments",
    headers: { 
      "X_API_VERSION": "1.5"
    }
  )
  
  
      rs.audit_entries.create(
      notify: "None",
    audit_entry: {
      auditee_href: "/api/deployments/472508004",
      summary: "File read",
      detail: join(["header: ",$response["header"]," body: ",$response["body"]])
    }
  )
end


#define user_create() do
#  
#  $response = http_get(
#    url: "https://s3.amazonaws.com/mitch-morpher/user_file.txt"
#  )
#  $users = split($response["body"], "\n")
#  
#  foreach $user in $users do
#    $user_data = split($user, ",")
#    sub on_error: handle_error() do
#      @task = rs.users.create(first_name: $user_data[0], last_name: $user_data[1], company: $user_data[2], email: $user_data[3], phone: $user_data[4], password: $user_data[5])
#    end
#    raise "Stopping after one"
#  end
#  
#end
#
#
#define handle_error() do
#  $error_message = $_error["message"]
#  $error_message_bits = split($error_message, " ")
#  foreach $error_message_bit in $error_message_bits do
#    if $error_message_bit =~ /\/api\/users\/[0-9]+/
#      call log("Found user", $error_message_bit, "None")
#    end
#  end
#  $_error_behavior = "skip"
#end
#
#
#define user_create() do
#  
#  $response = http_get(
#    url: "https://s3.amazonaws.com/mitch-morpher/user_file.txt"
#  )
#  $users = split($response["body"], "\n")
#  
#  foreach $user in $users do
#    $user_data = split($user, ",")
#    $create_resp = http_post(
#      url: "https://my.rightscale.com/api/usrs",
#      body: {
#      
#    sub on_error: handle_error() do
#      @task = rs.users.create(first_name: $user_data[0], last_name: $user_data[1], company: $user_data[2], email: $user_data[3], phone: $user_data[4], password: $user_data[5])
#    end
#    raise "Stopping after one"
#  end
#  
#end