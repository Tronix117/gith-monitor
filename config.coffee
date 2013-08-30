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
      from: "no-reply@tr.ee"

    # default mails templates, can be configured independentely on each repo
    templates: {}


  # The repository configuration
  repos:

    # This one is a basic exemple that can be used in a lot of cases
    # `user/concrete-exemple` is your repository name on github
    'user/concrete-exemple':->
      # We just deploy if master has been pushed
      return unless @branch is 'master'

      return unless @branch is 'master' # we just deploy if master has been pushed

      @exec.options = cwd: "/var/www/#{@repository.name}", uid: UID.www_data
      @mail.options = to: @original?.pusher?.email # we use the mail of the last user to commit, it's generaly the one to push
      @mail.templates = makeMailTemplates(@repo)

      @exec (gitRetrieve().concat 'npm install --unsafe-perm'), @mail.callback('error', 'success')


      @exec.options = uid: 5001 # corresponding to /home/website owner in this exemple

      @mail.options = to: @original?.head_commit?.author?.email # we use the mail of the last user to commit, it's generaly the one to push

      @mail.templates = 
        deployment_success: 
          subject: 'user/repo deployment is a success'
          content: 'Hi,\nIt has been successfully deployed at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{success}}'
          options: cc: 'testers@tr.ee' # we CC the testers to tell them new modifications has been successfully deployed
        deployment_error: 
          subject: 'user/repo push hook is a failure'
          content: 'Hi,\nError at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{error}}'

      @exec [
        'cd /home/websites/concrete-exemple'
        ['git checkout master', true] # the true here redirect stderr to stdout, otherwise the "Already on master" message will stop everything
        'git pull origin master'
        'npm install'
        'cake build'
      ], @mail.callback('deployment_error', 'deployment_success')

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