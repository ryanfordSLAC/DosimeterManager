//
//  Constants.swift
//  dosimeter-manager
//
//  Created by Admin on 7/20/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit

struct DataProperty {
    // Accessors for data properties
    static let facility = "facility"
    static let facilityNumber = "facilityNumber"
    static let location = "location"
    static let newCode = "newCode"
    static let oldCode = "oldCode"
    static let pickupDate = "pickupDate"
    static let placementDate = "placementDate"
    static let status = "status"
    static let tag = "tag"
    static let modified = "modified"
    
    // Placeholder for a missing data property
    static let placeholder = " "
    
    // Used for the period property
    static let deleteDate = "deleteDate"
}

struct Status {
    static let unrecovered: String = "Needs replacing"
    static let recovered: String = "Replaced"
    static let flagged: String = "Needs investigation"
    static let retired: String = "Retired"
}

struct Colors {
    static let salmon: UIColor = UIColor(red: CGFloat(1.0), green: CGFloat(126.0/255), blue: CGFloat(121.0/255), alpha: CGFloat(1.0))
    static let blue: UIColor = UIColor(red: CGFloat(0.0), green: CGFloat(122.0/255), blue: CGFloat(1.0), alpha: CGFloat(1.0))
}

struct Templates {
    static let exportFields = "Building,Tag,Location,Old Inlight,Placement Date,Pickup Date,New Inlight\n"
}
