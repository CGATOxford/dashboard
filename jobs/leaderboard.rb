require 'json'
require 'time'
require 'dashing'
require 'octokit'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/leaderboard', __FILE__)

backend = GithubBackend.new()
leaderboard = Leaderboard.new(backend)

LEADERBOARD_MAX_ENTRIES = ENV["LEADERBOARD_MAX_ENTRIES"] ? ENV["LEADERBOARD_MAX_ENTRIES"].to_i : 20

ORGAS = ENV['ORGAS'].split(',') if ENV['ORGAS']
puts("LEADERBOARD: contributions to organizations: #{ORGAS}")

REPOS = ENV['REPOS'].split(',') if ENV['REPOS']
puts("LEADERBOARD: contributions to repos: #{REPOS}")

SCHEDULER.every '1m', :first_in => '1s' do |job|

  puts("LEADERBOAD: starting data acquisition")
  weighting = (ENV['LEADERBOARD_WEIGHTING'] || '').split(',')
    .inject({}) {|c,pair|c.merge Hash[*pair.split('=')]}
  
  edits_weighting = (ENV['LEADERBOARD_EDITS_WEIGHTING'] || '').split(',')
    .inject({}) {|c,pair|c.merge Hash[*pair.split('=')]}
  
  # last thirty days
  days_interval = 30
  date_until = Time.now.to_datetime
  # comparing current with last period, so need twice the interval
  date_since = date_until - days_interval*2
  
  actors = leaderboard.get( 
    :days_interval => days_interval,
    :date_until => date_until,
    :orgas=>ORGAS,
    :repos=>REPOS,
    :weighting=>weighting,
    :edits_weighting=>edits_weighting,
    :skip_orga_members=>(ENV['LEADERBOARD_SKIP_ORGA_MEMBERS'].split(',') if ENV['LEADERBOARD_SKIP_ORGA_MEMBERS']),
    :skip_members=>(ENV['LEADERBOARD_SKIP_MEMBERS'].split(',') if ENV['LEADERBOARD_SKIP_MEMBERS'])
  )

  puts("LEADERBOAD: got actors: #{actors}")
  
  rows = actors.map do |actor|

    actor_github_info = backend.user(actor[0])
    
    if actor_github_info['avatar_url']
      actor_icon = actor_github_info['avatar_url'] + "&s=32"
    elsif actor_github_info['email']
      actor_icon = "http://www.gravatar.com/avatar/" + Digest::MD5.hexdigest(actor_github_info['email'].downcase) + "?s=24"
    else
      actor_icon = ''
    end
    
    trend = GithubDashing::Helper.trend_percentage(
                                                   actor[1]['previous_score'], 
                                                   actor[1]['current_score']
                                                   )
    
    {
      nickname: actor[0],
      fullname: actor_github_info['name'],
      icon: actor_icon,
      current_score: actor[1]['current_score'],
      current_score_desc: '<strong>Score from current %d days period.</strong><br>%s' % [days_interval, actor[1]['current_desc']],
      previous_score: actor[1]['previous_score'],
      previous_score_desc: '<strong>Score from previous %d days period.</strong><br>%s' % [days_interval, actor[1]['previous_desc']],
      trend: trend,
      trend_class: GithubDashing::Helper.trend_class(trend),
      github: actor_github_info
    }
  end if actors
        
  # add members not active in recent period
  members = backend.organization_members('CGATOxford')
  present = Hash[rows.collect { |v| [v[:nickname], 1] }]
  members.select { |i| !present.has_key?(i[:login]) }.each do |item|
    
    actor_github_info = backend.user(item[:login])
    
    if actor_github_info['avatar_url']
      actor_icon = actor_github_info['avatar_url'] + "&s=32"
    elsif actor_github_info['email']
      actor_icon = "http://www.gravatar.com/avatar/" + Digest::MD5.hexdigest(actor_github_info['email'].downcase) + "?s=24"
    else
      actor_icon = ''
    end
    trend = GithubDashing::Helper.trend_percentage(0, 0)
    rows.push( { 
                 nickname: item[:login], 
                 fullname: actor_github_info['name'],
                 icon: actor_icon,
                 current_score: 0,
                 current_score_desc: 0,
                 previous_score: 0,
                 previous_score_desc: 0,
                 trend: trend,
                 trend_class: GithubDashing::Helper.trend_class(trend),
                 github: actor_github_info
               }
               )

  end if members 

  rows = rows.sort_by{ |f| -f[:current_score]}[0..LEADERBOARD_MAX_ENTRIES]
  
  send_event('leaderboard', {
               rows: rows,
               date_since: date_since.strftime("#{date_since.day.ordinalize} %b"),
               date_until: date_until.strftime("#{date_until.day.ordinalize} %b"),
             })

  puts("LEADERBOAD: data has been sent")
end
