//
//  ItemListTableViewController.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 10/16/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import ARKit

protocol ItemListDragProtocol: class {
    func closeItemList()
    func showDirection(of object: arItemList)
}

class ItemListTableViewController: UITableViewController, UIGestureRecognizerDelegate {

    weak var delegate: ItemListDragProtocol?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        tableView.addGestureRecognizer(panGestureRecognizer)
        
        // listen to item changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateDataSource), name: Notification.Name("ITEM_CHANGE"), object: nil)

    }
    
    @objc func updateDataSource() {
        tableView.reloadData()
    }
    
    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        if pan.translation(in: tableView).y > 50  && pan.state == .ended{
            delegate?.closeItemList()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ItemModel.shared.anchors.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
        cell.textLabel?.text = ItemModel.shared.anchors[indexPath.row].0
        // Configure the cell...
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.closeItemList()
        delegate?.showDirection(of: ItemModel.shared.anchors[indexPath.row])
        tableView.deselectRow(at: indexPath, animated: true)

    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

}
