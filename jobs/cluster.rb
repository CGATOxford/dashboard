# count CPU and memory usage per server

# warning when at 80% usage
WARNING=80
# critical when at 95% usage
CRITICAL=95

SCHEDULER.every '2s', :first_in => '1s' do |job|

  lines = `qhost`

  cpu_items = []
  mem_items = []

  lines.split("\n").each do |line|
     s = line.split()
    
     cpu_items << 
        { name: s[0],
          progress: 100.0 * s[3].to_f / s[2].to_i,
      warning: WARNING,
      critical: CRITICAL,
      localScope: 0}


     next if s[5].nil? or s[4].nil?
     n = s[5].to_f
     d = s[4].to_f
     # Scale to Gb
     n /= 1000 if s[5][-1] == "M"
     d /= 1000 if s[4][-1] == "M"
       
     mem_items << 
      { name: s[0],
        progress: 100.0 * n / d,
        warning: WARNING,
        critical: CRITICAL,
        localScope: 0}
  end

  cpu_items.select! { |v| !v[:progress].nan? } 
  mem_items.select! { |v| !v[:progress].nan? } 

  send_event('cluster_cpu_usage', {title: "CPU usage", progress_items: cpu_items})
  send_event('cluster_mem_usage', {title: "Memory usage", progress_items: mem_items})

end
