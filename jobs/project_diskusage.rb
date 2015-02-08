# return last email send in a project
# 
require 'csv'
require 'time'
require 'date'
require 'nokogiri'

REPORT_DIRECTORY="/ifs/var/mon/isilon-disk/isilon-xml/"

# Top x number of projects to report
REPORT=10

SCHEDULER.every '1h', :first_in => '1s' do |job|

  # returns a single line
  # text = `python /ifs/devel/andreas/cgat/scripts/cgat_scan_email.py -v 0 --glob="#{EMAIL_GLOB}" #{MULTIPLE}`

  text = `cat #{REPORT_DIRECTORY}/scheduled_quota_report_1423185339.xml`
  doc = Nokogiri::XML(text)
  
  nodes = doc.xpath("//domains/domain").select{ |node|
    node.attributes["type"].value == "ALL" }

  usages = nodes.map { |node|
    path = node.children.select { |c| c.name == "path" }[0].text
    element = node.children.select { |c|
       c.name == "usage" && c.attributes["resource"].value == "physical" }[0]
    diskusage = element.text.to_i
    next unless path[/^\/ifs\/projects\//]
    next if path[/^\/ifs\/projects\/sftp/]
    { :path => path, :usage => diskusage }
  }
  usages.select!{ |f| !f.nil?}
  usages.sort_by!{ |f| -f[:usage] }

  total = usages[REPORT..usages.count].map{ |f| f[:usage]}.inject{|sum,x| sum + x}
  usages = usages[0..REPORT-1]
  usages << { :path => "other", :usage => total }

  rows = {}
  usages.each { |item|
    rows[item[:path]] = {
      label: item[:path],
      value: (item[:usage] / 1000000000000.0).round(1),
    }
  }

  send_event('project_diskusage', {
               items: rows.values })
end
