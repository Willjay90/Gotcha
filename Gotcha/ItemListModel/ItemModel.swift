//
//  ItemModel.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 10/16/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import ARKit

typealias arItemList = (String, ARAnchor)

protocol ItemListDragProtocol: class {
    func closeItemList()
    func showDirection(of object: arItemList)
}

class ItemModel {
    
    static let shared = ItemModel()
    
    var anchors: [arItemList] = [] {
        didSet {
            NotificationCenter.default.post(name: Notification.Name("ITEM_CHANGE"), object: nil)
        }
    }
    
    func removeAll() {
        anchors.removeAll()
    }
    
}
