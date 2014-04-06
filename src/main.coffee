# remote Object
# {
#   __r_id
#   __r_host
#   __r_port
#   __r_type : 'object'

# }
# 
# remote Object descriptor
# {
#   __r_id
#   __r_host
#   __r_port
#   __r_type : 'objDes'
#   __r_props : {
#       key/value mapping of primitive types and other remote object descriptor
#   }
#   __r_funcs :{
#       name/ method id mapping
#   }
# }
# 
# remote Function
# {
#   __r_id
#   __r_host
#   __r_port
#   __r_type : 'function'
# }
# 
# remote Function descriptor
# {
#   __r_id
#   __r_host
#   __r_port
#   __r_type : 'funcDes'
# }
# 
#  a object is a remote object if it has attribute __r_type.
#   
#   __r_host __r_port are optional
#   
#   request
#   {
#       type : 'retrive' or 'invoke'
#       objName : for 'retrive'
#       objId : for 'invoke'
#       args : argument list, array
#   }
#   
#   response
#   {
#       error : if error      
#       
#   }
#  descriptors only live in transmission layer
#  __r_host and __r_port are leave out if it is the local object from the server
#
http           = require 'http'   
{EventEmitter} = require('events')
express        = require 'express'
lodash         = require 'lodash'


class RmiService extends EventEmitter
    #fixed private prefix
    _privatePrefix : '_'
    ###
    __defineGetter__  __defineSetter__   __lookupGetter__  __lookupSetter__  
    constructor hasOwnProperty isPrototypeOf propertyIsEnumerable toLocaleString        
    toString valueOf toJSON
    ###
    _excludeMethods : ['constructor', 'hasOwnProperty','isPrototypeOf',
                        'propertyIsEnumerable', 'toLocaleString', 'toString',
                        'valueOf', 'toJSON']
    constructor: (@_option, callback) ->
        {@host, @port} = @_option
        @sequence = 42
        @serverObj = {}
        @methods = {}        
        @objects = {}
        @server = express()
        #parse the body
        @server.use(express.urlencoded())
        @server.use(express.json())
        @server.post('/',(req, res)=>
            @handleRemoteRequest(req, res)
            )
        @server.listen(@port,@host,511, ()=>
            if callback?
                callback null, this
            console.log "RmiService listening on #{@port}"
        )
        
    _isPrivate : (name)->
        if name.indexOf(@_privatePrefix) is 0
            return true
        for exclude in @_excludeMethods
            if name is exclude
                return true
        return false
        
        

    getSequence :()->
        @sequence++

    handleRemoteRequest : (req, res)->
        console.log "#{@host}:#{@port} receive request..."
        console.log JSON.stringify(req.body)
        if(req.body.type is 'retrive')
            obj = @serverObj
            if req.body.objName?
                obj = @serverObj[req.body.objName]
            serialized = @serializeObject(obj)
            objstr = JSON.stringify(serialized)
            res.write(objstr)
            res.end()
            return
        if req.body.type is 'invoke'
            method = @methods[req.body.objId]
            if not method?
                return @noSuchMethod(res)
            args = []
            for arg in req.body.args
                remoteObj = @parseRemoteObj(arg,{host:req.body.host, port:req.body.port}, {})
                args.push(remoteObj)               
            method.method.apply(method.obj, args)
            res.end()
            return

    createSkeleton: (endPoint, obj)->
        @serverObj[endPoint] = obj

    #TODO only keep id if the object is from the destination
    serializeObject : (obj)->
        @__serializeObject(obj, {})

    #append remote markers to existing object or create a new object with remote markers
    __addRemoteMarkers : (id, host, port, type, source)->
        result = if source? then source else {}
        result.__r_id = id
        result.__r_type = type
        # only add fields if they are from elsewhere
        if host? and port? and (host isnt @host or port isnt @port)
            result.__r_host = host
            result.__r_port = port
        return result

    __newRemoteObjectDesc : (id, host, port) ->
        return @__addRemoteMarkers(id, host, port , 'objDes')

    __addFuncToRemoteObjDesc : (desc, key, id) ->
        if not desc.__r_funcs?
            desc.__r_funcs={}
        desc.__r_funcs[key] = id

    __addPropToRemoteObjDesc : (desc, key, v) ->
        if not desc.__r_props?
            desc.__r_props = {}
        desc.__r_props[key] = v
        

    __newRemoteFunctionDesc : (id, host, port) ->
        return @__addRemoteMarkers(id, host, port , 'funcDes')
        
    #map is used to check cyclic reference
    __serializeObject : (obj, map)->
        if obj is null or (typeof obj isnt 'object' and typeof obj isnt 'function')
            return obj
        # assign id, this is definitely a local object
        if not obj.__r_id?
            obj.__r_id = @getSequence()
            @objects[obj.__r_id] = obj
        host = if obj.__r_host? then obj.__r_host else @host
        port = if obj.__r_port? then obj.__r_port else @port
        if not map[host]?
            map[host]={}
        if not map[host][port]?
            map[host][port]={}
        id = obj.__r_id
        cached = if map[host][port][id]? then map[host][port][id] else null
        if cached
            return @__addRemoteMarkers(id, host, port, 'ref')
        else
            map[host][port][id] = true
            if obj.__r_type?
                return @serializeForRemoteTypes(obj, map)
            # serialize function
            if typeof obj is 'function'
                funcDesc = @__newRemoteFunctionDesc(id, @host, @port)
                @methods[id] = {
                        method : obj
                        obj : {}
                }
                return funcDesc
            # serialize object
            objDesc = @__newRemoteObjectDesc(id, @host, @port)
            for k, v of obj
                if @_isPrivate(k)
                    continue
                # to minimize size, local function will only take up an id field
                if typeof v is 'function' and not v.__r_type?
                    #if this function was registerd before, calling __serializeObject will make sure id be reused
                    funcDesc = @__serializeObject(v, map)
                    methodId = funcDesc.__r_id
                    @__addFuncToRemoteObjDesc(objDesc,k,methodId)
                    @methods[methodId] = {
                        method : v
                        obj : obj
                    }
                    #console.log "#{methodId} : #{@methods[methodId]} #{@methods[methodId].method}"
                else
                    # for remote methods or other property we need full descriptor
                    @__addPropToRemoteObjDesc(objDesc, k, @__serializeObject(v, map))

            return objDesc        

    #convert remote objects to remote descriptors
    serializeForRemoteTypes : (obj, map)->
        if obj.__r_type is 'objDes' or obj.__r_type is 'funcDes'
            #this should not happen, unless in the future, descriptors are cached
            console.log "descriptors should only live in transmission layer"
            return obj
        if obj.__r_type is 'object'
            result = @__newRemoteObjectDesc(obj.__r_id, obj.__r_host, obj.__r_port)
            for k, v of obj
                if k.indexOf('__r_') is 0
                    continue
                if typeof v is 'function'
                    @__addFuncToRemoteObjDesc(result,k, v.__r_id)
                else
                    @__addPropToRemoteObjDesc(result, k, @__serializeObject(v, map))
            return result
        if obj.__r_type is 'function'
            return @__newRemoteFunctionDesc(obj.__r_id, obj.__r_host, obj.__r_port)


    retriveObj : (option, callback)->
        reqOption = {
            hostname : option.host
            port : option.port
            requestBody : {
                type : 'retrive'
                objName : option.objName
            }
        }
        httpRequest(reqOption, (err, body, resp)=>
            if err?
                callback err
                return
            console.log "#{@host}:#{@port} receive response..."
            console.log body
            respObj = JSON.parse(body)
            result = @parseRemoteObj(respObj, option, {})
            callback null, result
        )
    #copy host, port, etc
    mergeRemoteObj : (dest, src) ->
        dest.__r_id = src.__r_id
        dest.__r_host = src.__r_host
        dest.__r_port = src.__r_port
        return dest

    __newRemoteObj : (desc, context) ->
        result = {
            __r_id : desc.__r_id
            __r_type : 'object'
            __r_host : if desc.__r_host? then desc.__r_host else context.host
            __r_port : if desc.__r_port? then desc.__r_port else context.port
        }

    __newRemoteFunc : (desc, context) ->
        id = if desc.__r_id? then desc.__r_id else desc
        host = if desc.__r_host? then desc.__r_host else context.host
        port = if desc.__r_port? then desc.__r_port else context.port
        # it is local method
        if host is @host and port is @port
            return @methods[id].method
        _this = @
        func = do (_this, host, port ,id)->
            ()->
                _this.invokeRemoteMethod(host, port, id, arguments)
        func.__r_id = id
        func.__r_host = host
        func.__r_port = port
        func.__r_type = 'function'
        return func

    __findInMap : (desc, context, map) ->
        id = desc.__r_id
        host = if desc.__r_host? then desc.__r_host else context.host
        port = if desc.__r_port? then desc.__r_port else context.port
        return map[host][port][id]

    __putInMap : (desc, context, map) ->
        id = desc.__r_id
        host = if desc.__r_host? then desc.__r_host else context.host
        port = if desc.__r_port? then desc.__r_port else context.port
        if not map[host]?
            map[host]={}
        if not map[host][port]?
            map[host][port] = {}
        map[host][port][id] = desc
        
        

    #parse descriptors to remote stub
    #context is the server's host and port
    #map is for cyclic detection
    parseRemoteObj : (obj, context, map)->
        #return simple types
        if not obj? or not obj.__r_type?
            return obj
        
        if obj.__r_type is 'objDes'
            # return local object if possible
            if obj.__r_host is @host and obj.__r_port is @port
                return @objects[obj.__r_id]
            
            result = @__newRemoteObj(obj, context)
            @__putInMap(result, context, map)
            for k, v of obj.__r_props
                result[k]= @parseRemoteObj(v, context, map)
            for k, funcId of obj.__r_funcs
                remoteFunc = @__newRemoteFunc(funcId, context)
                result[k] = remoteFunc
                @__putInMap(remoteFunc, context, map) 
            return result
            
        if obj.__r_type is 'funcDes'
            remoteFunc = @__newRemoteFunc(obj, context)
            @__putInMap(remoteFunc, context, map)
            return remoteFunc
        if obj.__r_type is 'ref'
            # return local object if possible
            if obj.__r_host is @host and obj.__r_port is @port
                return @objects[obj.__r_id]
            return @__findInMap(obj, context, map)

        # no other types
        throw new Error('Unknown type')

    invokeRemoteMethod : (host, port, id, args)->
        serializedArgs = []
        callback = null
        if args?
            for arg in args
                serializedArgs.push(@serializeObject(arg))
            #conventionally the last arg is callback
            lastArg = args[args.length-1]
            if typeof lastArg is 'function'
                callback = lastArg
        
        reqOption = {
            hostname :host
            port : port
            requestBody : {
                type : 'invoke'
                objId : id
                host : @host
                port : @port
                args : serializedArgs
            }
        }
        httpRequest(reqOption, (err, body, resp)=>
            if err?
                if callback?
                    callback err
                else
                    @emit 'error', err
                return
            # TODO parse error requests
        )

        
#options is identical to options in http.request function, with an optional requestBody
# handler(err, body, response)
httpRequest = (options, handler)->
    options.method = 'POST'
    options.headers = {"Content-type" :"application/json; charset=utf-8"}
    req = http.request(options, (res)->
        res.setEncoding('utf8')
        body=''
        res.on('data', (chunk)->
            body+=chunk
        )
        res.on('end',()->
            handler null, body, res
        )
    )
    req.on('error',(e)->
        handler e
    )
    if options.requestBody?
        console.log "post #{options.hostname}:#{options.port} #{JSON.stringify(options.requestBody)}"
        if typeof options is 'string'
            req.write(options.requestBody)
        else
            req.write(JSON.stringify(options.requestBody))
    req.end()
    return req



exports.createRmiService = (options, callback)->
    new RmiService(options, callback)