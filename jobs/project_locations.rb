require 'csv'

FILENAME="/ifs/home/andreas/projects.tsv"

SCHEDULER.every '10s', :first_in => '1s' do

  markers = Array.new()
  CSV.foreach(FILENAME, :col_sep => "\t") do |row|
      project_id, department, institution, town, longitude, latitude = row
     markers << [longitude.to_f, latitude.to_f]
  end

  send_event('map', markers: markers)

end
