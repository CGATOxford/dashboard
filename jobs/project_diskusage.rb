#!/usr/bin/env ruby
# encoding: utf-8
#
# return disk usage per project as list of items (row/value)
# 
# Parameters taken from the configuration file:
#
# Location of isilon status files. This should be a glob expression
# and the most recent file is used.
REPORT_GLOB=ENV['PROJECT_IFS_STATS_GLOB']

require 'csv'
require 'time'
require 'date'
require 'nokogiri'

# Top x number of projects to report, "other" is added.
REPORT=9

SCHEDULER.every '1h', :first_in => '1s' do |job|

  files = Dir.glob(REPORT_GLOB)
  if files.empty?
    puts "scholar.rb: could not find data in #{REPORT_GLOB}"
    break
  end

  recent = files.max_by {|f| File.mtime(f)}

  
  File.open(recent) do |f|
    doc = Nokogiri::XML(f.read())

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
end
