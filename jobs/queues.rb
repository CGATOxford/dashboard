require 'time'
# return list of most recent issues
SCHEDULER.every '10s', :first_in => '1s' do |job|

  lines = `qstat -u "*"`

  running = 0
  waiting = 0

  lines.split("\n").each do |line|
    s = line.split()
    running += 1 if s[4] == "r"
    waiting += 1 if s[4] == "qw"	         
  end

  send_event('queues', {
               value1: running,
               value2: waiting} )
end

