require 'octokit'
require 'json'
require 'yaml'
require 'time'
require 'prawn'
require 'prawn/emoji'
require 'slop'
require 'date'

if File.file?("config.yaml")
	configuration = YAML.load_file("config.yaml")
else
	print "config.yaml missing.  See config-sample.yaml"
	exit
end

time = Time.new

options = Slop.parse do |o|
	o.banner = "git-pullrequests.rb Usage: "
	o.string '-s', '--startdate', 'Start Date mm-dd-yyyy'
	o.string '-e', '--enddate', 'End Date mm-dd-yyyy'
	o.string '-r', '--repo', 'Repository'
	o.string '-o', '--org', 'Organization', default: ''
	o.string '-p', '--path', 'Path', default: ''
end

start_date = options[:startdate]
end_date = options[:enddate]
repo = options[:repo]
gitorg = options[:gitorg]
path = options[:path]

arg_error = ""

if !start_date 
	arg_error.concat("Start Date must be provided\n")
end

begin
	Date.strptime(start_date, '%m-%d-%Y')
rescue ArgumentError,TypeError
	arg_error.concat("Start Date is invalid\n")
end

if !end_date 
	arg_error.concat("End Date must be provided\n")
end

begin
	Date.strptime(end_date, '%m-%d-%Y')
rescue ArgumentError,TypeError
	arg_error.concat("End Date is invalid\n")
end

begin
	if end_date < start_date
		arg_error.concat("End Date must be after Start Date")
	end
rescue NoMethodError

end

if !repo
	arg_error.concat("GitHub repository must be provided (user/repo)\n")
end

if arg_error != ''
	puts arg_error
	puts options
	exit
end

pdf = Prawn::Document.new
pdf.font 'fonts/DejaVuSans.ttf'
pdf.repeat(:all) do
	pdf.text_box "Closed pull requests for " + repo + " " + path.to_s + " from between " + start_date + " and " + end_date + " - Report generated: " + time.strftime("%m/%d/%Y %I:%M%p"), :at => pdf.bounds.top_left, :size => 6
end

client = Octokit::Client.new(:access_token => configuration["apikey"])
client.auto_paginate = true
#client.per_page = 500

begin 
	user = client.user
rescue Octokit::TooManyRequests
	puts "API rate limit exceeeded"
	exit
end

org = client.org(gitorg)
print client.say("Retrieving closed pull requests for " + repo + " " + path.to_s + " from between " + start_date + " and " + end_date)
pdf.move_down 210
pdf.font_size(22)
pdf.text "Closed Pull Requests Report", :align => :center
pdf.move_down 100
pdf.font_size(18)
pdf.text "Repository: " + repo, :align => :right
if path != ''
	pdf.text "Path: " + path.to_s, :align => :right
end
pdf.text "From " + start_date + " to " + end_date, :align => :right
pdf.move_down 120
pdf.font_size(16)
pdf.text "Report generated: " + time.strftime("%m/%d/%Y %I:%M%p"), :align => :center

# Get all of the closed pull requests for the repo because github doesn't give us a better way...

begin
	pullrequests = client.pull_requests(repo, :state => 'closed' )
rescue Octokit::NotFound
	print "Repository not found"
	exit
end

#puts pullrequests.inspect
#exit

pullrequests.each do |pullrequest|
# client.pull_merged?(repo,pullrequest['number']) &&
	if pullrequest['merged_at']
		if Date.parse(pullrequest['merged_at'].strftime('%Y-%m-%d %H:%M %Z'),'%m-d-%Y') >= Date.strptime(start_date, '%m-%d-%Y') && Date.parse(pullrequest['merged_at'].strftime('%Y-%m-%d %H:%M %Z'),'%m-d-%Y') <= Date.strptime(end_date, '%m-%d-%Y')
			files = client.pull_request_files(repo,pullrequest['number'])
			files.each do |file|
				if file['filename'] == path || !path || path == ''
					pdf.start_new_page(:top_margin => 50)
					pdf.font_size(22)
					pdf.text pullrequest['title'] + "(#" + pullrequest['number'].to_s + ")"
					pdf.font_size(9)
					pdf.text "Created at: " + pullrequest['created_at'].strftime('%Y-%m-%d %H:%M %p') + " by " + pullrequest['user']['login'] + "\n\n"
					pdf.text "Conversation: \n"
					pdf.text pullrequest['user']['login'] +  " said at " + pullrequest['created_at'].strftime('%Y-%m-%d %H:%M %p') + ": " + pullrequest['body'] + "\n"
					client.issue_comments(repo,pullrequest['number']).each do |comment|
						pdf.text comment['user']['login'] + " said at " + comment['updated_at'].strftime('%Y-%m-%d %H:%M %p') + ": " + comment['body'] + "\n"
					end
					pdf.text "\n"
					pdf.text "Reviews \n\n"
					reviews = client.pull_request_reviews(repo,pullrequest['number'],:accept => 'application/vnd.github.v3.raw+json')
					if reviews.count < 1
						pdf.text "No Reviews \n\n"
					else
						reviews.each do |review|
							pdf.text "Reviewed by: " + review['user']['login'] + "\n"
							pdf.text "Reviewed at: " + review['submitted_at'].strftime('%Y-%m-%d %H:%M %p') + "\n"
							client.pull_request_review_comments(repo,pullrequest['number'],review['id'],:accept=>'application/vnd.github.black-cat-preview').each do |comment|
								pdf.text "Comment: " + comment['body'] + "\n"
								pdf.text "Relevant Lines in " + comment['path'] + ": \n" + comment['diff_hunk'] + "\n"
							end
							pdf.text "Review State: " + review['state'] + "\n"
							
						end
					end
					pdf.text "Merged at: " + pullrequest['merged_at'].strftime('%Y-%m-%d %H:%M %p') + "\n"
					pdf.text "\n"
					
					pr_commits = client.pull_request_commits(repo,pullrequest['number'])
					pr_commits.each do |pr_commit| 
						commit =  client.commit(repo,pr_commit['sha'])
						pdf.text "Commit by " + commit['commit']['committer']['name'] + " on " + commit['commit']['committer']['date'].strftime('%Y-%m-%d %H:%M %p') + "\n"
						pdf.text "Commit message: " + commit['commit']['message'] + "\n"
						pdf.text "URL: " + commit['html_url'] + "\n"
						pdf.text "---------------\n"
						pdf.text "Additions: " + commit['stats']['additions'].to_s + " - Deletions: " + commit['stats']['deletions'].to_s
						commit['files'].each do |file|
							pdf.text "Changes: \n\n"
							if file['patch']
								pdf.text file['patch'] + "\n\n"
							end
							pdf.text "End of change \n"
						end
					end
				end
			end
		end
	end
end
if path.nil? 
	path = ''
end
pdf.render_file "reports/Pull Requests - " + repo.gsub("\/","-").to_s + " " + path.gsub("\/","-") + " - " + start_date.gsub("\/","-").to_s + " - " + end_date.gsub("\/","-").to_s + " - Report.pdf"





