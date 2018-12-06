//
//  ItemListCollectionViewController.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 12/4/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class ItemListCollectionViewController: UICollectionViewController {

    weak var delegate: ItemListDragProtocol?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        // listen to item changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateDataSource), name: Notification.Name("ITEM_CHANGE"), object: nil)
        
    }

    @objc func updateDataSource() {
        collectionView.reloadData()
    }
    
    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        if pan.translation(in: collectionView).y > 50  && pan.state == .ended {
            delegate?.closeItemList()
        }
    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ItemModel.shared.anchors.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        if let label = cell.viewWithTag(1) as? UILabel {
            label.text = ItemModel.shared.anchors[indexPath.row].0
        }
        cell.backgroundColor = UIColor.green.withAlphaComponent(0.45)
        cell.layer.cornerRadius = 20
        return cell
    }

    // MARK: UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.closeItemList()
        delegate?.showDirection(of: ItemModel.shared.anchors[indexPath.row])
        collectionView.deselectItem(at: indexPath, animated: true)
    }

    
}
