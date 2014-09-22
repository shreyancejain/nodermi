// Generated by CoffeeScript 1.8.0
(function() {
  var addHiddenField, createCompressMap, debug, encodeHelper, k, keyWord, keyWordCode, keyWords, keyWordsMap, keyWordsReverseMap, logger, normalized, v, _i, _len;

  debug = require('debug');

  logger = debug('nodermi:common');

  addHiddenField = function(obj, key, val) {
    return Object.defineProperty(obj, key, {
      value: val,
      writable: false,
      enumerable: false,
      configurable: false
    });
  };

  keyWords = ['__r_id', '__r_host', '__r_port', 'origin', 'remoteType', 'arrayElements', 'dateValue', 'properties', 'functions', 'serverVersion', 'messageType', 'objectName', 'objectId', 'functionName', 'args', 'objDes', 'funcDes', 'arrDes', 'dateDes', 'ref', 'retrive', 'invoke', 'pojo', 'protocolVersion', 'messageId', 'success', 'error'];

  createCompressMap = function(arr) {
    var compressed, counter, item, map, _i, _len;
    counter = 0;
    map = {};
    for (_i = 0, _len = arr.length; _i < _len; _i++) {
      item = arr[_i];
      if (map[item] == null) {
        compressed = counter.toString(35);
        map[item] = compressed;
        counter++;
      } else {
        throw new Error("duplicate item " + item);
      }
    }
    return map;
  };

  keyWordsMap = createCompressMap(keyWords);

  logger("keyWordsMap " + (JSON.stringify(keyWordsMap)));


  /*
  nodermi:common keyWordsMap {"__r_id":"0","__r_host":"1","__r_port":"2","origin":"3","remoteType":"4","arrayElements":"5",
  "dateValue":"6","properties":"7","functions":"8","serverVersion":"9","messageType":"a","objectName":"b",
  "objectId":"c","functionName":"d","args":"e","objDes":"f","funcDes":"g","arrDes":"h","dateDes":"i",
  "ref":"j","retrive":"k","invoke":"l","pojo":"m","protocolVersion":"n","messageId":"o","success":"p","error":"q"}
   */

  keyWordsReverseMap = {};

  for (k in keyWordsMap) {
    v = keyWordsMap[k];
    keyWordsReverseMap[v] = k;
  }

  encodeHelper = {};

  for (_i = 0, _len = keyWords.length; _i < _len; _i++) {
    keyWord = keyWords[_i];
    normalized = keyWord.replace(/_/g, '');
    encodeHelper[normalized] = keyWord;
    keyWordCode = keyWordsMap[keyWord];
    encodeHelper["" + normalized + "Code"] = keyWordCode;
    normalized = normalized.charAt(0).toUpperCase() + normalized.slice(1);
    encodeHelper["get" + normalized] = (function(keyWordCode) {
      return function(obj) {
        return obj[keyWordCode];
      };
    })(keyWordCode);
    encodeHelper["getHidden" + normalized] = (function(keyWord) {
      return function(obj) {
        return obj[keyWord];
      };
    })(keyWord);
    encodeHelper["setHidden" + normalized] = (function(keyWord) {
      return function(obj, val) {
        if (val != null) {
          return addHiddenField(obj, keyWord, val);
        }
      };
    })(keyWord);
    encodeHelper["getFull" + normalized] = (function(keyWordCode) {
      return function(obj) {
        var fullVal, val;
        val = obj[keyWordCode];
        fullVal = val;
        if (val != null) {
          fullVal = keyWordsReverseMap[val];
          if (fullVal == null) {
            throw new Error("cannot find keyWord code " + val + ", return null");
          }
        }
        return fullVal;
      };
    })(keyWordCode);
    encodeHelper["set" + normalized] = (function(keyWordCode) {
      return function(obj, val, valueIsKeyWord) {
        var cval;
        cval = val;
        if (valueIsKeyWord && (val != null)) {
          cval = keyWordsMap[val];
          if (cval == null) {
            throw new Error("cannot find keyword " + val);
          }
        }
        if (cval != null) {
          return obj[keyWordCode] = cval;
        }
      };
    })(keyWordCode);
    encodeHelper["set" + normalized + "From"] = (function(keyWordCode) {
      return function(obj, source) {
        if (source[keyWordCode] != null) {
          return obj[keyWordCode] = source[keyWordCode];
        }
      };
    })(keyWordCode);
    encodeHelper["is" + normalized + "Equals"] = (function(keyWordCode) {
      return function(obj, val) {
        if ((val != null) && (obj[keyWordCode] != null)) {
          return val === obj[keyWordCode];
        }
        return (val == null) && (obj[keyWordCode] == null);
      };
    })(keyWordCode);
  }

  exports.encodeHelper = encodeHelper;

  exports.privatePrefix = '_';


  /*
  __defineGetter__  __defineSetter__   __lookupGetter__  __lookupSetter__  
  constructor hasOwnProperty isPrototypeOf propertyIsEnumerable toLocaleString        
  toString valueOf toJSON
   */

  exports.excludeMethods = ['constructor', 'hasOwnProperty', 'isPrototypeOf', 'propertyIsEnumerable', 'toLocaleString', 'toString', 'valueOf', 'toJSON'];

  exports.addHiddenField = addHiddenField;

}).call(this);