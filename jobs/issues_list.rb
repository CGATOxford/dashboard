require 'time'
require 'dashing'

GITHUB_BACKEND_POOL2 = ConnectionPool.new(size: 3, timeout: 5) do
  conn = GithubBackend.new()
  conn
end

# return list of most recent issues
SCHEDULER.every '1h', :first_in => '5s' do |job|
  
  issues = GITHUB_BACKEND_POOL2.with do |conn|
    conn.recent_issues(
                       :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
                       :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
                       :since=>ENV['SINCE'],
                       :limit=>10)
  end

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

