//
//  GitHubAPI.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation
import Moya

private extension String {
    var URLEscapedString: String {
        return self.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())!
    }
}

enum GitHub {
    case Trending
}

extension GitHub: TargetType {
    var baseURL: NSURL { return NSURL(string: "https://api.github.com")! }
    
    var path: String {
        switch self {
        case .Trending:
            return "search/repositories"
        }
    }
    
    var method: Moya.Method {
        return .GET
    }
    
    var parameters: [String: AnyObject]? {
        switch self {
        case .Trending:
            var param = [String: String]()
            param["q"] = "stars:>=500 fork:true language:swift"
            param["sort"] = "stars"
            return param
        }
    }
    
    var sampleData: NSData {
        return NSData()
    }
}