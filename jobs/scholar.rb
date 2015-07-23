# return number of publications per year and total number
# of publications.
# 
require 'time'

# number of top cited papers to include
TOP_CITED=10

# length of title to return
TITLE_LENGTH=40

# file needs to be manually downloaded, no 
# Google Scholar API.
SCHOLAR_GLOB=ENV["SCHOLAR_GLOB"]

# Regular expression mathing the following:
# S='<td class="gsc_a_t"><a href=... class="gsc_a_at">TITLE</a><div class="gs_gray">AUTHORS</div><div class="gs_gray">REFERENCE<span class="gs_oph">, YEAR</span></div></td><td class="gsc_a_c"><a href=... class="gsc_a_ac">CITATIONS</a></td>'

# Note that citations can be empty, in which case they are "&nbsp;"
# Multi-line mode essential as sometimes there are new-lines within
# titles.
REGEX=/<td class="gsc_a_t">.*<a.*>(?<title>.*)<\/a><div.*>(?<authors>.*)<\/div><div.*>(?<reference>.*)<span.*>, (?<year>\d+)<\/span.*><a.*>(?<citations>.*)<\/a>/m

SCHEDULER.every '10s', :first_in => '1s' do |job|

  # returns a single line
  recent = Dir.glob(SCHOLAR_GLOB).max_by {|f| File.mtime(f)}
  file = File.open(recent, :encoding=>"ISO-8859-1")

  all_text = file.read()
  # split table at </tr> tag and make sure
  # line starts with correct CSS class
  text = all_text.split("<tr ").select{
    |l| l[/^class="gsc_a_tr"/] }

  year_counts = Hash.new(0)
  total = 0

  # patch, add first and current year
  year_counts[2011] = 0
  year_counts[Time.now.year] = 0
  # list of most cited papers
  most_cited = []

  text.each{ |row| 
      m = REGEX.match(row)
      next if m.nil?
      # nbsp; will be converted to 0
      citations = m["citations"].to_i
      year = m["year"].to_i
      year_counts[m["year"].to_i] += 1
      total += 1
      most_cited.push([citations, year, m["title"]])
  }
      
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
               items: rows.values})

end

