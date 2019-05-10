//
//  FlagHandlerVC.swift
//  dosimeter-manager
//
//  Created by Admin on 8/6/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData

class FlagHandlerVC: QueryModeVC {

    @IBOutlet weak var flaggedLabel: UILabel!
    var areaMonitor: NSManagedObject?
    @IBOutlet weak var replaceButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var replaceButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.flaggedLabel.numberOfLines = 0
        do {
            self.areaMonitor = try self.addEntity(entity: self.newEntity)
            self.flaggedLabel.text = "The area monitor has been flagged as being in an unknown location. Would you like to continue replaceing the area monitor?"
        } catch {
            self.replaceButton.isHidden = true
            self.replaceButton.isUserInteractionEnabled = false
            self.replaceButtonHeight.constant = 0
            self.flaggedLabel.text = "An error occured while trying to flag the area monitor. Please scan a different area monitor."
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
