# coding: utf-8

require 'sinatra'
require 'octokit'
require 'hashie'

require 'json'

require './comments'

# for sinatra
#set :environment, :production

def pr_comment_for_ios_cookpad(action)
  case action
  when 'opened'
    PR_OPEN_COMMENT_IOS
  when 'closed'
    PR_CLOSE_COMMENT_IOS
  else
    'nothing'
  end
end

def pr_comment_for_android_cookpad(action)
  case action
  when 'opened'
    PR_OPEN_COMMENT_ANDROID
  when 'closed'
    PR_CLOSE_COMMENT_ANDROID
  else
    'nothing'
  end
end

def default_pr_comment(action)
  case action
  when 'opened'
    PR_OPEN_COMMENT
  when 'closed'
    PR_CLOSE_COMMENT
  else
    'nothing'
  end
end


def get_pr_comment_with(repository, action)
  repo = repository.downcase
  case repo
  when 'ios' #full repository name
    pr_comment_for_ios_cookpad(action)
  when 'android' #full repository name
    pr_comment_for_android_cookpad(action)
  else
    default_pr_comment(action)
  end
end


def comment_for_pr(client, repository, issue_number, action)
  if action == 'opened' || action == 'closed'
    client.add_comment(repository, issue_number, get_pr_comment_with(repository, action))
  else
    'nothing'
  end
end

# extend class for original bot
class OctokitBot < Octokit::Client
  def initialize *args
    #Octokit.api_endpoint = 'http://api.github.dev'
    #Octokit.web_endpoint = 'http://github.dev'
    super
  end

  def sample_method
    'Hello Sample Method!'
  end
end

#===================================


post '/hook_sample' do
  delivery_id = request.env["HTTP_X_GITHUB_DELIVERY"]
  github_event = request.env['HTTP_X_GITHUB_EVENT']

  req_body =  Hashie::Mash.new(JSON.parse(request.body.read))

  repository = req_body.repository.full_name

  # start instance
  client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN']) # access_token for GitHub

  case github_event
  when 'pull_request'
    comment_for_pr(client, repository, req_body.pull_request.number, req_body.action)
  else
    'nothing'
  end
end

# sample repo is KazuCocoa/tagTestRepository

# Get title, number, open_issue, close_issue and due_on of milestones against the repository.
# @param repo,  A GitHub repository.
# @option :status, status of milestone. (default is open)
# @option :sort, :sort (created) Sort: <tt>created</tt>, <tt>updated</tt>, or <tt>comments</tt>.
# @option :dir (desc) Direction: <tt>asc</tt> or <tt>desc</tt>.
# @return [Array] A list of milestones. number, title, open_issues, close_issues and due_on.
get '/milestones' do
  error 400 unless params['repo']

  repository = params['repo']
  option = {
      state: params['status'] ||= 'open',
      sort: params['sort'] ||= 'created',
      direction: params['dir'] ||= 'desc'
  }

  client = OctokitBot.new(access_token: ['ACCESS_TOKEN'])

  # see https://developer.github.com/v3/issues/milestones/
  milestones = client.list_milestones(repository, option)

  milestones.map! do |milestone|
    {
        number: milestone.number,
        title: milestone.title,
        open_issue: milestone.open_issues,
        close_issue: milestone.close_issues,
        due_on: milestone.due_on
    }
  end

  "#{milestones}"
end

# Get list of assignees who assigned in the milestone.
# @param repo,  A GitHub repository.
# @option :number, A number of the Milestone. (if nil, you can obtain all milestones)
# @return [Array] A list of users who assigned.
# see https://developer.github.com/v3/issues/milestones/
# Example
# request: http://localhost/milestone/1/assignees?repo=repository_name
# return: [{"user name1"}, {"user name2"}}
get '/milestone/:number/assignees' do
  error 400 unless params['repo']

  repository = params['repo']
  option = {
      milestone: params[:number]
  }

  #client = OctokitBot.new(access_token: ['ACCESS_TOKEN'])
  client = OctokitBot.new() #the client doesn't comment. So, don't need ACCESS_TOKEN

  issues = client.list_issues(repository, option)
  assignees = issues.map do |issue|
    issue.assignee.login unless issue.assignee.nil?
  end
  assignees.compact!.uniq!

  "#{assignees}"
  # milestoneに紐づくissues一覧を取得するのによさそう
end

# Get list of issue number and titles which have no assignees.
# Example
# request: http://localhost/milestone/1/non_assignees/issues?repo=repository_name
# return: [{:number=>13, :title=>"2nd"}, {:number=>25, :title=>"3rd"}
# 毎朝、マイルストーンに設定されているかどうかを確認する。
get '/milestone/:number/non_assignees/issues' do
  error 400 unless params['repo']

  repository = params['repo']
  option = {
      milestone: params[:number],
      state: params[:state] ||= 'open'
  }

  #client = OctokitBot.new(access_token: ['ACCESS_TOKEN'])
  client = OctokitBot.new() #the client doesn't comment. So, don't need ACCESS_TOKEN


  # see https://developer.github.com/v3/issues/milestones/
  issues = client.list_issues(repository, option)

  #milestoneに対する操作を書く

  non_assineers = issues.map do |issue|
    if issue.assignee.nil?
      {
          number: issue.number,
          title: issue.title
      }
    end
  end

  non_assineers.compact!

  "#{non_assineers}"
  # milestoneに紐づくissues一覧を取得するのによさそう
end


get '/sample' do
  client = OctokitBot.new(access_token: ENV['ACCESS_TOKEN'])

  "#{client.sample_method}"
end

post '/crashlytics_sample' do
  File.write("crashlytics_logs.txt", "#{request.body.read}")
  status 200
end

get '/get_crashlytics_logs' do
  "#{File.read("crashlytics_logs.txt", :encoding => Encoding::UTF_8)}"
end
