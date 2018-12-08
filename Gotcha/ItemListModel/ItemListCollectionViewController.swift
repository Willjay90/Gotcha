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
    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ItemModel.shared.getList().count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        if let label = cell.viewWithTag(1) as? UILabel {
            label.text = ItemModel.shared.getList()[indexPath.row].name
        }
        cell.backgroundColor = UIColor.green.withAlphaComponent(0.45)
        cell.layer.cornerRadius = 20
        return cell
    }

    // MARK: UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.closeItemList()
        delegate?.showDirection(of: ItemModel.shared.getList()[indexPath.row])
        collectionView.deselectItem(at: indexPath, animated: true)
    }

    
}

extension ItemListCollectionViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 150, height: 150)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
}
