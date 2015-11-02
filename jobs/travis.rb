require 'json'
require 'time'
require 'dashing'
require 'net/https'
require 'cgi'
require 'connection_pool'
require File.expand_path('../../lib/travis_backend', __FILE__)

$lastTravisItems = []

# exclude branches older than this:
TRAVIS_MAX_DAYS=60

TRAVIS_BACKEND = ConnectionPool.new(size: 3, timeout: 5) do
  TravisBackend.new
end

SCHEDULER.every '2m', :first_in => '1s' do |job|

  # scrutinizer_backend = ScrutinizerBackend.new
  builds = []
    
  # Only look at release branches (x.y) and master, not at tags (x.y.z)
  master_whitelist = /^(\d+\.\d+$|master)/  

  # accept all for branches
  branch_whitelist = /./
  branch_blacklist_by_repo = {}
  branch_blacklist_by_repo = JSON.parse(ENV['TRAVIS_BRANCH_BLACKLIST']) if ENV['TRAVIS_BRANCH_BLACKLIST']

  # TODO Move to configuration
  repo_slug_replacements = [/(silverstripe-australia\/|silverstripe-labs\/|silverstripe\/|silverstripe-)/,'']

  repo_slugs = TRAVIS_BACKEND.with do |conn|
    l = []
    if ENV['ORGAS']
      ENV['ORGAS'].split(',').each do |orga|
        l = l.concat(conn.get_repos_by_orga(orga).collect{|repo|repo['slug']})
      end
    end
    l
  end
	
  if ENV['REPOS']
    repo_slugs.concat(ENV['REPOS'].split(','))
  end

  repo_slugs.sort!

  branches = repo_slugs.map do |repo_slug|
    label = repo_slug
    label = repo_slug.gsub(repo_slug_replacements[0],
                           repo_slug_replacements[1]) if repo_slug_replacements
    item = {
      'label' => label,
      'class' => 'none',
      'url' => '',
      'items' => [],
    }

    # Travis info
    repo_branches = TRAVIS_BACKEND.with do |conn|
        conn.get_branches_by_repo(repo_slug)
    end

    if repo_branches and repo_branches['branches'].length > 0
      # Latest builds are listed under "branches",
      # but their corresponding branch name is
      # stored through the "commits" association
      items = repo_branches['branches']
        .select do |branch|
        commit = repo_branches['commits'].find{|commit|
          commit['id'] == branch['commit_id']}
        branch_name = commit['branch']
        
        # title=>"2014-03-07T19:25:04Z"
        next if branch['finished_at'].nil?
        days = Time.now.to_date - Date.parse(branch['finished_at'])
        # ignore "old" branches
        if days > TRAVIS_MAX_DAYS
          false
        # Ignore branches not in whitelist
        elsif not branch_whitelist.match(branch_name) 
          false
          # Ignore branches specifically blacklisted
        elsif branch_blacklist_by_repo.has_key?(repo_slug) and branch_blacklist_by_repo[repo_slug].include?(branch_name)
          false
        else
          true
        end
      end
        .map do |branch|
        commit = repo_branches['commits'].find{|commit|commit['id'] == branch['commit_id']}
        branch_name = commit['branch']
        {
          'class'=>(["passed","started","created"].include?(branch['state'])) ? 'good' : 'bad', # POSIX return code
          'label'=>branch_name,
          'title'=>branch['finished_at'],
          'result'=>branch['state'],
          'url'=> 'https://travis-ci.org/%s/builds/%d' % [repo_slug,branch['id']]
        } 
      end

      # set class of repository to bad if any are failing
      # item['class'] = (items.find{|b|b["class"] == 'bad'}) ? 'bad' : 'good'
      item['url'] = items.count ? 'https://travis-ci.org/%s' % repo_slug : ''
      # Only show items if some are failing
      item['items'] = (items.find{|b|b["class"] == 'bad'}) ? items : []
    end

    item
  end

  # Sort by name, then by status
  branches.sort_by! do|item|
    if item['class'] == 'bad'
      [1,item['label']]
    elsif item['class'] == 'good'
      [2,item['label']]
    else
      [3,item['label']]
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
