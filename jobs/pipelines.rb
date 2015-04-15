#!/usr/bin/env ruby
# encoding: utf-8
#
# poll RabbitMQ message board periodically and
# sent pipeline status to be displayed in a nested
# list.
# 
# TODO:
# * connect to any server, currently uses default which is
#   localhost
#
# Parameters taken from the configuration file:
#
# 1. when to remove a pipeline that is failed/completed
# from the display. In multiples of the refresh-rate.
KILL_DELAY=ENV['PIPELINES_DELAY'].to_i || 100
#
# 2. topic to listen to on RabbitMQ:
PIPELINES_TOPIC=ENV['PIPELINES_TOPIC'] || "ruffus_pipelines"
# 3. host running RabbitMQ
PIPELINES_HOST=ENV['PIPELINES_HOST'] || "localhost"
#

require 'bunny'
require 'json'

# hash with list of tasks in a project
projects = Hash.new()

# hash with projects to be removed from the list
# this is counted down when a project is in the 
# completed/failed stage
kill_list = Hash.new(0)

conn = Bunny.new(:host => PIPELINES_HOST, :automatically_recover => false)
queue = nil

SCHEDULER.every '10s' do

  if !conn.open?
    begin
      conn.start
      ch = conn.create_channel
      exchange = ch.topic(PIPELINES_TOPIC)
      queue = ch.queue("", :exclusive => true)
      # listen to all messages
      queue.bind(exchange, :routing_key => "#")
    rescue Bunny::TCPConnectionFailed => e
      send_event('project_pipelines', {
                   unordered: true,
                   items: [{'label' => "not connected to message queue"}]
                 })
      next
    end
  end

  next if queue.nil?
  # puts "## conn = #{conn}"

  # puts "################"
  begin
    queue.subscribe(:block => false) do |delivery_info, properties, body|
      project_name, pipeline_name, task_name = delivery_info.routing_key.split(".")

      # puts " [x] #{delivery_info.routing_key}:#{body}"
      
      key = project_name + "." + pipeline_name
      
      # remove key from kill_list as new information has
      # been receined
      kill_list.delete(key)

      # save task
      projects[key] = Hash.new() if !projects.has_key?(key)
      projects[key][task_name] = JSON.parse(body)

    end
  rescue Interrupt => _
    ch.close
    conn.close
  end

  items = projects.map do |key, tasks|
    
    subitems = tasks.map do |task_name, task_info|
      item = {
        'label' => task_name,
        'class' => task_info["task_status"],
        'result' => task_info["task_status"],
        'title' => task_name
      }
      item
    end

    status_counts = Hash.new(0)
    subitems.each{ |b| status_counts[b["class"]] += 1 }
    if status_counts.has_key?("failed")
       cls = "failed_project"
    elsif status_counts["running"] == 0 && status_counts["completed"] > 0
       cls = "completed_project"
    elsif status_counts["running"] > 0
       cls = "alive_project"
    else 
      cls = "update"
    end

    # add to kill list if not already present
    if !kill_list.has_key?(key) && 
        (cls == "failed_project" || cls == "completed_project")
      kill_list[key] = KILL_DELAY
    end

    item = {
      'label' => key,
      'class' => cls,
      'items' => subitems,
    }
    item
    
  end

  kill_list.each { |k, v| kill_list[k] = v - 1 }
  kill_list.select { |k, v| v <= 0 }.each do |k, v| 
    kill_list.delete(k)
    projects.delete(k)
  end

  # puts "#{items}"
  # puts "#{kill_list}"

  send_event('project_pipelines', {
               unordered: true,
               items: items
             })
end


