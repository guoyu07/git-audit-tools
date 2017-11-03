# git-audit-tools

## What?
git-pullrequests is a simple ruby command line utility to retrieve the closed pull requests, and associated commits, for a specified repository, file (optional), and date range.  The results are saved to a PDF.
## Why?
A lot of compliance assessment relevant information is retained in pull requests.  During a recent assessment an individual had to manually load and PDF print the details of each pull request for review.  Tedious, unnecessary work well suited for a script.
## Installation
Tested in ruby-2.4.2
Bundler installed
1. git clone https://github.com/eightzerobits/git-audit-tools.git
2. bundle
3. ruby git-pullrequests.rb
## Instructions
The tool takes up to 5 parameters:
* -s, --startdate  REQUIRED: Start Date mm-dd-yyyy 
* -e, --enddate    REQUIRED: End Date mm-dd-yyyy
* -r, --repo       REQUIRED: Repository (eightzerobits/git-audit-tools)
* -o, --org        OPTIONAL: Organization (eightzerobits)
* -p, --path       OPTIONAL: Restrict pull requests to those including changes to this file path (i.e. fonts/DejaViSans.ttf)

The output is automatically stored as a PDF in the reports folder.