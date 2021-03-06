###
 * Restify v0.3.1
 * (c) 2013 Ilan Frumer
 * License: MIT
###


# Declare module
module = angular.module('restify', [])

original = {}

module.config ['$httpProvider', ($httpProvider)->
  original.transformRequest  = $httpProvider.defaults.transformRequest[0]
  original.transformResponse = $httpProvider.defaults.transformResponse[0]

]

module.factory 'restify', ['$http','$q', ($http, $q)->

  ## helpers

  uriToArray = (uri)->
    _.filter(uri.split('/'),(a)-> a)

  ## wrap response data with resified objects


  restify = (data, wrap)->

    newElement = null

    if _.isObject(data) 

      $id = null
      $route = @$$route          

      for key,val of @$$route
        if /^:/.test(key)
          $id = key.match(/^:(.+)/)[1]
          $route = val
          break

      if _.isArray(data)

        newElement = new Restify(@$$url,@$$route,@$$parent)

        if($id)

          data = _.map data, (item)->

            if (item[$id])
              return _.extend(new Restify("#{newElement.$$url}/#{item[$id]}", $route, newElement), item)
            else
              return item

        newElement.push(data...)

      else

        if ($id && data[$id])
          newElement = new Restify("#{@$$url}/#{data[$id]}",@$$route, this)                
        else
          newElement = new Restify(@$$url, @$$route, @$$parent)

        newElement = _.extend(newElement, data)

    else
      newElement = new Restify(@$$url, @$$route, @$$parent)
      newElement.data = data      
      
    return newElement

  ## unwrap request data from resified objects
  
  deRestify = (obj)->
    if angular.isObject(obj)
      _.omit (obj) , (v,k)-> /^\$/.test(k)

  ## class

  class Restify extends Array

    constructor: (base, route, parent)->

      @$$url = base
      @$$route = route
      @$$parent = parent
      @$$config = {}

      for key,val of route
        base = "" if base == "/"
        if /^:/.test(key)
          $id = key.match(/^:(.+)/)[1]
          @["$#{$id}"] = (id)->
            new Restify("#{base}/#{id}", val, this)
        else
          @["$#{key}"] = new Restify("#{base}/#{key}", val, this)

    $req: (config, wrap = true)->
      
      conf = {}
      config.data = deRestify(config.data) if config.data
      config.url = @$$url

      angular.extend(conf, @$$config , config)

      # defaults
      conf.method = conf.method || "GET"
      delete conf.params if _.isEmpty(conf.params)

      $http(conf).then (response)=>
        response.data = restify.call(this, response.data) if wrap
        return response.data

    $ureq: (config)-> @$req(config, false)

    $uget : (params = {})-> @$ureq({method: 'GET' , params: params});
    $get : (params = {})-> @$req({method: 'GET' , params: params});

    $upost : (data) -> @$ureq({method: 'POST', data: data || this});
    $post : (data) -> @$req({method: 'POST', data: data || this});

    $uput : (data) -> @$ureq({method: 'PUT', data: data || this});
    $put : (data) -> @$req({method: 'PUT', data: data || this});

    $upatch : (data) -> @$ureq({method: 'PATCH', data: data || this});
    $patch : (data) -> @$req({method: 'PATCH', data: data || this});

    $udelete : () -> @$ureq({method: 'DELETE'});
    $delete : () -> @$req({method: 'DELETE'});

    $config: (config)-> angular.extend($$config,config)

  return (baseUrl, callback)->

    match = baseUrl.match(/^(https?\:\/\/)?(.+)/) || []

    baseUrl = (match[1] || '/') + uriToArray(match[2] || '').join('/')

    base = {}

    configuerer =
      add: (route)->

        route = uriToArray(route)
      
        mergeRoutes = (base, route)->

          unless _.isEmpty(route)

            name = route[0]
            next = route.slice(1)

            base[name] = base[name] || {}

            mergeRoutes(base[name], next)

        mergeRoutes(base, route, [])

    callback(configuerer)

    return new Restify(baseUrl, base , null)
]