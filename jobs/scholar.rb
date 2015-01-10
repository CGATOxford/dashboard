# return number of publications per year and total number
# of publications.
# 
require 'csv'
require 'time'

# number of top cited papers to include
TOP_CITED=10

# length of title to return
TITLE_LENGTH=40


SCHEDULER.every '1d', :first_in => '1s' do |job|

  # returns a single line
  # csv = `python /ifs/devel/andreas/scholar.py/scholar.py --filename-phrases=/ifs/devel/andreas/github-dashing/jobs/phrases.list --csv`
  text = `cat /ifs/devel/andreas/github-dashing/jobs/test.txt`

  year_counts = Hash.new(0)
  total = 0

  # patch, add first and current year
  year_counts[2011] = 0
  year_counts[Time.now.year] = 0
  # list of most cited papers
  most_cited = []

  text.encode('UTF-8', :invalid => :replace, :replace => '').split("\n").each do |line|
    CSV.parse(line, {:col_sep => '|'} ) do |row|
      title, url, year, num_citations, num_versions, cluster_id, url_pdf, url_citations, url_versions, url_citation, excerpt = row
    
      year_counts[year.to_i] += 1
      total += 1
      most_cited.push([num_citations.to_i, year.to_i, title])
      end
    end

  series = []
  year_counts.keys.sort.each do |year|
    series << {
      x: Date.new(year).to_time.to_i,
      y: year_counts[year],
    }
  end

  most_cited.sort!.reverse!

  trend_class = "up"

  send_event(
             'papers_published', 
             {
               # Series graph expects a stacked graph
               series: [series],
               displayedValue: total,
               difference: total,
               trend_class: trend_class,
               arrow: '',
             })


  rows = {}
  most_cited.take(TOP_CITED).each { |article|
    num_citations, year, title = article
    rows[title] = {
      label: title[0, TITLE_LENGTH] + "...    (#{year})",
      value: num_citations,
    }
  }

  send_event('topcited_papers', {
               items: rows.values })



end

