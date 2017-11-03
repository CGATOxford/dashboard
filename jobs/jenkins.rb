#!/usr/bin/env ruby
# encoding: utf-8
#
# send jenkins build status for use with the list widget.
# 
# Parameters taken from the configuration file:
#
# Host IP of jenkins instance
JENKINS_HOST=ENV['JENKINS_HOST']

require 'connection_pool'
require 'jenkins_api_client'

JENKINS_POOL = ConnectionPool.new(size: 3, timeout: 5) do
   JenkinsApi::Client.new(:server_ip => JENKINS_HOST)
end

SCHEDULER.every '2m', :first_in => '1s' do |job|

  puts("JENKINS will be queried on #{JENKINS_HOST}")

  data = JENKINS_POOL.with do |conn|
    conn.job.list_all_with_details
  end

  # The following call will return all jobs matching 'Testjob'
  items = data.map do |jenkins_job|
    {
      'label' => jenkins_job['name'],
      'class' => (jenkins_job['color'] == "blue" ) ? 'good' : 'bad',
      'url' => jenkins_job['url'],
      'items' => [],
    }
  end

  send_event('jenkins', {
               unordered: true,
               items: items,
             })
end

