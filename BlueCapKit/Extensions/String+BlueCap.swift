//
//  String+BlueCap.swift
//  BlueCap
//
//  Created by Troy Stribling on 6/29/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import Foundation

public extension String {
    
    public var floatValue : Float {
        return (self as NSString).floatValue
    }
    
    public func dataFromHexString() -> Data {
        var bytes = [UInt8]()
        for i in 0..<(self.characters.count/2) {
            let range = self.characters.index(self.startIndex, offsetBy: 2*i)..<self.characters.index(self.startIndex, offsetBy: 2*i+2)
            let stringBytes = self.substring(with: range)
            let byte = strtol((stringBytes as NSString).utf8String, nil, 16)
            bytes.append(UInt8(byte))
        }
        return Data(bytes: UnsafePointer<UInt8>(bytes), count:bytes.count)
    }
    
}
