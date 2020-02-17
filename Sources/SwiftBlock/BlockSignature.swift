//
//  BlockSignature.swift
//
//  Created by Yury Vovk on 14.02.2020.
//  Copyright © 2020. All rights reserved.
//

public struct _BlockSignature {
    
    private static func _alignofArray(_ encoding: String) -> (Int, Int) {
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "]" {
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        let (align, length) = _alignofEncoding(String(encoding[i..<end]), true)
        i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
        
        precondition(encoding.distance(from: i, to: end) != 0 && encoding[i] == "]")
        i = encoding.index(after: i)
        
        return (align, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    private static func _alignofStruct(_ encoding: String) -> (Int, Int) {
        var align = 0
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "=" {
            guard encoding[i] != "}" else {
                i = encoding.index(after: i)
                return (1, encoding.distance(from: encoding.startIndex, to: i))
            }
            
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "}" {
            let (fieldAlign, length) = _alignofEncoding(String(encoding[i..<end]), true)
            i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
            align = max(align, fieldAlign)
        }
        
        precondition(encoding.distance(from: i, to: end) != 0 && encoding[i] == "}")
        i = encoding.index(after: i)
        
        return (align, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    private static func _alignofUnion(_ encoding: String) -> (Int, Int) {
        var align = 0
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "=" {
            guard encoding[i] != ")" else {
                i = encoding.index(after: i)
                return (1, encoding.distance(from: encoding.startIndex, to: i))
            }
            
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != ")" {
            let (fiedAlign, length) = _alignofEncoding(String(encoding[i..<end]), true)
            i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
            align = max(align, fiedAlign)
        }
        
        precondition(encoding.distance(from: i, to: end) != 0 && encoding[i] == ")")
        i = encoding.index(after: i)
        
        return (align, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    private static func _alignofEncoding(_ encoding: String, _ inStruct: Bool) -> (Int, Int) {
        let typeQualifiers = "rnNoORV"
        let align: Int
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        precondition(i != end)

        while i != end && typeQualifiers.contains(encoding[i]) {
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(i != end)
        
        switch encoding[i] {
        case "c", "C": align = MemoryLayout<CChar>.alignment
        case "i", "I": align = MemoryLayout<CInt>.alignment
        case "s", "S": align = MemoryLayout<CShort>.alignment
        case "l", "L": align = MemoryLayout<CLong>.alignment
        case "q", "Q":
            do {
                #if arch(i386) && !os(Windows)
                align = inStruct ? 4 : MemoryLayout<CLongLong>.alignment
                #else
                align = MemoryLayout<CLongLong>.alignment
                #endif
            }
        case "f": align = MemoryLayout<CFloat>.alignment
        case "d": align = MemoryLayout<CDouble>.alignment
        case "D": align = MemoryLayout<CLongDouble>.alignment
        case "B": align = MemoryLayout<CBool>.alignment
        case "v": align = 0
        case "*", "@", "#", ":":
            do {
                align = MemoryLayout<UnsafeMutableRawPointer>.alignment
                
                if encoding[i] == "@" && encoding.distance(from: i, to: end) >= 1 &&
                    encoding[encoding.index(after: i)] == "?" {
                    i = encoding.index(after: i)
                }
            }
        case "[": return _alignofArray(String(encoding[i..<end]))
        case "{": return _alignofStruct(String(encoding[i..<end]))
        case "(": return _alignofUnion(String(encoding[i..<end]))
        case "^":
            do {
                i = encoding.index(after: i)
                let (_, length) = _alignofEncoding(String(encoding[i..<end]), false)
                i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
                return (MemoryLayout<UnsafeMutableRawPointer>.alignment, encoding.distance(from: encoding.startIndex, to: i))
            }
        case "j": preconditionFailure("Complex numbers not supported, yet")
        default: preconditionFailure("Invalid type encoding format")
        }
        
        i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        
        return (align, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    public static func alignof(typeEncoding encoding: String) -> Int {
        let (align, length) = _alignofEncoding(encoding, false)
        precondition(length == encoding.count)
        return align
    }
    
    private static func _sizeofArray(_ encoding: String) -> (Int, Int) {
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        var count = 0
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i].isNumber {
            count = count * 10 + Int(String(encoding[i]))!
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(count != 0)
        
        let (size, length) = _sizeofEncoding(String(encoding[i..<end]))
        i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
        
        precondition(encoding.distance(from: i, to: end) > 0 && encoding[i] == "]")
        i = encoding.index(after: i)
        
        return (count * size, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    private static func _sizeofStruct(_ encoding: String) -> (Int, Int) {
        var i = encoding.startIndex
        let end = encoding.endIndex
        var size = 0
        let (alignment, _) = _alignofStruct(encoding)
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "=" {
            guard encoding[i] != "}" else {
                i = encoding.index(after: i)
                return (0, encoding.distance(from: encoding.startIndex, to: i))
            }
            
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(encoding.distance(from: i, to: end) != 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "}" {
            let (fieldSize, length) = _sizeofEncoding(String(encoding[i..<end]))
            let (fieldAlign, _) = _alignofEncoding(String(encoding[i..<end]), true)
            i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
            
            if size % fieldSize != 0 {
                let padding = fieldAlign - (size % fieldAlign)
                precondition(Int.max - size > padding)
                size += padding
            }
            
            precondition(Int.max - size > fieldSize)
            size +=  fieldSize
        }
        
        precondition(encoding.distance(from: i, to: end) > 0 && encoding[i] == "}")
        i = encoding.index(after: i)
        
        if size % alignment != 0 {
            let padding = alignment - (size % alignment)
            precondition(Int.max - size > padding)
            size += padding
        }
        
        return (size, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    private static func _sizeofUnion(_ encoding: String) -> (Int, Int) {
        var size = 0
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != "=" {
            guard encoding[i] != ")" else {
                return (0, encoding.distance(from: encoding.startIndex, to: i))
            }
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(encoding.distance(from: i, to: end) > 0)
        i = encoding.index(after: i)
        
        while i != end && encoding[i] != ")" {
            let (fieldSize, length) = _sizeofEncoding(String(encoding[i..<end]))
            i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
            size = max(size, fieldSize)
        }
        
        precondition(encoding.distance(from: i, to: end) > 0 && encoding[i] == ")")
        i = encoding.index(after: i)
        
        return (size, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    private static func _sizeofEncoding(_ encoding: String) -> (Int, Int) {
        let typeQualifiers = "rnNoORV"
        var i = encoding.startIndex
        let end = encoding.endIndex
        
        precondition(encoding.distance(from: i, to: end) != 0)
        
        while i != end && typeQualifiers.contains(encoding[i]) {
            i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
        
        precondition(i != end)
        
        let size: Int
        
        switch encoding[i] {
        case "c", "C": size = MemoryLayout<CChar>.size
        case "i", "I": size = MemoryLayout<CInt>.size
        case "s", "S": size = MemoryLayout<CShort>.size
        case "l", "L": size = MemoryLayout<CLong>.size
        case "q", "Q": size = MemoryLayout<CLongLong>.size
        case "f": size = MemoryLayout<CFloat>.size
        case "d": size = MemoryLayout<CDouble>.size
        case "D": size = MemoryLayout<CLongDouble>.size
        case "B": size = MemoryLayout<CBool>.size
        case "v": size = 0
        case "*", "@", "#", ":", "%":
            do {
                size = MemoryLayout<UnsafeMutableRawPointer>.size
                if encoding[i] == "@" && encoding.distance(from: i, to: end) >= 1 &&
                    encoding[encoding.index(after: i)] == "?" {
                    i = encoding.index(after: i)
                }
            }
        case "[": return _sizeofArray(String(encoding[i..<end]))
        case "{": return _sizeofStruct(String(encoding[i..<end]))
        case "(": return _sizeofUnion(String(encoding[i..<end]))
        case "^":
            do {
                i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
                let (_, length) = _sizeofEncoding(String(encoding[i..<end]))
                i = encoding.index(i, offsetBy: length, limitedBy: end) ?? end
                
                return (MemoryLayout<UnsafeMutableRawPointer>.size, encoding.distance(from: encoding.startIndex, to: i))
            }
        case "j": preconditionFailure("Complex numbers not supported, yet")
        default: preconditionFailure("Invalid type encoding format")
        }
        
        i = encoding.index(i, offsetBy: 1, limitedBy: end) ?? end
        return (size, encoding.distance(from: encoding.startIndex, to: i))
    }
    
    public static func sizeof(typeEncoding encoding: String) -> Int {
        let (size, length) = _sizeofEncoding(encoding)
        precondition(length == encoding.count)
        return size
    }
    
    private var _offsets: [Int] = []
    private var _argumentsTypes: [String] = []
    
    public init(fromString signature: String) {
        var i = signature.startIndex
        let end = signature.endIndex
        var last = i
        
        while i != end {
            if signature[i].isNumber {
                precondition(last != signature.index(after: i))
                _argumentsTypes.append(String(signature[last..<i]))
                var offset = Int(String(signature[i]))!
                
                i = signature.index(i, offsetBy: 1, limitedBy: end) ?? end
                
                while i != end && signature[i].isNumber {
                    offset = offset * 10 + Int(String(signature[i]))!
                    i = signature.index(i, offsetBy: 1, limitedBy: end) ?? end
                }
                
                _offsets.append(offset)
                
                guard i != end else {
                    break
                }
                
                last = i
                i = signature.index(before: i)
                
            } else if signature[i] == "{" {
                var depth: Int = 0
                
                while i != end {
                    if signature[i] == "{" {
                        depth += 1
                    } else if signature[i] == "}" {
                        depth -= 1
                        
                        if depth == 0 {
                            break
                        }
                    }
                    
                    i = signature.index(i, offsetBy: 1, limitedBy: end) ?? end
                }
                
                precondition(depth == 0)
                precondition(i != end)
                
            } else if signature[i] == "(" {
                var depth: Int = 0
                
                while i != end {
                    if signature[i] == "(" {
                        depth += 1
                    } else if signature == ")" {
                        depth -= 1
                        
                        if depth == 0 {
                            break
                        }
                    }
                    
                    i = signature.index(i, offsetBy: 1, limitedBy: end) ?? end
                }
                
                precondition(depth == 0)
                precondition(i != end)
            }
            
            i = signature.index(i, offsetBy: 1, limitedBy: end) ?? end
        }
    }
    
    public init?<B>(fromBlock block: B) {
        guard let signature = withUnsafeBlockReference(block, _BlockGetSignatureString) else {
            return nil
        }
        
        self = _BlockSignature(fromString: signature)
    }
    
    public var numberOfArguments: Int {
        return _argumentsTypes.count - 1
    }
    
    public var frameLength: Int {
        return _offsets.first!
    }
    
    public var returnType: String {
        return _argumentsTypes.first!
    }
    
    public var returnTypeSize: Int {
        return _BlockSignature.sizeof(typeEncoding: returnType)
    }
    
    public var returnTypeAlign: Int {
        return _BlockSignature.alignof(typeEncoding: returnType)
    }
    
    public func argumentType(atIndex index: Int) -> String {
        return _argumentsTypes[index + 1]
    }
    
    public func argumentTypeSize(atIndex index: Int) -> Int {
        return _BlockSignature.sizeof(typeEncoding: argumentType(atIndex: index))
    }
    
    public func argumentTypeAlign(atIndex index: Int) -> Int {
        return _BlockSignature.alignof(typeEncoding: argumentType(atIndex: index))
    }
    
    public func argumentOffset(atIndex index: Int) -> Int {
        return _offsets[index + 1]
    }
}
