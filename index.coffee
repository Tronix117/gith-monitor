gith = require 'gith'
{exec} = require 'child_process'

global.extend = (target)->
  target[name] = arg[name] for name in Object.keys arg for arg in arguments
  target

class Callback
  exec: (scripts, callback, stdoutBuffer = '')-> 
    scripts = [].concat scripts
    exec scripts.shift(), (error, stdout, stderr)=> 
      stdoutBuffer += stdout
      return callback error, stdoutBuffer if error or not scripts.length
      @exec scripts, callback, stdoutBuffer
    @
  execs: @exec
  expose: (args = {}) -> 
    @[k] = v for k,v of args
    @

class GithMonitor

  config: {}
  gith: null
  callbacksContext: new Callback

  constructor: ()->
    @config = extend @config, extend (try require path.join realdir, '..', 'config') or {}, (try require '/etc/gith-monitor') or {}, (try require '~/.gith-monitor') or {}
    @gith = gith.create @config.port

    @loadRepos(@config.repos)

  loadRepos: (repos)->
    callbacksContext = @callbacksContext
    for repo, callbacks of repos
      repoGith = @gith(repo: repo)
      for callback in [].concat callbacks 
        repoGith.on 'all', () -> callback.apply callbacksContext.expose(arguments[0]), arguments

module.exports = new GithMonitor()