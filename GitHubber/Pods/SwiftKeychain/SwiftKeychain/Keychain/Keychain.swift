//
//  Keychain.swift
//  SwiftKeychain
//
//  Created by Yanko Dimitrov on 11/11/14.
//  Copyright (c) 2014 Yanko Dimitrov. All rights reserved.
//

import Foundation

public class Keychain: KeychainService {
    
    public let accessMode: NSString
    public let serviceName: String
    public var accessGroup: String?
    private let errorDomain = "swift.keychain.error.domain"
    
	static var sharedKeychain: Keychain = Keychain()
    
    ///////////////////////////////////////////////////////
    // MARK: - Initializers
    ///////////////////////////////////////////////////////
    
    public init(serviceName name: String, accessMode: NSString = kSecAttrAccessibleWhenUnlocked, group: String? = nil) {
        
        self.accessMode = accessMode
        
        serviceName = name
        accessGroup = group
    }
    
    public convenience init() {
        self.init(serviceName: "swift.keychain")
    }
    
    ///////////////////////////////////////////////////////
    // MARK: - Errors
    ///////////////////////////////////////////////////////
    
    private func errorForStatusCode(statusCode: OSStatus) -> NSError {
        
        return NSError(domain: errorDomain, code: Int(statusCode), userInfo: nil)
    }
    
    ///////////////////////////////////////////////////////
    // MARK: - KeychainService
    ///////////////////////////////////////////////////////
    
    public func add(key: KeychainItem) -> NSError? {
        
        let secretFields = key.fieldsToLock()
        
        if secretFields.count == 0 {
            return errorForStatusCode(errSecParam)
        }
        
        let query = key.makeQueryForKeychain(self)
        
        query.addFields(secretFields)
        
        let status = SecItemAdd(query.fields, nil)
        
        if status != errSecSuccess {
            return errorForStatusCode(status)
        }
        
        return nil
    }
    
    /**
        Updates or adds the given keychain item.
        
        :param: key The keychain item to update or add
        :returns: An NSError if something goes wrong, nil otherwise
     */
    public func update(key: KeychainItem) -> NSError? {
        
        let changes = key.fieldsToLock()
        if changes.count == 0 {
            
            return errorForStatusCode(errSecParam)
        }
        
        let query = key.makeQueryForKeychain(self)
        let status = SecItemUpdate(query.fields, changes)
        
        if status != errSecSuccess {
            
            if status == errSecItemNotFound {
                return add(key)
            }
            
            return errorForStatusCode(status)
        }
        
        return nil
    }
    
    public func remove(key: KeychainItem) -> NSError? {
        
        let query = key.makeQueryForKeychain(self)
        let status = SecItemDelete(query.fields)
        
        if status != errSecSuccess {
            return errorForStatusCode(status)
        }
        
        return nil
    }
    
    public func get<T: BaseKey>(key: T) -> (item: T?, error: NSError?) {
        
        let query = key.makeQueryForKeychain(self)
        
        query.shouldReturnData()
        
        var result: AnyObject?
        let status = withUnsafeMutablePointer(&result) { cfPointer -> OSStatus in
            SecItemCopyMatching(query.fields, UnsafeMutablePointer(cfPointer))
        }
        
        if status != errSecSuccess {
            return (nil, errorForStatusCode(status))
        }
        
        if let resultData = result as? NSData {
            
            key.unlockData(resultData)
            
            return (key, nil)
        }
        
        return (nil, nil)
    }
}

///////////////////////////////////////////////////////
// MARK: - Unit testing
///////////////////////////////////////////////////////

public extension Keychain {
    
    public class func setTestingInstance(mockKeychain: Keychain) {
        
        sharedKeychain = mockKeychain
    }
}
