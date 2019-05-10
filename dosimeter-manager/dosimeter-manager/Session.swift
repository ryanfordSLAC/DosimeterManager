//
//  Session.swift
//  dosimeter-manager
//
//  Created by Admin on 7/21/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

struct Session {
    var facility: String?
    var facilityNumber: String?
    
    init(forFacility facility: String?, withNumber number: String?) {
        self.facility = facility
        self.facilityNumber = number
    }
}
