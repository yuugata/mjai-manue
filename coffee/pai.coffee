Util = require("./util")

class Pai

  constructor: ->

    switch arguments.length
      when 1
        [arg] = arguments
        if typeof(arg) == "number"
          @_id = arg
          @_red = false
        else
          if arg == "?"
            type = number = null
            @_red = false
          else if arg.match(/^([1-9])([mps])(r)?$/)
            type = RegExp.$2
            number = parseInt(RegExp.$1)
            @_red = RegExp.$3 != ""
          else if (number = Pai.TSUPAI_STRS.indexOf(arg)) > 0
            type = "t"
            number = number
            @_red = false
          else
            throw "Unknown pai string: #{arg}"
      when 2, 3
        [type, number, @_red] = arguments
        if @_red == undefined then @_red = false
      else
        throw "Wrong number of arguments"

    if @_id != undefined
    else if type != null || number != null
      type_index = Pai.TYPE_STRS.indexOf(type)
      if type_index < 0
        throw "Bad type: #{type}"
      if typeof(number) != "number"
        throw "number must be number: #{number}"
      if @_red != true && @_red != false
        throw "red must be boolean: #{@_red}"
      @_id = type_index * 9 + (number - 1)
    else
      @_id = null

  type: ->
    return if @_id == null then null else Pai.TYPE_STRS[Math.floor(@_id / 9)]

  number: ->
    return if @_id == null then null else @_id % 9 + 1

  equal: (other) ->
    return other && other.constructor == Pai && @_id == other.id() && @_red == other.red()

  hasSameSymbol: (other) ->
    return @_id == other.id()

  isIn: (pais) ->
    for pai in pais
      if @equal(pai) then return true
    return false

  toString: ->
    type = @type()
    number = @number()
    switch type
      when null
        return "?"
      when "t"
        return Pai.TSUPAI_STRS[number]
      else
        return number + type + (if @_red then "r" else "")

Util.attrReader(Pai, ["id", "red"])

Pai.NUM_IDS = 9 * 3 + 7
Pai.TYPE_STRS = ["m", "p", "s", "t"]
Pai.TSUPAI_STRS = [null, "E", "S", "W", "N", "P", "F", "C"]
Pai.UNKNOWN = new Pai("?")

Pai.paisToStr = (pais) ->
  return if pais then pais.join(" ") else null

Pai.strToPais = (str) ->
	return (new Pai(f) for f in str.split(/\ /))

Pai.compare = (lhs, rhs) ->
  return lhs.id() - rhs.id()

module.exports = Pai
