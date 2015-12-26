//
//  Moya+Utils.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation
import Moya
import ObjectMapper

public extension Response {
    
    /// Maps data received from the signal into an object which implements the Mappable protocol.
    /// If the conversion fails, the signal errors.
    public func mapObjectMapper<T: Mappable>() throws -> T {
        guard let object = Mapper<T>().map(try mapJSON()) else {
            throw Error.JSONMapping(self)
        }
        return object
    }
    
    /// Maps data received from the signal into an array of objects which implement the Mappable
    /// protocol.
    /// If the conversion fails, the signal errors.
    public func mapObjectMapper<T: Mappable>() throws -> [T] {
        guard let objects = Mapper<T>().mapArray(try mapJSON()) else {
            throw Error.JSONMapping(self)
        }
        return objects
    }
    
}