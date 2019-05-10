//
//  MonitorVerifyVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/25/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit

class MonitorVerifyVC: MonitorDisplayVC {
    @IBOutlet weak var facility: UILabel!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var barcode: UILabel!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var tag: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let barcode = self.newEntity[DataProperty.oldCode] else {
            setupLabels(labelProperties: [DataProperty.facility: self.facility, DataProperty.location: self.location,
                                          DataProperty.oldCode: self.barcode, DataProperty.status: self.status,
                                          DataProperty.tag: self.tag])
            return
        }
        setupLabels(labelProperties: [DataProperty.facility: self.facility, DataProperty.location: self.location,
                                      DataProperty.status: self.status, DataProperty.tag: self.tag])
        self.barcode.text = barcode
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
