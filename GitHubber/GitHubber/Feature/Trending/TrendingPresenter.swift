//
//  TrendingPresenter.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import Foundation


typealias TrendingPresenterInput = TrendingInteractorToPresenterPipline
typealias TrendingPresenterOutput = TrendingPresenterToViewControllerPipline

class TrendingPresenter {
    weak var output: TrendingPresenterOutput!
}

extension TrendingPresenter: TrendingPresenterInput {
    
    func presentData(response: TrendingDataResponse) {
        //Transform etc...
        let viewModel = TrendingDataViewModel(list: response.list.map {
            var cellModel = TrendingDataViewCellModel()
            cellModel.cellText = $0.name
            cellModel.cellLink = $0.link
            return cellModel
            })
        output.displayData(viewModel)
    }
    
}