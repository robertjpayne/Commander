public enum ArgumentType {
  case argument
  case option
}


public protocol ArgumentDescriptor {
  associatedtype ValueType

  /// The arguments name
  var name:String { get }

  /// The arguments description
  var description:String? { get }

  var type:ArgumentType { get }

  /// Parse the argument
  func parse(_ parser:ArgumentParser) throws -> ValueType
}
extension ArgumentDescriptor {
  
  internal func helpDescription(ansi: Bool) -> String {
    var d = ""

    if ansi {
      d += "\(ANSI.blue)\(self.name)\(ANSI.reset)"
    } else {
      d += "\(self.name)"
    }

    if let description = self.description {
      d += " - \(description)"
    }

    return d
  }
  
}

extension ArgumentConvertible {
  init(string: String) throws {
    try self.init(parser: ArgumentParser(arguments: [string]))
  }
}


open class VaradicArgument<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = [T]

  open let name: String
  open let description: String?

  open var type: ArgumentType { return .argument }

  public init(_ name: String, description: String? = nil) {
    self.name = name
    self.description = description
  }

  open func parse(_ parser: ArgumentParser) throws -> ValueType {
    return try Array<T>(parser: parser)
  }
}


open class Argument<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = T
  public typealias Validator = (ValueType) throws -> ValueType

  open let name:String
  open let description:String?
  open let validator:Validator?

  open var type:ArgumentType { return .argument }

  public init(_ name:String, description:String? = nil, validator: Validator? = nil) {
    self.name = name
    self.description = description
    self.validator = validator
  }

  open func parse(_ parser:ArgumentParser) throws -> ValueType {
    let value: T

    do {
      value = try T(parser: parser)
    } catch ArgumentError.missingValue {
      throw ArgumentError.missingValue(argument: name)
    } catch {
      throw error
    }

    if let validator = validator {
      return try validator(value)
    }

    return value
  }
}


open class Option<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = T
  public typealias Validator = (ValueType) throws -> ValueType

  open let name:String
  open let flag:Character?
  open let description:String?
  open let `default`:ValueType?
  open var type:ArgumentType { return .option }
  open let validator:Validator?

  public init(_ name:String, _ default:ValueType?, flag:Character? = nil, description:String? = nil, validator: Validator? = nil) {
    self.name = name
    self.flag = flag
    self.description = description
    self.`default` = `default`
    self.validator = validator
  }

  open func parse(_ parser:ArgumentParser) throws -> ValueType {
    if let value = try parser.shiftValueForOption(name) {
      let value = try T(string: value)

      if let validator = validator {
        return try validator(value)
      }

      return value
    }

    if let flag = flag {
      if let value = try parser.shiftValueForFlag(flag) {
        let value = try T(string: value)

        if let validator = validator {
          return try validator(value)
        }

        return value
      }
    }
    
    if let `default` = `default` {
      return `default`
    }

    throw ArgumentError.missingValue(argument: "--\(self.name)")
  }
  
  internal func helpDescription(ansi: Bool) -> String {
    var str = ""
    
    if ansi {
      str += "--\(ANSI.blue)\(name)\(ANSI.reset)"
      if let flag = flag {
        str += ", \(ANSI.blue)-\(flag)\(ANSI.reset)"
      }
    } else {
      str += "--\(name)"
      if let flag = flag {
        str += ", -\(flag)"
      }
    }
    
    if let description = description {
      str += " - \(description)"
    }
    
    if let `default` = `default` {
      str += " (Default: \(`default`))"
    }
    
    return str
  }
  
}


open class Options<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = [T]

  open let name:String
  open let description:String?
  open let count:Int
  open let `default`:ValueType?
  open var type:ArgumentType { return .option }

  public init(_ name:String, _ default:ValueType?, count: Int, description:String? = nil) {
    self.name = name
    self.`default` = `default`
    self.count = count
    self.description = description
  }

  open func parse(_ parser:ArgumentParser) throws -> ValueType {
    let values = try parser.shiftValuesForOption(name, count: count)
    if let value = try values?.map { try T(string: $0) } {
      return value
    }
    
    if let `default` = `default` {
      return `default`
    }
    
    throw ArgumentError.missingValue(argument: "--\(self.name)")
  }
  
  internal func helpDescription(ansi: Bool) -> String {
    var str = ""
    
    if ansi {
      str += "--\(ANSI.blue)\(name)\(ANSI.reset)"
    } else {
      str += "--\(name)"
    }
    
    if let description = description {
      str += " - \(description)"
    }
    
    if let `default` = `default` {
      str += " (Default: \(`default`))"
    }
    
    return str
  }
  
}


open class Flag : ArgumentDescriptor {
  public typealias ValueType = Bool

  open let name:String
  open let flag:Character?
  open let disabledName:String
  open let disabledFlag:Character?
  open let description:String?
  open let `default`:ValueType
  open var type:ArgumentType { return .option }

  public init(_ name:String, _ default:Bool = false, flag:Character? = nil, disabledName:String? = nil, disabledFlag:Character? = nil, description:String? = nil) {
    self.name = name
    self.disabledName = disabledName ?? "no-\(name)"
    self.flag = flag
    self.disabledFlag = disabledFlag
    self.description = description
    self.`default` = `default`
  }

