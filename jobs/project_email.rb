# return last email send in a project
# 
require 'csv'
require 'time'
require 'date'

# glob for email repositories to scan
EMAIL_GLOB="/ifs/home/andreas/mail/Local Folders/Projects.sbd/*"
MULTIPLE="--multiple=TybulewiczLab=010:036 --multiple=DrakeLab=013:034:035 --multiple=KnightLab=005:043"
MAX_DAYS=35


SCHEDULER.every '1h', :first_in => '1s' do |job|

  # returns a single line
  text = `python /ifs/devel/andreas/cgat/scripts/cgat_scan_email.py -v 0 --glob="#{EMAIL_GLOB}" #{MULTIPLE}`

  # text = `cat /ifs/devel/andreas/dashboard/jobs/out.txt`

  last_email = Hash.new(0)

  text.encode('UTF-8', :invalid => :replace, :replace => '').split("\n").each do |line|

    next unless line[/project_id/].nil?
    CSV.parse(line, {:col_sep => "\t"} ) do |row|
       project_id, date, filename, scanned = row
       d = Date.parse(date)
       days = Time.now.to_date - d
       last_email[project_id] = days.to_i
    end
  end

  CLOSED_PROJECTS = ENV['PROJECTS_CLOSED'].split(',') if ENV['PROJECTS_CLOSED']
  CLOSED_PROJECTS ||= []

  items = last_email.map do |project_id, days|

    to_skip = CLOSED_PROJECTS.select {
      |name| project_id == name }.length > 0
    next if to_skip

    item = {
    'label' => "proj#{project_id}",
    'class' => days < MAX_DAYS ? "good" : "bad",
    'url' => 'https://travis-ci.org/CGATOxford/cgat',
    'items' => [],
    }

    item

  end
  send_event('project_emails', {
               unordered: true,
               items: items
             })

end


