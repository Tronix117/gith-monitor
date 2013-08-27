module.exports =
  pidfile: '/var/run/gith-monitor.pid'
  logfile: '/var/log/gith-monitor.log'
  port: 9001 # Web server port on which github should send request

  mailer: # See nodemailer config. If null, then mailer is not configured. 
    type: 'SMTP' # default is SMTP, Sendmail, or SES can be used
    service: "Gmail"
    auth: user: "gmail.user@gmail.com", pass: "userpass"
    options: from: "no-reply@tr.ee"
    templates: {}

  repos:
    'user/repo':->
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

    'user/concrete-exemple':->
      @mail.options = to: @original?.head_commit?.author?.email # we use the mail of the last user to commit, it's generaly the one to push

      @mail.templates = 
        deployment_success: 
          subject: 'user/repo deployment is a success'
          content: 'Hi,\nIt has been successfully deployed at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{stdout}}'
          options: cc: 'testers@tr.ee' # we CC the testers to tell them new modifications has been successfully deployed
        deployment_error: 
          subject: 'user/repo push hook is a failure'
          content: 'Hi,\nError at XX/YY/ZZZZ HH:MM,\n\nSTDOUT is:\n{{error}}'

      @exec [
        'cd /home/websites/concrete-exemple'
        'git checkout master'
        'git pull origin master'
        'npm install'
        'cake build'
      ], @mail.callback('deployment_error', 'deployment_success')