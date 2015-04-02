#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# poll pypi for download status for a list of
# projects to be displayed as a list (label/value).
#
# This job requires the pypi-cli command line utility
# to be installed. 
#
# Parameters taken from the configuration file:
#
# 1. List of projects to obtain projects from
PYPI_PROJECTS = ENV['PYPI_PROJECTS'].split(',') if ENV['PYPI_PROJECTS']

SCHEDULER.every '1h', :first_in => '1s' do |job|

  items = PYPI_PROJECTS.map do |project|

    text = `pypi info #{project} | grep "Last month:"`
    downloads = /([0-9,]+)/.match(text)[1]
    downloads[","] = "" if downloads.include? ","
  
    item = {
      'label' => project,
      'value' => downloads.to_i }
    item

  end

  send_event('pypi_downloads', {
               items: items
             })

end # SCHEDULER
