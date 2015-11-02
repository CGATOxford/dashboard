#!/usr/bin/env ruby
require 'net/http'
require 'openssl'
require 'json'

# This job will track metrics of a github organisation or user

# Config
# ------
# example for tracking single user repositories
github_username = ENV['GITHUB_USERINFO_USERNAME'] || 'users/CGATOxford'
# example for tracking an organisations repositories
# github_username = 'orgs/foobugs'

SCHEDULER.every '1h', :first_in => 0 do |job|

  data = $github_pool.with do |conn| 
    response = conn.request(Net::HTTP::Get.new("/#{github_username}"))
    if response.code != "200"
      puts "github api error (status-code: #{response.code})\n#{response.body}"
    end
    JSON.parse(response.body)
  end

  send_event('github_userinfo_followers', current: data['followers'])
  send_event('github_userinfo_following', current: data['following'])
  send_event('github_userinfo_repos', current: data['public_repos'])
  send_event('github_userinfo_gists', current: data['public_gists'])

end
