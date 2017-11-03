# return diskspace free for number widget
# available diskspace is returned as percentage
# of free space.
# 
# 17.4T is removed as this is our critical threshold
# (80% disk usage)
OFFSET = 0

last = nil

SCHEDULER.every '1d', :first_in => '1s' do |job|

  # returns a single line
  line = `/bin/df | grep " /ifs/projects"`

  size, used, avail, percent, mount = line.split()
  # convert to Tb
  avail = avail.to_f
  # df shows 1k blocks
  avail /= 1024 * 1024 * 1024 
  avail -= OFFSET
  avail = avail.round(1)

  last = avail if last.nil?

  send_event('diskspace', {
               current: avail,
               last: last })

  last = avail

end

