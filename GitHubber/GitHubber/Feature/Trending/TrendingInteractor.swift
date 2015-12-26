//
//  TrendingInteractor.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation

typealias TrendingInteractorInput = TrendingViewControllerToInteractorPipline
typealias TrendingInteractorOutput = TrendingInteractorToPresenterPipline

class TrendingInteractor {
    
    var output: TrendingInteractorOutput!
    var worker: TrendingWorker = TrendingAPIWorking()
    
}

extension TrendingInteractor: TrendingInteractorInput {
    
    func refreshData(request: TrendingDataRequest) {
        worker.fetchTrendingData({ (data) -> Void in
            self.output.presentData(data)
            }) { (error) -> Void in
                // handle error
        }
    }
    
}
