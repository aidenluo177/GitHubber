//
//  AppDelegate.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import UIKit
import p2_OAuth2

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    lazy private(set) var oauth: OAuth2 = {
        let settings = [
            "client_id": "f08e510e02c9de4ddbaa",
            "client_secret": "ee22ce793b246ee51081b40b1b56aa3031020f41",
            "authorize_uri": "https://github.com/login/oauth/authorize",
            "token_uri": "https://github.com/login/oauth/access_token",
            "redirect_uris": ["githubber://oauth/callback"],
            "keychain": true,
            "title": "Github"
            ] as OAuth2JSON
        let oauth2 = OAuth2CodeGrant(settings: settings)
        oauth2.onAuthorize = { parameters in
            self.window?.rootViewController = UIStoryboard.instanceViewController(identifier: .TrendingScene, viewIdentifier: .TrendingViewNavController)
        }
        oauth2.onFailure = { error in
            if let error = error {
                print(error)
            }
        }
        return oauth2
    }()


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
//        if oauth.hasUnexpiredAccessToken() {
            window?.rootViewController = UIStoryboard.instanceViewController(identifier: .TrendingScene, viewIdentifier: .TrendingViewNavController)
//        } else {
//            window?.rootViewController = UIStoryboard.instanceViewController(identifier: .LoginScene, viewIdentifier: .LoginViewController)
//        }
        
        window?.makeKeyAndVisible()
        return true
    }

    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        if url.absoluteString.hasPrefix("githubber://oauth/callback") {
            do {
                try oauth.handleRedirectURL(url)
            } catch {
                
            }
        }
        return true
    }
    
}

