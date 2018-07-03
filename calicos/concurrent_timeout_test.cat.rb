name 'Concurrent with Timeout Example'
rs_ca_ver 20161221
short_description  "Example of Concurrent with Timeout"


operation 'launch' do
  description 'Launch the application'
  definition 'conc_test'
end

define conc_test() do
  $wait1 = 0
  $wait2 = 0
  $timeout = "2m"
    concurrent return $wait1, $wait2 do
      sub timeout: $timeout, on_timeout: skip do
         call wait_1min() retrieve $wait1
      end
      sub timeout: $timeout, on_timeout: skip do
        call wait_3min() retrieve $wait2
      end
    end
    
    call log("wait1: "+$wait1+"; wait2: "+$wait2, "")
end

define wait_1min() return $wait_num do
  sleep(60)
  $wait_num = 1
  call log("1 minute wait - "+to_s(now()), "")
end

define wait_3min() return $wait_num do
  sleep(60)
  $wait_num = 1
  call log("1 minute into 3 minute wait - "+to_s(now()), "")
  sleep(30)
  $wait_num = 2
  call log("1.5 minutes into 3 minute wait - "+to_s(now()), "")
  sleep(30)
  $wait_num = 3
  call log("2 minutes into 3 minute wait - "+to_s(now()), "")
  sleep(60)
  $wait_num = 4
  call log("3 minute wait - "+to_s(now()), "")
end

define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end