#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

PYPI_PROJECTS = ENV['PYPI_PROJECTS'].split(',') if ENV['PYPI_PROJECTS']

# SCHEDULER.every '3m', :first_in => 0 do |job|
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