  open func parse(_ parser:ArgumentParser) throws -> ValueType {
    if parser.hasOption(disabledName) {
      return false
    }

    if parser.hasOption(name) {
      return true
    }

    if let flag = flag {
      if parser.hasFlag(flag) {
        return true
      }
    }
    if let disabledFlag = disabledFlag {
      if parser.hasFlag(disabledFlag) {
        return false
      }
    }

    return `default`
  }
  
  internal func helpDescription(ansi: Bool) -> String {
    var str = ""
    
    if ansi {
      str += "--\(ANSI.blue)\(name)\(ANSI.reset)"
      if let flag = flag {
        str += ", \(ANSI.blue)-\(flag)\(ANSI.reset)"
      }
    } else {
      str += "--\(name)"
      if let flag = flag {
        str += ", -\(flag)"
      }
    }
    
    if ansi {
      str += ", --\(ANSI.blue)\(disabledName)\(ANSI.reset)"
      if let flag = disabledFlag {
        str += ", \(ANSI.blue)-\(flag)\(ANSI.reset)"
      }
    } else {
      str += ", --\(disabledName)"
      if let flag = disabledFlag {
        str += ", -\(flag)"
      }
    }
    
    if let description = description {
      str += " - \(description)"
    }
    
    str += " (Default: \(`default`))"
    
    return str
  }
}


class BoxedArgumentDescriptor {
  let name:String
  let description:String?
  let `default`:String?
  let type:ArgumentType
  let plainHelpDescription: String
  let ansiHelpDescription: String
  
  init<T : ArgumentDescriptor>(value:T) {
    name = value.name
    description = value.description
    type = value.type

    if let value = value as? Flag {
      `default` = value.`default`.description
    } else {
      // TODO, default for Option and Options
      `default` = nil
    }
    
    plainHelpDescription = value.helpDescription(ansi: false)
    ansiHelpDescription = value.helpDescription(ansi: true)
  }
}


class UsageError : Error, ANSIConvertible, CustomStringConvertible {
  let message: String
  let help: Help

  init(_ message: String, _ help: Help) {
    self.message = message
    self.help = help
  }

  var description: String {
    return [message, help.description].filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  var ansiDescription: String {
    return [message, help.ansiDescription].filter { !$0.isEmpty }.joined(separator: "\n\n")
  }
}


class Help : Error, ANSIConvertible, CustomStringConvertible {
  let command:String?
  let group:Group?
  let descriptors:[BoxedArgumentDescriptor]

  init(_ descriptors:[BoxedArgumentDescriptor], command:String? = nil, group:Group? = nil) {
    self.command = command
    self.group = group
    self.descriptors = descriptors
  }

  func reraise(_ command:String? = nil) -> Help {
    if let oldCommand = self.command, let newCommand = command {
      return Help(descriptors, command: "\(newCommand) \(oldCommand)")
    }
    return Help(descriptors, command: command ?? self.command)
  }

  var description: String {
    var output = [String]()

    let arguments = descriptors.filter { $0.type == ArgumentType.argument }
    let options = descriptors.filter   { $0.type == ArgumentType.option }

    if let command = command {
      let args = arguments.map { "<\($0.name)>" }
      let usage = ([command] + args).joined(separator: " ")

      output.append("Usage:")
      output.append("")
      output.append("    \(usage)")
      output.append("")
    }

    if let group = group {
      output.append("Commands:")
      output.append("")
      for command in group.commands {
        if let description = command.description {
          output.append("    + \(command.name) - \(description)")
        } else {
          output.append("    + \(command.name)")
        }
      }
      output.append("")
    }
    
    if !arguments.isEmpty {
      output.append("Arguments:")
      for argument in arguments {
        output.append("    " + argument.plainHelpDescription)
      }
      output.append("")
    }

    if !options.isEmpty {
      output.append("Options:")
      for option in options {
        output.append("    " + option.plainHelpDescription)
      }
    }

    return output.joined(separator: "\n")
  }

  var ansiDescription: String {
    var output = [String]()

    let arguments = descriptors.filter { $0.type == ArgumentType.argument }
    let options = descriptors.filter   { $0.type == ArgumentType.option }

    if let command = command {
      let args = arguments.map { "<\($0.name)>" }
      let usage = ([command] + args).joined(separator: " ")

      output.append("Usage:")
      output.append("")
      output.append("    \(usage)")
      output.append("")
    }

    if let group = group {
      output.append("Commands:")
      output.append("")
      for command in group.commands {
        if let description = command.description {
          output.append("    + \(ANSI.green)\(command.name)\(ANSI.reset) - \(description)")
        } else {
          output.append("    + \(ANSI.green)\(command.name)\(ANSI.reset)")
        }
      }
      output.append("")
    }
    
    if !arguments.isEmpty {
      output.append("Arguments:")
      for argument in arguments {
        output.append("    " + argument.ansiHelpDescription)
      }
      output.append("")
    }
    
    if !options.isEmpty {
      output.append("Options:")
      for option in options {
        output.append("    " + option.ansiHelpDescription)
      }
    }

    return output.joined(separator: "\n")
  }
}
