# Light config file
# to show you how easy, short and clean it is to configure your deployments !
# 
# Configuration for all repositories hooks: 28 lines
# Deployment of two projects on push: 14 lines

module.exports =
  port: 9001
  context: 
    sender: "no-reply@my-company.org"
    gitRetrieve: (branch = 'master')->
      [["git reset --hard HEAD"    , true]
       ["git checkout #{branch}"   , true]
       ["git pull origin #{branch}", true]]
    UID: www_data: 33

  exec: 
    uid: "{{UID.www_data}}"
    cwd: -> "/var/www/{{original.repository.name}}" + if @branch is 'master' then '' else '-{{branch}}'
    callback: -> @mail.callback 'error', 'success'

  mailer:
    auth: user: "gmail.user@gmail.com", pass: "userpass"
    options: from: "{{sender}}", to: "{{original.pusher.email}}"

    templates:
      success: 
        title: '{{original.repository.name}} deployment is a success'
        message: -> # can be a string or a function
          'Hi,\n' +
          'Successfully deployed at ' + (new Date).toUTCString() + ',\n\n' +
          'Console is:\n{{console}}'
        options: cc: 'testers@my-company.org'
      error: 
        title: '{{original.repository.name}} push hook is a failure'
        message: ->
          'Hi,\nError at ' + (new Date).toUTCString() + '\n\n' +
          'Console is:\n{{console}}'

  repos:
    'user/project-webapp': 'master, staging': ->
      @exec gitRetrieve().concat [
        'npm install'
        'bower install'
        'cake build'
      ]

    'user/project-api': 'master, staging': ->
      railsEnv = if @branch is 'master' then 'development' else @branch

      @exec gitRetrieve().concat [
        'bundle install'
        'rake db:migrate RAILS_ENV=' + railsEnv
        'touch restart.txt'
        'curl http://127.0.0.1/api'
      ]