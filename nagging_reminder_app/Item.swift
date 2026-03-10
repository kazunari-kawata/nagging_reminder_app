//
//  Item.swift
//  nagging_reminder_app
//
//  Created by Kawata Kazunari on 2026/03/10.
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
