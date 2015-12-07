#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'net/http'
require 'openssl'
require 'json'

# This job can track metrics of a public visible user or organisation’s repos
# by using the public api of github.
# 
# Note that this API only allows 60 requests per hour.
# 
# This Job should use the `List` widget

# Config
# ------
# example for tracking single user repositories
# github_username = 'users/ephigenia'
# example for tracking an organisations repositories
github_username = ENV['GITHUB_USER_REPOS_USERNAME'] || 'orgs/CGATOxford'
# number of repositories to display in the list
max_length = 7
# order the list by the numbers
ordered = true

SCHEDULER.every '10s', :first_in => 0 do |job|

  data = $GITHUB_POOL.with do |conn|
    response = conn.request(Net::HTTP::Get.new("/#{github_username}/repos"))
    if response.code != "200"
      puts "github api error (status-code: #{response.code})\n#{response.body}"
    end
    JSON.parse(response.body)
  end
  
  repos_forks = Array.new
  repos_watchers = Array.new
  data.each do |repo|
    repos_forks.push({
                       label: repo['name'],
                       value: repo['forks']
                     })
    repos_watchers.push({
                          label: repo['name'],
                          value: repo['watchers']
                        })
  end

  if ordered
    repos_forks = repos_forks.sort_by { |obj| -obj[:value] }
    repos_watchers = repos_watchers.sort_by { |obj| -obj[:value] }
  end

  puts "#{repos_watchers.slice(0, max_length)}"

  send_event('github_user_repos_forks', { items: repos_forks.slice(0, max_length) })
  send_event('github_user_repos_watchers', { items: repos_watchers.slice(0, max_length) })

end
