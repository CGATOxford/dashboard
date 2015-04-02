#!/usr/bin/env ruby
# encoding: utf-8
#
# return project locations for map widget
# 
# Parameters taken from the configuration file:
#
# Location of table with project status information. This should be
# a tab-separated file with the following 6 columns:
# project_id, _, _, _, longitude, latitude
FILENAME=ENV['PROJECT_SUMMARY']

require 'csv'

SCHEDULER.every '10s', :first_in => '1s' do

  markers = Array.new()
  CSV.foreach(FILENAME, :col_sep => "\t") do |row|
      project_id, department, institution, town, longitude, latitude = row
     markers << [longitude.to_f, latitude.to_f]
  end

  send_event('map', markers: markers)

end
