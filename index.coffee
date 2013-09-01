gith = require 'gith'
{spawn} = require 'child_process'

global.extend = (target)->
  target[name] = arg[name] for name in Object.keys arg for arg in arguments
  target


class Callback
  exec: (scripts, callback, options = {}, stdout = '', stderr = '', out = '')-> 
    options = extend options, @exec.options || {}
    scripts = [].concat scripts

    script = [].concat(scripts.shift())
    stdErrToStdOut = if typeof script[script.length - 1] is 'boolean' then script.pop() else false

    if script.length is 1 # 'ls -la dir'
      args = script.shift().split(' ')
      command = args.shift()
    else # ['ls', '-la', 'dir']
      command = script.shift()
      args = script

    proc = spawn command , args, options
    proc.stdout.on 'data', (data)-> 
      stdout += data
      out += data
    proc.stderr.on 'data', (data)-> 
      if stdErrToStdOut then stdout += data else stderr += data
      out += data
    proc.on 'close', (code)=>
      return callback stderr, stdout, out if stderr isnt '' or not scripts.length
      @exec scripts, callback, options, stdout, stderr, out
    @
  execs: @exec
  expose: (args = {}) -> 
    @[k] = v for k,v of args
    @

  mailer: null
  mailerOptions: 
    from: 'nobody@nobody.com'
  mail: ->
    return unless @mailer
    options = extend @mailerOptions, extend @mail.options, if typeof arguments[arguments.length - 1] is 'object' then arguments[arguments.length - 1] else {}

    # @mail(template_name, options) or  @mail(template_name)
    if template = @mail.templates[arguments[0]]
      options = extend options, template.options or {}
      options.subject = template.subject
      options.text = template.message
    else # @mail(title, message, options)
      options.subject = arguments[0]
      options.text = arguments[1]

    # Handle options that are functions, and render options content
    for k, v of options
      options[k] = @render (if typeof v is 'function' then v.apply @ else v), @

    @mailer.sendMail options
  
  mailCallback: (errorTemplate, successTemplate, options = {})=>
    return (->) unless @mailer and @mail.templates[errorTemplate] and @mail.templates[successTemplate]

    (error, success, out)=>
      template = if error then errorTemplate else successTemplate

      @error = error
      @success = success
      @console = out

      @mail(template, options)

  ## 
  # Light template engine
  # 
  # First argument is the template under the form
  #   'My name is {{user.firstname}} {{user.lastname}}, my first friend 
  #    is {{user.friends[0].firstname}}. I am {{status}}!'
  # 
  # Second argument is an object representing data
  #   { user: {
  #       firstname: 'Jeremy',
  #       lastname: 'Trufier',
  #       friends: [
  #         { firstname: 'Jack',
  #           lastname: 'Sparrow' }
  #       ]
  #     },
  #     status: 'a great guy'
  #   }
  #   
  #   It will result into:
  #   'My name is Jeremy Trufier, my first friend is Jack. I am a great guy!'
  render: (str, attributes)->
    str = str.replace /{{(.*?)}}/g, ->
      val = attributes
      arguments[1].replace /(.*?)"?'?\]?(\.|\["?'?|$)/g, ->
        val = val?[arguments[1]] if arguments[1]
      val or ''
    str

  constructor: ()->
    @mail.options = {}
    @mail.templates = {}
    @mail.callback = @mailCallback

    @exec.options = {}


class GithMonitor

  config: {}
  gith: null
  mailer: null

  constructor: ()->
    @config = extend @config, extend (try require path.join realdir, '..', 'config') or {}, (try require '/etc/gith-monitor') or {}, (try require '~/.gith-monitor') or {}
    @gith = gith.create @config.port

    @mailer = require('nodemailer').createTransport(@config.mailer.type || 'SMTP', @config.mailer) if @config.mailer

    @loadRepos(@config.repos)

  loadRepos: (repos)->
    for repo, callbacks of repos
      repoGith = @gith(repo: repo)
      for callback in [].concat callbacks 
        callbacksContext = new Callback
        callbacksContext.mailer = @mailer
        callbacksContext.mailerOptions = extend callbacksContext.mailerOptions, @config.mailer?.options or {}
        repoGith.on 'all', ((callback, callbacksContext)-> -> callback.apply callbacksContext.expose(arguments[0]), arguments)(callback, callbacksContext)

module.exports = new GithMonitor()