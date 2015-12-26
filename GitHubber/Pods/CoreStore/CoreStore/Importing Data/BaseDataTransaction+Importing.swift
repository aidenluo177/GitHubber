//
//  BaseDataTransaction+Importing.swift
//  CoreStore
//
//  Copyright (c) 2015 John Rommel Estropia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import CoreData


// MARK: - BaseDataTransaction

public extension BaseDataTransaction {
    
    // MARK: Public
    
    /**
    Creates an `ImportableObject` by importing from the specified import source.
    
    - parameter into: an `Into` clause specifying the entity type
    - parameter source: the object to import values from
    - returns: the created `ImportableObject` instance, or `nil` if the import was ignored
    */
    public func importObject<T where T: NSManagedObject, T: ImportableObject>(
        into: Into<T>,
        source: T.ImportSource) throws -> T? {
            
            CoreStore.assert(
                self.bypassesQueueing || self.transactionQueue.isCurrentExecutionContext(),
                "Attempted to import an object of type \(typeName(into.entityClass)) outside the transaction's designated queue."
            )
            
            return try autoreleasepool {
                
                guard T.shouldInsertFromImportSource(source, inTransaction: self) else {
                    
                    return nil
                }
                
                let object = self.create(into)
                try object.didInsertFromImportSource(source, inTransaction: self)
                return object
            }
    }
    
    /**
    Creates multiple `ImportableObject`s by importing from the specified array of import sources.
    
    - parameter into: an `Into` clause specifying the entity type
    - parameter sourceArray: the array of objects to import values from
    - returns: the array of created `ImportableObject` instances
    */
    public func importObjects<T, S: SequenceType where T: NSManagedObject, T: ImportableObject, S.Generator.Element == T.ImportSource>(
        into: Into<T>,
        sourceArray: S) throws -> [T] {
            
            CoreStore.assert(
                self.bypassesQueueing || self.transactionQueue.isCurrentExecutionContext(),
                "Attempted to import an object of type \(typeName(into.entityClass)) outside the transaction's designated queue."
            )
            
            return try autoreleasepool {
                
                return try sourceArray.flatMap { (source) -> T? in
                    
                    guard T.shouldInsertFromImportSource(source, inTransaction: self) else {
                        
                        return nil
                    }
                    
                    return try autoreleasepool {
                        
                        let object = self.create(into)
                        try object.didInsertFromImportSource(source, inTransaction: self)
                        return object
                    }
                }
            }
    }
    
    /**
    Updates an existing `ImportableUniqueObject` or creates a new instance by importing from the specified import source.
    
    - parameter into: an `Into` clause specifying the entity type
    - parameter source: the object to import values from
    - returns: the created/updated `ImportableUniqueObject` instance, or `nil` if the import was ignored
    */
    public func importUniqueObject<T where T: NSManagedObject, T: ImportableUniqueObject>(
        into: Into<T>,
        source: T.ImportSource) throws -> T?  {
            
            CoreStore.assert(
                self.bypassesQueueing || self.transactionQueue.isCurrentExecutionContext(),
                "Attempted to import an object of type \(typeName(into.entityClass)) outside the transaction's designated queue."
            )
            
            return try autoreleasepool {
                
                let uniqueIDKeyPath = T.uniqueIDKeyPath
                guard let uniqueIDValue = try T.uniqueIDFromImportSource(source, inTransaction: self) else {
                    
                    return nil
                }
                
                if let object = self.fetchOne(From(T), Where(uniqueIDKeyPath, isEqualTo: uniqueIDValue)) {
                    
                    try object.updateFromImportSource(source, inTransaction: self)
                    return object
                }
                else {
                    
                    guard T.shouldInsertFromImportSource(source, inTransaction: self) else {
                        
                        return nil
                    }
                    
                    let object = self.create(into)
                    object.uniqueIDValue = uniqueIDValue
                    try object.didInsertFromImportSource(source, inTransaction: self)
                    return object
                }
            }
    }
    
    /**
    Updates existing `ImportableUniqueObject`s or creates them by importing from the specified array of import sources.
    
    - parameter into: an `Into` clause specifying the entity type
    - parameter sourceArray: the array of objects to import values from
    - parameter preProcess: a closure that lets the caller tweak the internal `UniqueIDType`-to-`ImportSource` mapping to be used for importing. Callers can remove from/add to/update `mapping` and return the updated array from the closure.
    - returns: the array of created/updated `ImportableUniqueObject` instances
    */
    public func importUniqueObjects<T, S: SequenceType where T: NSManagedObject, T: ImportableUniqueObject, S.Generator.Element == T.ImportSource>(
        into: Into<T>,
        sourceArray: S,
        @noescape preProcess: (mapping: [T.UniqueIDType: T.ImportSource]) throws -> [T.UniqueIDType: T.ImportSource] = { $0 }) throws -> [T] {
            
            CoreStore.assert(
                self.bypassesQueueing || self.transactionQueue.isCurrentExecutionContext(),
                "Attempted to import an object of type \(typeName(into.entityClass)) outside the transaction's designated queue."
            )
            
            return try autoreleasepool {
                
                var mapping = Dictionary<T.UniqueIDType, T.ImportSource>()
                let sortedIDs = try autoreleasepool {
                    
                    return try sourceArray.flatMap { (source) -> T.UniqueIDType? in
                        
                        guard let uniqueIDValue = try T.uniqueIDFromImportSource(source, inTransaction: self) else {
                            
                            return nil
                        }
                        
                        mapping[uniqueIDValue] = source
                        return uniqueIDValue
                    }
                }
                
                mapping = try autoreleasepool { try preProcess(mapping: mapping) }
                
                var objects = Dictionary<T.UniqueIDType, T>()
                for object in self.fetchAll(From(T), Where(T.uniqueIDKeyPath, isMemberOf: mapping.keys)) ?? [] {
                    
                    try autoreleasepool {
                        
                        let uniqueIDValue = object.uniqueIDValue
                        
                        guard let source = mapping.removeValueForKey(uniqueIDValue)
                            where T.shouldUpdateFromImportSource(source, inTransaction: self) else {
                                
                                return
                        }
                        
                        try object.updateFromImportSource(source, inTransaction: self)
                        objects[uniqueIDValue] = object
                    }
                }
                
                for (uniqueIDValue, source) in mapping {
                    
                    try autoreleasepool {
                        
                        guard T.shouldInsertFromImportSource(source, inTransaction: self) else {
                            
                            return
                        }
                        
                        let object = self.create(into)
                        object.uniqueIDValue = uniqueIDValue
                        try object.didInsertFromImportSource(source, inTransaction: self)
                        
                        objects[uniqueIDValue] = object
                    }
                }
                
                return sortedIDs.flatMap { objects[$0] }
            }
    }
}
