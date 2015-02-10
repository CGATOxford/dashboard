# return last email send in a project
# 
require 'csv'
require 'time'
require 'date'
require 'nokogiri'

REPORT_GLOB="/ifs/var/mon/isilon-disk/isilon-xml/scheduled_quota_report_*.xml"

# Top x number of projects to report, "other" is added.
REPORT=9

SCHEDULER.every '1h', :first_in => '1s' do |job|

  recent = Dir.glob(REPORT_GLOB).max_by {|f| File.mtime(f)}
  file = File.open(recent)
  doc = Nokogiri::XML(file.read())
  
  nodes = doc.xpath("//domains/domain").select{ |node|
    node.attributes["type"].value == "ALL" }

  usages = nodes.map { |node|
    path = node.children.select { |c| c.name == "path" }[0].text
    element = node.children.select { |c|
       c.name == "usage" && c.attributes["resource"].value == "physical" }[0]
    diskusage = element.text.to_i
    next unless path[/^\/ifs\/projects\//]
    next if path[/^\/ifs\/projects\/sftp/]
    # remove "/ifs/projects/" prefix
    path = path[14..-1]
    { :path => path, :usage => diskusage }
  }
  usages.select!{ |f| !f.nil?}
  usages.sort_by!{ |f| -f[:usage] }

  total = usages[REPORT..usages.count].map{ |f| f[:usage]}.inject{|sum,x| sum + x}
  usages = usages[0..REPORT-1]
  usages << { :path => "other", :usage => total }

  rows = {}
  usages.each { |item|
    tb = (item[:usage] / 1000000000000.0).round(1)
    rows[item[:path]] = {
      label: "#{item[:path]}  (#{tb} Tb)",
      value: tb,
    }
  }

  send_event('project_diskusage', {
               items: rows.values })

end
