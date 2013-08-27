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

  mailer: null
  mailerOptions: 
    from: 'nobody@nobody.com'
  mail: ->
    return unless @mailer
    options = extend @mailerOptions, extend @mail.options, if typeof arguments[arguments.length - 1] is 'object' then arguments[arguments.length - 1] else {}

    # @mail(template_name, attributes, options) or  @mail(template_name, attributes) or  @mail(template_name)
    if template = @mail.templates[arguments[0]]
      options = extend options, template.options or {}
      options.subject = @render(template.title, options)
      options.text = @render(template.message, options)
    else # @mail(title, message, options)
      options.subject = @render(arguments[0], options)
      options.text = @render(arguments[1], options)

    @mailer.sendMail options
  
  mailCallback: (errorTemplate, successTemplate)->
    return (->) unless mailer = @mailer and errorTemplate = @mail.templates[errorTemplate] and successTemplate = @mail.templates[successTemplate]

    options = extend @mailerOptions, extend @mail.options, if typeof arguments[arguments.length - 1] is 'object' then arguments[arguments.length - 1] else {}

    (error, success)->
      template if error then errorTemplate else successTemplate

      options = extend options, extend template.options or {}, {error: error, success: success}
      options.subject = @render(template.title, options)
      options.text = @render(template.message, options)

      mailer.sendMail options

  render: (str, attributes)->
    str = str.replace(new RegExp("{{#{k}}}",'g'), v) for k,v of attributes
    str

  constructor: ()->
    @mail.options = {}
    @mail.templates = {}
    @mail.callback = @mailCallback


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
        repoGith.on 'all', () -> callback.apply callbacksContext.expose(arguments[0]), arguments

module.exports = new GithMonitor()