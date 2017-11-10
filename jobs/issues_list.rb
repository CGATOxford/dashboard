require 'time'
require File.expand_path('../../lib/github_backend', __FILE__)

GITHUB_BACKEND_POOL2 = ConnectionPool.new(size: 3, timeout: 5) do
  conn = GithubBackend.new()
  conn
end

ISSUES_MAX_ENTRIES = ENV["ISSUES_MAX_ENTRIES"] ? ENV["ISSUES_MAX_ENTRIES"].to_i : 25

# return list of most recent issues
SCHEDULER.every '1h', :first_in => '5s' do |job|

  issues = GITHUB_BACKEND_POOL2.with do |conn|
    conn.recent_issues(
                       :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
                       :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
                       :since=>ENV['SINCE'],
                       :limit=>30)
  end

  rows = {}
  issues.each { |issue|
    begin
      rows[issue.title] = {
        label: issue.title,
        value: ((Time.now - issue.created_at.to_time) / 1.day).to_int
      }
    rescue NoMethodError => exception
      puts "# issues_list.rb: error ignored #{exception}"
    end
  }

  items = rows.values.sort_by{ |f| f[:value] }[0..ISSUES_MAX_ENTRIES]

  send_event('recent_issues', {
               items: items })
end

