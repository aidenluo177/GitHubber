//
//  LoginViewController.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import UIKit
import p2_OAuth2

class LoginViewController: UIViewController {
    
    @IBAction func loginAction(sender: UIButton) {
        let oauth = (UIApplication.sharedApplication().delegate as! AppDelegate).oauth
        oauth.authorize()
    }

}
