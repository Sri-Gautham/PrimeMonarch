//
//  Item.swift
//  PrimeMonarch
//
//  Created by Sri Gautham Subramani on 8/2/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
