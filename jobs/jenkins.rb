#!/usr/bin/env ruby
# encoding: utf-8
#
# send jenkins build status for use with the list widget.
# 
# Parameters taken from the configuration file:
#
# Host IP of jenkins instance
JENKINS_HOST=ENV['JENKINS_HOST']

require 'jenkins_api_client'

SCHEDULER.every '2m', :first_in => '1s' do |job|

  @client = JenkinsApi::Client.new(:server_ip => JENKINS_HOST)
  # The following call will return all jobs matching 'Testjob'
  items = @client.job.list_all_with_details.map do |jenkins_job|
    
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

