app = angular.module('MM_Graph')

class Team_Data
  constructor: ($routeParams,$rootScope, $cacheFactory, $q, API)->
    @.$routeParams   = $routeParams
    @.$rootScope     = $rootScope
    @.$cacheFactory  = $cacheFactory
    @.cache          = $cacheFactory('team_Data')
    @.$q             = $q
    @.deferred       = null
    @.API            = API
    @.data           = null
    @.project        = null
    @.schema         = null
    @.schema_Details = null
    @.team           = null


  call_With_Cache: (method, params, callback)=>                                 # method that uses promises to prevent multiple parallel calls

    cache_Key = "#{method}_#{JSON.stringify(params)}"                           # create cache key using method and params

    if not @.cache.get cache_Key                                                # if this is the first require for this type of data (method_project_team)
      deferred = @.$q.defer()                                                   # create a new instance of deferred
      @.cache.put cache_Key, deferred.promise                                   # put its promise in the cache

      on_Data_Received = (data)->                                               # simple callback method to resolve the promise
        deferred.resolve(data)                                                  # resolve promise (this is the data that will show as the 1st param in 'then')

      method_Params = params.concat(on_Data_Received)                           # append on_Data_Received callback method to the current 'method' params list

      @.API[method].apply(null, method_Params)                                  # invoke 'method' in @.API

    @.cache.get(cache_Key).then (data)->                                        # invoke the 'then' from the promise (will happen async until data is recevied)
      callback (data)                                                           # finally call the original callback with the data received from 'method'

  clear_Data: ()=>
    @.cache.removeAll()
    @.scores   = null
    @.schema   = null
    @.data     = null
    @.deferred = null

  load_Data: (callback)=>
    if not (@.$routeParams.project and @.$routeParams.team)                     # check that project and team are set
      return callback()

    if (@.$routeParams.project is @.project and @.$routeParams.team is @.team)  # check if either the project or team have changed
      # do nothing here since project or team have not changed
    else
      @.clear_Data()                                                            # when project changes remove all cache entries
      @.project = @.$routeParams.project
      @.team    = @.$routeParams.team
      @.project_Schema (schema)=>                                               # get project schema
        @.project_Schema_Details (schema_Details)=>
          @.data_Score (scores)=>                                                 # get current team scores
            @.team_Get (data)=>                                                   # get team data
              @.data           = data
              @.schema         = schema
              @.schema_Details = schema_Details
              @.scores         = scores
              @.deferred.resolve()                                                # trigger promise resolve

    @.deferred ?= @.$q.defer()                                                  # ensure @.deferred object exits
    @.deferred.promise.then ->                                                  # schedule execution
      callback()                                                                # invoke original caller callback

  data_Score            : (             callback) => @.call_With_Cache 'data_Score'             , [@.project, @.team      ], callback
  project_Schema        : (             callback) => @.call_With_Cache 'project_Schema'         , [@.project              ], callback
  project_Schema_Details: (             callback) => @.call_With_Cache 'project_Schema_Details' , [@.project              ], callback
  radar_Fields          : (             callback) => @.call_With_Cache 'data_Radar_Fields'      , [@.project              ], callback
  radar_Team            : (target_Team, callback) => @.call_With_Cache 'data_Radar_Team'        , [@.project, target_Team ], callback
  team_Get              : (             callback) => @.call_With_Cache 'team_Get'               , [@.project, @.team      ], callback

  save: (callback)=>
    @.API.file_Save @.project, @.team , @.data, (result)=>

      callback result                                                           # the code below had a really nasty side effect, where the 2nd save didn't work because the input fields would be pointing to the previous @.data object

#      @.project  = null                                                         # clear these values to trigger data reload
#      @.team     = null
#      @.load_Data =>                                                            # find better way to reload this data (see below)
#        callback result                                                         # since at the moment we are doing a full data reload

      #@.data_Score (scores)=>                                                  # (this would be a better option but cache prevents data_Score data reload
        #@.scores = scores                                                      # get current team scores (to update it based on saved changes)
        #callback()

app.service 'team_Data', ($routeParams, $rootScope, $cacheFactory, $q, API)=>
  return new Team_Data $routeParams, $rootScope, $cacheFactory, $q, API