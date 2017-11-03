require 'time'
# return list of most recent issues
SCHEDULER.every '10s', :first_in => '1s' do |job|

  lines = `qstat -u "*"`

  users_running = Hash.new(0)
  users_waiting = Hash.new(0)
  cores_running = Hash.new(0)
  cores_waiting = Hash.new(0)
  users = Hash.new(0)
  lines.split("\n").each do |line|
    next if line.start_with?("---")
    next if line.start_with?("job-ID")
    s = line.split()

    users_running[s[3]] += 1 if s[4] == "r"
    users_waiting[s[3]] += 1 if s[4] == "qw"
    cores_running[s[3]] += 1 if s[4] == "r" * s[8].to_i()
    cores_waiting[s[3]] += 1 if s[4] == "qw" * s[8].to_i()
    users[s[3]] += 1
  end

  rows = users.sort_by {|name, count| count} .reverse.map do |user, count|
    {cols: [
       {value: user, class: "row", title: "title", arrow: "arrow"},
       {value: users_running[user], class: "row", title: "title", arrow: "arrow"},
       {value: users_waiting[user], class: "row", title: "title", arrow: "arrow"},
       {value: cores_running[user], class: "row", title: "title", arrow: "arrow"},
       {value: cores_waiting[user], class: "row", title: "title", arrow: "arrow"}]}
  end
  
  send_event('queue_user_table', {
               headers: [
                 {value: "user"},
                 {value: "jobs"},
                 {value: ""},
                 {value: "cores"},
                 {value: ""}],
               rows: rows
             })

  send_event('queues', {value1: users_running.values.sum,
                        value2: users_waiting.values.sum} )
  
end

