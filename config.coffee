# Default config file
# usualy located in /etc/
# 
# You add all your repository there
# and actions to do when the repository is updated on github

# Some preliminary definitions and functions that will be used
# in multiple repositories

UID = 
  www_data: 33
  user1: 1001
  user2: 1002

# Basicaly it's the same everywhere to get last version of a project
# so we can define a method for that, which will return commands to 
# execute.
gitRetrieve = (branch = 'master')->
   # second argument to `true` prevents the execution to stop on errors
   # indeed, "Already on master" message or similar, are on STDERR and
   # will stop the script execution
  [["git reset --hard HEAD"    , true]
   ["git checkout #{branch}"   , true]
   ["git pull origin #{branch}", true]]


# Now it's config time !
module.exports =
  # Web server port on which github should send request
  port: 9001

  # See nodemailer config. If null, then mailer is not configured. 
  mailer:
    # default is SMTP, Sendmail, or SES can be used
    type: 'SMTP'

    # Authentication informations
    service: "Gmail"
    auth: user: "gmail.user@gmail.com", pass: "userpass"
    
    # default options for mail sending (from, cc, to, ...)
    options: 
      from: "no-reply@my-company.org"

    # default mails templates, can be configured independentely on each repo
    templates:
      success: 
        title: '{{original.repository.name}} deployment is a success'
        message: -> # can be a string or a function
          'Hi,\n' +
          'Successfully deployed at ' + (new Date).toUTCString() + ',\n\n' +
          'Console is:\n' + 
          '{{console}}'

        # we CC the testers to tell them new modifications 
        # has been successfully deployed
        options: cc: 'testers@my-company.org'
      error: 
        title: '{{original.repository.name}} push hook is a failure'
        message: ->
          'Hi,\n' +
          'Error at ' + (new Date).toUTCString() + '\n\n' +
          'Console is:\n' + 
          '{{console}}'


  # The repository configuration
  repos:

    # This one is a basic exemple that can be used in a lot of cases
    # `user/concrete-exemple` is your repository name on github
    'user/my-project':->
      # Note: 
      #   Gith payload is exposed on `@`
      #   `@original` is the original payload sent by github
      #   Check https://github.com/danheberden/gith#payload
      #   for more informations

      # We just deploy if master or staging has been pushed
      # (production is deployed on an other server)
      return unless -1 is ['master', 'staging'].indexOf @branch

      # Let's choose working path: 
      # * `/var/www/my-project`
      # * `/var/www/my-project-staging`
      path = "/var/www/#{@original.repository.name}"
      path += '-#{@branch}' if @branch is 'staging'

      # `cwd` defines the working directory, `uid` the user
      # who will execute commands. (`gid` can also be used)
      @exec.options = cwd: path, uid: UID.www_data

      # We use the mail of the developper who pushed for feedback
      @mail.options = to: @original.pusher.email

      # List of commands to execute to deploy 
      # We will use commands defined in the gitRetrieve() method
      # and three additional ones, two to update packages of our project
      # and the last one to build it.
      commands = gitRetrieve().concat [
        'npm install'
        'bower install'
        'cake build'
      ]

      # We can directly use a mail as callback, first parameter is the template
      # name to use as error, second is the template name to use as success.
      callback = @mail.callback('error', 'success')

      # Finaly, let the magic happen!!
      @exec commands, callback 

    # Same exemple with a little number of lines and no comments
    'user/my-project-reduced':->
      return unless -1 is ['master', 'staging'].indexOf @branch

      @exec.options = 
        cwd: "/var/www/#{@original.repository.name}" + if @branch is 'staging' then '-#{@branch}' else '',
        uid: UID.www_data
      @mail.options = to: @original.pusher.email

      @exec gitRetrieve().concat [
        'npm install'
        'bower install'
        'cake build'
      ], @mail.callback('error', 'success') 

    ## Some more misc documentation bellow
    'user/repo':->
      # cwd String Current working directory of the child process
      # env Object Environment key-value pairs
      # uid Number Sets the user identity of the process. (See setuid(2).)
      # gid Number Sets the group identity of the process. (See setgid(2).)
      @exec.options = {}

      @mail.to = 'someone@tr.ee, someone-else@tr.ee'

      # Define some mails templates we can use (will be merge with mailer.templates)
      @mail.templates =
        deployment_success:
          title: 'user/repo deployment is a success'
          message: 'Hi,\nIt has been successfully deployed at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{success}}' # `stdout` and `error` are available depending context of use
        success:
          title: 'user/repo push hook is a success'
          message: 'Hi,\nIt has been successfully deployed at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{success}}' # `stdout` and `error` are available depending context of use
        error:
          title: 'user/repo push hook is a failure'
          message: 'Hi,\nError at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{error}}'
          options: cc: 'developper-support@tr.ee'
        default:
          title: 'user/repo push has been called'
          message: 'Hi,\nHere what has been made:\n{{console}}'
          options: cc: 'developper-support@tr.ee'

      console.log @ # log the payload
      console.log "The branch is #{@branch}"

      # Let's assume 'ls' correspond to a deployment :)
      # asynchrone execution of 1 command
      # @mail.callback('template_name_for_error', 'template_name_for_success')
      # -> it will return a method which expect two parameters: function(error, success);
      # -- if first one is not null, then error template will be used
      @exec 'ls', @mail.callback('error', 'deployment_success')

      # it is the same as:
      # @mail(template_name, attributes)
      @exec 'ls', (error, stdout)->
        return @mail('error', {error: error}) if error
        @mail('deployment_success', {success: success})

      # or the same as:
      # using @mail(title, message, options)
      @exec 'ls', (error, stdout)-> 
        return @mail('MyProject deployment is a failure', 'Hi,\nFail to deploy at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n' + error) if error
        @mail('MyProject deployment is a success', 'Hi,\nIt has been successfully deployed at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n' + stdout)

      # asynchrone execution of X commands, they are executed in queue, if one fail, followings will not be run
      @exec [
        'cd /tmp'
        'echo "' + (new Date).toUTCString() + '\n" >> monitored'
        'echo "success"'
      ], @mail.callback('other')