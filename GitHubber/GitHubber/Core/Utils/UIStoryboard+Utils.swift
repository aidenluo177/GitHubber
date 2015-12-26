//
//  UIStoryboard+Utils.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import UIKit

public enum StoryboardIdentifier: String {
    // MARK: - Login
    case LoginScene
    // MARK: - Trending
    case TrendingScene
}

public enum ViewControllerIdentifier: String {
    // MARK: - Login
    case LoginViewController
    // MARK: - Trending
    case TrendingViewNavController
    case TrendingViewController
}

extension UIStoryboard {
    
    class func instanceViewController(identifier id: StoryboardIdentifier, viewIdentifier vid: ViewControllerIdentifier) -> UIViewController? {
        return UIStoryboard(name: id.rawValue, bundle: nil).instantiateViewControllerWithIdentifier(vid.rawValue)
    }
    
}