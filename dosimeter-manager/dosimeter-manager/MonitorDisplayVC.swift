//
//  MonitorDisplayVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/21/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData

class MonitorDisplayVC: QueryModeVC {
    
    var areaMonitor: NSManagedObject?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setupLabels(labelProperties: [String: UILabel]) {
        guard let areaMonitor = self.areaMonitor else {
            return
        }
        for key in labelProperties.keys {
            let value = areaMonitor.value(forKey: key) as? String ?? DataProperty.placeholder
            labelProperties[key]!.text = value
        }
    }
}

