require 'json'
require 'time'
require 'travis'
require 'connection_pool'
require 'pry'

$lastTravisItems = []

# exclude branches older than this, can't seem to find information
# on active/inactive branches in API.
TRAVIS_MAX_DAYS=60

TRAVIS_BACKEND = ConnectionPool.new(size: 3, timeout: 5) do
  Travis::Client.new(access_token: ENV['TRAVIS_TOKEN'])
end

SCHEDULER.every '2m', :first_in => '1s' do |job|

  # Only look at release branches (x.y) and master, not at tags (x.y.z)
  master_whitelist = /^(\d+\.\d+$|master)/  

  # accept all for branches
  branch_whitelist = /./
  repo_blacklist = []
  # remove quotes around array
  repo_blacklist = (ENV['TRAVIS_REPO_BLACKLIST'].split(",") if ENV['TRAVIS_REPO_BLACKLIST'])
  branch_blacklist_by_repo = {}
  # branch_blacklist_by_repo = JSON.parse(ENV['TRAVIS_BRANCH_BLACKLIST']) if ENV['TRAVIS_BRANCH_BLACKLIST']

  TRAVIS_BACKEND.with do |client|

    next if client.user.repositories.nil?

    branches = client.user.repositories.map do |repo|

      if !repo.active?
        next
      end
      
      if repo_blacklist.include?(repo.name)
        next
      end
      
      item = {
        'label' => repo.name,
        'class' => 'none',
        'url' => '',
        'items' => [],
      }

      puts("TRAVIS: working on repository #{repo.name}")
      if repo.branches.nil?
        puts("TRAVIS: no branches for #{repo.name} - skipping")
        puts("TRAVIS: #{repo}")
        next
      end
      
      if repo.branches and repo.branches.size > 0

        items = repo.branches.each_value
                  .select do |branch|

          branch_name = branch.branch_info

          if branch.finished_at.nil?
            false
          # ignore "old" branches
          elsif Time.now.to_date - branch.finished_at.to_date > TRAVIS_MAX_DAYS
            false
          # Ignore branches not in whitelist
          elsif not branch_whitelist.match(branch_name) 
            false
          # Ignore branches specifically blacklisted
          elsif branch_blacklist_by_repo.has_key?(repo) and branch_blacklist_by_repo[repo].include?(branch_name)
            false
          else
            true
          end
        end
                  .map do |branch|
          branch_name = branch.branch_info
          {
            'class'=>(["passed","started","created"].include?(branch.state)) ? "good" : "bad",
            'color'=>branch.color,
            'label'=>branch_name,
            'title'=>branch.finished_at,
            'result'=>branch.state,
            'url'=> 'https://travis-ci.org/%s/builds/%d' % [repo.name, branch.id]
          }
        end

        next if items.nil?
        
        # remove any nil's
        items = items.compact
        
        # puts("#{items}")
        # set class of repository to bad if any are failing        
        item['class'] = (items.find{|b| b["class"] == "bad"}) ? 'bad' : 'good'
        item['url'] = items.count ? 'https://travis-ci.org/%s' % repo.name : ''
        # Only show items if some are failing
        item['items'] = (items.find{|b| b["class"] == "bad"}) ? items : []
      end
      puts("TRAVIS: completed repository #{repo.name}")
      item
    end

    branches = branches.compact
    
    # Sort by name, then by status
    branches.sort_by! do |item|
      if item['class'] == 'bad'
        [1, item['label']]
      elsif item['class'] == 'good'
        [2, item['label']]
      else
        [3, item['label']]
      end
    end

    # output master
    master = branches.map do |repo|
      s = repo['items'].select{|x| master_whitelist.match(x['label'])}
      item = {
        'label' => repo['label'],
        'class' => (s.find{|b| b["class"] == 'bad'}) ? 'bad' : 'good',
        'url' => repo['url'],
        'items' => s,
      }
    end

    if branches != $lastTravisItems
      send_event('travis_master', {
                   unordered: true,
                   items: master,
                 })
      send_event('travis_branches', {
                   unordered: true,
                   items: branches,
                 })
    end
    
    $lastTravisItems = branches
  end
  
end
