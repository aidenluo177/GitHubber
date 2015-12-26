//
//  TrendingWorker.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation
import Moya
import ObjectMapper

protocol TrendingWorker {
    
    func fetchTrendingData(success:((data: TrendingDataResponse) -> Void), fail: ((error: ErrorType?) -> Void))
    
}

struct TrendingAPIWorking: TrendingWorker {
    
    var api: MoyaProvider<GitHub> = MoyaProvider()
    
    func fetchTrendingData(success: ((data: TrendingDataResponse) -> Void), fail: ((error: ErrorType?) -> Void)) {
        api.request(.Trending) { (result) -> () in
            switch result {
            case .Success(let response):
                do {
                    let JSON = try response.mapJSON()
                    let listData = Mapper<TrendingListData>().map(JSON)
                    success(data: TrendingDataResponse(list: listData!.item!))
                } catch {
                    //error handle
                }
            case .Failure(let error):
                // error handle
                print(error)
                break
            }
        }
    }
    
}

//struct TrendingDatabaseWokring: TrendingWorker {
//    
//    
//    
//}