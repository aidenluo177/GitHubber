//
//  TrendingViewController.swift
//  GitHubber
//
//  Created by aidenluo on 12/26/15.
//  Copyright © 2015 aiden. All rights reserved.
//

import UIKit
import SafariServices

typealias TrendingViewControllerInput = TrendingPresenterToViewControllerPipline
typealias TrendingViewControllerOutput = TrendingViewControllerToInteractorPipline

class TrendingViewController: UITableViewController {
    
    private(set) var output: TrendingViewControllerOutput!
    private(set) var data = [TrendingDataViewCellModel]()
    @IBOutlet weak var refresher: UIRefreshControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVIP()
        refreshControl = refresher
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func refreshAction(sender: UIRefreshControl) {
        let request = TrendingDataRequest()
        output?.refreshData(request)
    }
    
    private func setupVIP() {
        let interactor = TrendingInteractor()
        let presenter = TrendingPresenter()
        output = interactor
        interactor.output = presenter
        presenter.output = self
    }

}

// MARK: - Input

extension TrendingViewController: TrendingViewControllerInput {
    
    func displayData(viewModel: TrendingDataViewModel) {
        data.removeAll()
        viewModel.list.forEach { data.append($0) }
        refreshControl?.endRefreshing()
        tableView.reloadData()
    }
    
}


// MARK: - TableView Datasource

extension TrendingViewController {
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard indexPath.row < data.count else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCellWithIdentifier("TrendingCell", forIndexPath: indexPath)
        cell.textLabel?.text = data[indexPath.row].cellText
        return cell
    }
    
}

// MARK: - TableView Delegate


extension TrendingViewController {
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if let link = data[indexPath.row].cellLink, url = NSURL(string: link) {
            let viewController = SFSafariViewController(URL: url)
            presentViewController(viewController, animated: true, completion: nil)
        }
        
    }
    
}