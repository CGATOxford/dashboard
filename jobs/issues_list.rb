require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/github_backend', __FILE__)

# return list of most recent issues
SCHEDULER.every '10m', :first_in => '1s' do |job|
  backend = GithubBackend.new()
  issues = backend.recent_issues(
     :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
     :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
     :since=>ENV['SINCE'],
     :limit=>10)

  rows = {}
  issues.each { |issue|
    rows[issue.title] = {
      label: issue.title,
      value: ((Time.now - issue.created_at.to_time) / 1.day).to_int
    }
  }

  send_event('recent_issues', {
               items: rows.values })
end

