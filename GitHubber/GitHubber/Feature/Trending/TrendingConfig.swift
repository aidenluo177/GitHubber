//
//  TrendingConfig.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation

protocol TrendingViewControllerToInteractorPipline {
    
    func refreshData(request: TrendingDataRequest)
    
}

protocol TrendingInteractorToPresenterPipline {
    
    func presentData(response: TrendingDataResponse)
}

protocol TrendingPresenterToViewControllerPipline: class {
    
    func displayData(viewModel: TrendingDataViewModel)
    
}