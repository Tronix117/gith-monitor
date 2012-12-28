gith = require 'gith'
{exec} = require 'child_process'


class Callback
  exec: (scripts, callback, stdoutBuffer = '')-> 
    scripts = [].concat scripts
    exec scripts.shift(), (error, stdout, stderr)=> 
      stdoutBuffer += stdout
      return callback error, stdoutBuffer if error or not scripts.length
      @exec scripts, callback, stdoutBuffer
    @
  execs: @exec

class GithMonitor

  config: {}
  gith: null
  callbacksContext: new Callback

  constructor: (config)->
    @config = extend @config, config
    @gith = gith.create @config.port

    @loadRepos(@config.repos)

  loadRepos: (repos)->
    for repo, callbacks of repos
      for callback in [].concat callbacks 
        gith(repo: repo).on 'all', () -> callback.apply callbacksContext, arguments



module.exports = GithMonitor