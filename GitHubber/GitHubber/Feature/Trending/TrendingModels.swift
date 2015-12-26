//
//  TrendingModels.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation
import ObjectMapper

struct TrendingDataRequest {
    // page controll etc...
    
    /**
    *  <#Description#>
    */
    
    
}

struct TrendingDataResponse {
    var list: [TrendingListItemData] = [TrendingListItemData]()
}

struct TrendingDataViewModel {
    var list: [TrendingDataViewCellModel]
}

struct TrendingDataViewCellModel {
    var cellText: String?
    var cellLink: String?
}

struct TrendingListData: Mappable {
    
    var item: [TrendingListItemData]?
    
    init?(_ map: Map) { }
    
    mutating func mapping(map: Map) {
        item <- map["items"]
    }
}

struct TrendingListItemData: Mappable {
    var id: Int = -1
    var name: String?
    var link: String?
    
    init?(_ map: Map) { }
    
    mutating func mapping(map: Map) {
        id <- map["id"]
        name <- map["name"]
        link <- map["html_url"]
    }
}