//
//  ItemModel.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 10/16/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import ARKit

protocol ItemListDragProtocol: class {
    func closeItemList()
    func showDirection(of object: ARItem)
}

struct ARItem {
    let name: String
    let anchor: ARAnchor
}

class ItemModel {
    
    static let shared = ItemModel()
    
    private var itemsList: [ARItem] = []
    
    public func getList() -> [ARItem] {
        return itemsList
    }
    
    public func addItem(name: String, anchor: ARAnchor) {
        let item = ARItem(name: name, anchor: anchor)
        itemsList.append(item)
    }
    
    public func removeAll() {
        itemsList.removeAll()
    }
    
}
