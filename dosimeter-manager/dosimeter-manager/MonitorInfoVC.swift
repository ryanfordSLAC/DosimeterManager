//
//  MonitorInfoVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/25/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit

class MonitorInfoVC: MonitorDisplayVC {
    @IBOutlet weak var facility: UILabel!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var barcode: UILabel!
    @IBOutlet weak var newBarcode: UILabel!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var tag: UILabel!
    @IBOutlet weak var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLabels(labelProperties: [DataProperty.facility: self.facility, DataProperty.self.location: location,
                                    DataProperty.status: self.status, DataProperty.tag: self.tag,
                                    DataProperty.oldCode: self.barcode, DataProperty.newCode: self.newBarcode])
        self.location.numberOfLines = 0
        if (self.currentMode == .error) {
            self.button.setTitle("Flag", for: .normal)
            self.button.backgroundColor = Colors.salmon
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPressButton(_ sender: Any) {
        if (self.currentMode == .error) {
            guard let areaMonitor = self.areaMonitor else {
                return
            }
            do {
                areaMonitor.setValue(Status.flagged, forKey: DataProperty.status)
                try self.saveMonitor(areaMonitor: areaMonitor)
            } catch {
                // TODO: Provide a useful error for the user
                print("Error: Couldn't save the status of the flagged area monitor")
                return
            }
        }
    }
}
