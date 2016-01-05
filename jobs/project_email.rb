#!/usr/bin/env ruby
# encoding: utf-8
#
# return list of projects flagged according to when an emal
# was last sent. If within MAX_DAYS, the status is "good", otherwise
# it is labeled as "BAD"

# glob for email repositories to scan
EMAIL_USERNAME=ENV["PROJECT_EMAIL_USERNAME"]
EMAIL_PASSWORD=ENV["PROJECT_EMAIL_PASSWORD"]

MULTIPLE=ENV["PROJECT_EMAIL_OPTIONS"] || ""
EMAIL_MAX_DAYS=ENV["PROJECT_EMAIL_MAX_DAYS"].to_i || 35

PROJECTS_CLOSED=ENV['PROJECT_EMAIL_CLOSED'].split(',') | []

require 'csv'
require 'time'
require 'date'
require 'gmail'

SCHEDULER.every '1h', :first_in => '1s' do |job|

  d = Date.today - EMAIL_MAX_DAYS

  Gmail.connect(EMAIL_USERNAME, EMAIL_PASSWORD) do |gmail|
    gmail.logged_in?
    emails = gmail.inbox.emails(:after => d)

    last_email = Hash.new(0)

    emails.each do |email|
      d = Date.parse(email.date)
      days = Time.now.to_date - d    
      email.sender.each do |sender|
        m = REGEX.match(sender.name)
        next if m.nil?
        last_email[m["project_id"]] = days.to_i
      end
    end
  end

  items = last_email.reject { |project_id, days|
    PROJECTS_CLOSED.select {
      |name| project_id == name }.length > 0 }.map do |project_id, days|

    {
    'label' => "proj#{project_id}",
    'class' => days < EMAIL_MAX_DAYS ? "good" : "bad",
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


