module.exports =
  pidfile : '/var/run/gith-deploy.pid'
  logfile : '/var/log/gith-deploy.log'
  port: 9001 # Web server port on which github should send request

  repos:
    'user/repo': (payload)->
      console.log payload

      callback = (error, stdout)->
        return console.error error if error
        console.log stdout
        console.info 'Success!!'

      # asynchrone execution of 1 command
      @exec 'ls', callback


      # asynchrone execution of X commands, they are executed in queue, if one fail, followings will not be run
      @exec [
        'cd /tmp'
        'echo "' + (new Date).toUTCString() + '\n" >> monitored'
        'echo "success"'
      ], callback