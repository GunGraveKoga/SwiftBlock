//
//  Block.swift
//
//  Created by Yury Vovk on 14.02.2020.
//  Copyright © 2020. All rights reserved.
//

#if canImport(Darwin)
@_exported import Darwin
#else
@_cdecl("_Block_copy")
func _Block_copy(_ aBlock: UnsafeRawPointer!) -> UnsafeMutableRawPointer!

@_cdecl("_Block_release")
func _Block_release(_ aBlock: UnsafeRawPointer!) -> Void
#endif

public struct _BLockFlags : OptionSet {
    static let deallocating = _BLockFlags(rawValue: 0x0001)
    static let referenceCountMask = _BLockFlags(rawValue: 0xfffe)
    static let needsFree = _BLockFlags(rawValue: 1 << 24)
    static let copyDispose = _BLockFlags(rawValue: 1 << 25)
    static let hasCTOR = _BLockFlags(rawValue: 1 << 26)
    static let isGC = _BLockFlags(rawValue: 1 << 27)
    static let isGlobal = _BLockFlags(rawValue: 1 << 28)
    static let useSTRET = _BLockFlags(rawValue: 1 << 29)
    static let hasSignature = _BLockFlags(rawValue: 1 << 30)
    
    public typealias RawValue = CInt
    
    public let rawValue: RawValue
    
    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

public struct _BlockDescriptor_1 {
    public let reserved: CUnsignedLong
    public let size: CUnsignedLong
}

public struct _BlockDescriptor_2 {
    public let copy: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    public let dispose: @convention(c) (UnsafeMutableRawPointer?) -> Void
}

public struct _BlockDescriptor_3 {
    public let signature: UnsafePointer<CChar>
    public let layout: UnsafePointer<CChar>
}

public struct _BlockLiteral {
    public let isa: UnsafeMutableRawPointer
    public let flags: CInt
    public let reserved: CInt
    public let invoke: @convention(c) () -> Void
    public let descriptor: UnsafeMutablePointer<_BlockDescriptor_1>
}

public func _BlockGetSignature(_ block: UnsafeMutablePointer<_BlockLiteral>) -> String? {
    let flags = _BLockFlags(rawValue: block.pointee.flags)
    
    if flags.contains(.hasSignature) {
        var descriptor = UnsafeMutableRawPointer(block.pointee.descriptor).advanced(by: MemoryLayout<_BlockDescriptor_1>.size)
        
        if flags.contains(.copyDispose) {
            descriptor = descriptor.advanced(by: MemoryLayout<_BlockDescriptor_2>.size)
        }
        
        let signature = descriptor.assumingMemoryBound(to: _BlockDescriptor_3.self).pointee.signature
        
        return String(cString: signature)
    }
    
    return nil
}

public func withUnsafeBlockReference<B, T>(_ block: B, _ body: (UnsafeMutablePointer<_BlockLiteral>) throws -> T) rethrows -> T {
    return try body(unsafeBitCast(block, to: UnsafeMutablePointer<_BlockLiteral>.self))
}
