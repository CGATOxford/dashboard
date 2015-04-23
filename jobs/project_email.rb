#!/usr/bin/env ruby
# encoding: utf-8
#
# return list of projects flagged according to when an emal
# was last sent. If within MAX_DAYS, the status is "good", otherwise
# it is labeled as "BAD"

# glob for email repositories to scan
EMAIL_GLOB=ENV["PROJECT_EMAIL_GLOB"]
EMAIL_SCRIPT=ENV["PROJECT_EMAIL_SCRIPT"]

MULTIPLE=ENV["PROJECT_EMAIL_OPTIONS"] || ""
MAX_DAYS=ENV["PROJECT_EMAIL_MAX_DAYS"].to_i || 35

PROJECTS_CLOSED=ENV['PROJECT_EMAIL_CLOSED'].split(',') | []

require 'csv'
require 'time'
require 'date'

SCHEDULER.every '1h', :first_in => '1s' do |job|

  # returns a single line
  text = `python #{EMAIL_SCRIPT} -v 0 --glob="#{EMAIL_GLOB}" #{MULTIPLE}`

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

  items = last_email.reject { |project_id, days|
    PROJECTS_CLOSED.select {
      |name| project_id == name }.length > 0 }.map do |project_id, days|

    {
    'label' => "proj#{project_id}",
    'class' => days < MAX_DAYS ? "good" : "bad",
    'url' => 'https://travis-ci.org/CGATOxford/cgat',
    'items' => [],
    }

  end

  items.sort_by! { |x| x["label"] }

  send_event('project_emails', {
               unordered: false,
               items: items
             })

end


