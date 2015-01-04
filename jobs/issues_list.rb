require 'json'
require 'time'
require 'dashing'
require 'date'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/github_backend', __FILE__)

# return list of most recent issues
SCHEDULER.every '1h', :first_in => '1s' do |job|
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

buzzwords = ['Paradigm shift', 'Leverage', 'Pivoting', 'Turn-key', 'Streamlininess', 'Exit strategy', 'Synergy', 'Enterprise', 'Web 2.0'] 
buzzword_counts = Hash.new({ value: 0 })

SCHEDULER.every '2s' do
  random_buzzword = buzzwords.sample
  buzzword_counts[random_buzzword] = { label: random_buzzword, value: (buzzword_counts[random_buzzword][:value] + 1) % 30 }
  
  send_event('recent_issues2', { items: buzzword_counts.values })
end
