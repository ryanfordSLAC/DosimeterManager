//
//  ExportVC.swift
//  dosimeter-manager
//
//  Created by Admin on 8/13/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData
import MessageUI

class ExportVC: FileManagerVC {
    @IBOutlet weak var deleteButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deleteButton.isEnabled = false
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        do {
            let managedContext = appDelegate.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: EntityNames.period)
            let periodContainer = try managedContext.fetch(fetchRequest)
        
            if (periodContainer.count == 1) {
                let period = periodContainer[0] as! NSManagedObject
                if (validDeleteDate(period)) {
                    deleteButton.isHidden = false
                    deleteButton.isEnabled = true
                }
            }
        } catch {
            return
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPressDeleteData(_ sender: Any) {
        generateWarning(title: "Confirm Delete", message: "This action will clear all local data for the device, are you really sure you want to do this?",
                    continueMsg: "Delete Data", cancelMsg: "Go Back",
                    continueAction: {action in
                        self.purgeCoreData()
                    },
                    cancelAction: {action in
                        
                    })
    }
    
    @IBAction func didPressExport(_ sender: Any) {
        do {
            let exportData = try query(withKVPs: nil, fetchRetired: true)
            let (fileURL, filename) = try exportToCSV(areaMonitors: exportData)
            let fileData = NSData(contentsOf: fileURL)
            sendEmail(to: [Remote.email], subject: "test", body: "test", attachmentHandle: filename, attachmentData: fileData as Data?)
        } catch let error as NSError {
            print("\(error), \(error.userInfo)")
            return
        }
    }
}
