gith = require 'gith'
{spawn} = require 'child_process'

global.extend = (target)->
  target[name] = arg[name] for name in Object.keys arg for arg in arguments
  target


class Callback
  exec: (scripts, callback, options = {}, stdout = '', stderr = '', out = '')-> 
    options = extend @execOptions, @exec.options || {}, options

    for k, v of options
      if k isnt 'callback' and k isnt 'createCallback'
        options[k] = @render (if typeof v is 'function' then v.apply @ else v), @

    options['callback'] = callback if callback
    unless typeof options['callback'] is 'function'
      if typeof options['createCallback'] is 'function'
        options['callback'] = options['createCallback'].apply @
        delete options.createCallback
      else
        options['callback'] = -> console.log 'NO CALLBACK DEFINED'

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
      return options['callback'] stderr, stdout, out if stderr isnt '' or not scripts.length
      @exec scripts, null, options, stdout, stderr, out
    @
  execs: @exec
  expose: (args = {}) -> 
    @[k] = v for k,v of args
    @
  execOptions: {}
  mailer: null
  mailerOptions: 
    from: 'nobody@nobody.com'
  mail: =>
    return unless @mailer
    options = extend @mailerOptions, @mail.options, if typeof arguments[arguments.length - 1] is 'object' then arguments[arguments.length - 1] else {}

    templates = extend {}, @mailer.options?.templates or {}, @mail.templates or {}

    # @mail(template_name, options) or  @mail(template_name)
    if template = templates[arguments[0]]
      options = extend options, template.options or {}
      options.subject = template.title
      options.text = template.message
    else # @mail(title, message, options)
      options.subject = arguments[0]
      options.text = arguments[1]

    # Handle options that are functions, and render options content
    for k, v of options
      options[k] = @render (if typeof v is 'function' then v.apply @ else v), @

    @mailer.sendMail options
  
  mailCallback: (errorTemplate, successTemplate, options = {})=>
    return (->) unless @mailer

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
    return str unless typeof str is 'string'
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
      hooks = []
      if typeof callbacks is 'object'
        if callbacks instanceof Array
          for callback in callbacks
            if typeof callback is 'function'
              hooks.push {on: 'all', branch: null, callback: callback}
        else # Object: `'branch1, branch2': -> ...callback...` or `'branch1 branch2 branch3': [(-> ...calback1...), (-> ...callback2...)]`
          for branches, callback of callbacks
            branches = branches.replace(/\s*(,|\s)\s*/g, ',').split(',') # match `branch1,branch2 branch3   ,   branch4`
            for c in [].concat callback
              for branch in branches
                hooks.push {on: 'all', branch: branch, callback: c} if typeof c is 'function'
      else if typeof callbacks is 'function'
        hooks.push {on: 'all', branch: null, callback: callbacks}

      for hook in hooks
        settings = repo: repo
        settings['branch'] = hook.branch if hook.branch
        callback = hook.callback

        repoGith = @gith settings

        callbacksContext = new Callback
        callbacksContext.mailer = @mailer
        callbacksContext.mailerOptions = extend callbacksContext.mailerOptions, @config.mailer?.options or {}
        callbacksContext[k] = v for k, v of @config.context or {}
        callbacksContext.execOptions[k] = v for k, v of @config.exec or {}
        
        console.log 'Watch ' + repo + ' on ' + hook.on + ' for branch: ' + (hook.branch or 'all')

        repoGith.on hook.on, ((callback, callbacksContext)-> -> callback.apply callbacksContext.expose(arguments[0]), arguments)(callback, callbacksContext)

module.exports = new GithMonitor()