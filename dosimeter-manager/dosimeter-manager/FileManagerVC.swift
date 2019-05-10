//
//  FileManagerVC.swift
//  dosimeter-manager
//
//  Created by Admin on 8/19/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData
import MessageUI

class FileManagerVC: QueryVC, MFMailComposeViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    enum exportError: Error {
        case corruptData
        case unknownPath
        case unmodified
    }
    
    struct Remote {
        static let email = "xiaosj@slac.stanford.edu"
    }
    
    struct Addresses {
        static let importURL = URL(string: "https://www.slac.stanford.edu/~xiaosj/scanner/dosimeters_last-period.csv")
        static let localDirectory = "dosimeter-manager/"
        static let backupDirectory = "dosimeter-manager/backup"
    }
    
    func exportToCSV(areaMonitors: [NSManagedObject]) throws -> (URL, String) {
        func areaMonitorToString(areaMonitor: NSManagedObject) throws -> String {
//            guard let isModified = areaMonitor.value(forKey: DataProperty.modified) as? Bool else {
//                print("Fatal error: Data is corrupted")
//                throw exportError.corruptData
//            }
            //if (!isModified) {
            //    throw exportError.unmodified
            //}
            let normalPropertyKeys = [DataProperty.facility, DataProperty.tag, DataProperty.location, DataProperty.oldCode,
                                      DataProperty.placementDate, DataProperty.pickupDate, DataProperty.newCode]
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
//            dateFormatter.setLocalizedDateFormatFromTemplate("dd-MMM-yy")
            dateFormatter.dateFormat = "dd-MMM-yy"
            var properties = normalPropertyKeys.map({ (key: String) -> String in
                let property = areaMonitor.value(forKey: key)
                if (property == nil) {
                    return DataProperty.placeholder
                }
                if (key == DataProperty.pickupDate || key == DataProperty.placementDate) {
                    let dateProperty = property as! Date
                    return dateFormatter.string(from: dateProperty)
                }
                else if (key == DataProperty.location) {
                    let locationProperty = property as! String
                    return "\"\(locationProperty)\""
                }
                let value = areaMonitor.value(forKey: key) as? String ?? DataProperty.placeholder
                if (value == "") {
                    return " "
                }
                return value
            })
            let facility = properties[0]
            let facilityNumber = areaMonitor.value(forKey: DataProperty.facilityNumber) as? String
            if (facility != DataProperty.placeholder && facilityNumber != nil && facilityNumber != DataProperty.placeholder) {
                properties[0] += " " + facilityNumber!
            }
            var line = properties.reduce("", {$0 + "," + $1}) + "\n"
            line.remove(at: line.startIndex)
            return line
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "dd-MM-yy_HH-mm-ss"
        let fileName = "monitors_" + dateFormatter.string(from: Date()) + ".csv"
        guard let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unknown Path")
            throw exportError.unknownPath
        }
        let path = documentPath.appendingPathComponent(fileName)
        let fileContents: String = try areaMonitors.map(areaMonitorToString).reduce(Templates.exportFields, {$0 + $1})
        try fileContents.write(to: path, atomically: true, encoding: .utf8)
        return (path, fileName)
    }
    
    func backupData() {
        do {
            let areaMonitors = try query(withKVPs: nil, fetchRetired: true)
            let (urlToBackup, fileName) = try exportToCSV(areaMonitors: areaMonitors)
            try writeBackup(target: urlToBackup, fileName: fileName)
        } catch exportError.unmodified {
            generateMessage(title: "Error", message: "The file you try trying to export is unmodified since the last export",
                            continueMsg: "Continue", continueAction: nil)
        } catch let error as NSError {
            print("\(error), \(error.userInfo)")
        }
    }
    
    func writeBackup(target: URL, fileName: String) throws {
        let fileManager = FileManager.default
        guard let documentPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let backupPath = documentPath.appendingPathComponent(Addresses.backupDirectory)
        try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true, attributes: nil)
        try fileManager.moveItem(at: target, to: backupPath.appendingPathComponent(fileName))
    }

    func sendEmail(to recipients: [String], subject: String?, body: String?, attachmentHandle: String?, attachmentData: Data?) {
        if (!MFMailComposeViewController.canSendMail()) {
            let alertController = UIAlertController(title: "Error", message: "Cannot send email", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        let composeVC = MFMailComposeViewController()
        composeVC.mailComposeDelegate = self
        composeVC.setToRecipients(recipients)
        if (subject == nil) {
            composeVC.setSubject("")
        } else {
            composeVC.setSubject(subject!)
        }
        if (body == nil) {
            composeVC.setMessageBody("", isHTML: false)
        } else {
            composeVC.setMessageBody(body!, isHTML: false)
        }
        if (attachmentData != nil) {
            var attachmentHandle = attachmentHandle
            if (attachmentHandle == nil) {
                attachmentHandle = "monitor.csv"
            }
            composeVC.addAttachmentData(attachmentData!, mimeType: "text/csv", fileName: attachmentHandle!)
        }
        self.present(composeVC, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        switch (result) {
        case .cancelled:
            print("Cancelled")
        case .failed:
            print("Failed")
        case .saved:
            print("Saved")
        case .sent:
            print("Sent")
        }
        controller.dismiss(animated: true, completion: nil)
    }
    
    func exportData() {
        do {
            let exportData = try query(withKVPs: nil, fetchRetired: true)
            let (fileURL, fileName) = try exportToCSV(areaMonitors: exportData)
            try writeBackup(target: fileURL, fileName: fileName)
            let fileData = NSData(contentsOf: fileURL)
            sendEmail(to: [Remote.email], subject: "test", body: "test", attachmentHandle: nil, attachmentData: fileData as Data?)
        } catch exportError.unmodified {
            generateMessage(title: "Error", message: "The file you try trying to export is unmodified since the last export",
                            continueMsg: "Continue", continueAction: nil)
        } catch let error as NSError {
            print("\(error), \(error.userInfo)")
            return
        }
    }
    
    func purgeCoreData() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: EntityNames.areaMonitor)
        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedContext.execute(request)
            try managedContext.save()
        } catch {
            print("Error deleting core data")
        }
    }
    
    func setDeleteDate() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        do {
            let managedContext = appDelegate.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: EntityNames.period)
            let periodContainer = try managedContext.fetch(fetchRequest)
            if(periodContainer.count > 1) {
                print("Error: more than one period is present")
                return
            }
            if(periodContainer.count < 1) {
                let coreDataEntity = NSEntityDescription.entity(forEntityName: EntityNames.period, in: managedContext)!
                let period = NSManagedObject(entity: coreDataEntity, insertInto: managedContext)
                try replaceDeleteDate(period)
            }
            else {
                let period = periodContainer[0] as! NSManagedObject
                if (validDeleteDate(period)) {
                try replaceDeleteDate(period)
                }
            }
        } catch {
            print("An error occured while trying to set the delete date")
            return
        }
    }
    
    func validDeleteDate(_ period: NSManagedObject) -> Bool {
        guard let previousDeleteDate = period.value(forKey: DataProperty.deleteDate) as? Date else {
            print("No date associated with period")
            return false
        }
        let currentDate = Date()
        let months = Calendar.current.dateComponents([.month], from: previousDeleteDate, to: currentDate).month
        return months! > 2
    }
    
    func replaceDeleteDate(_ period: NSManagedObject) throws {
        guard let managedContext = period.managedObjectContext else {
            return
        }
        period.setValue(Date(), forKeyPath: DataProperty.deleteDate)
        try managedContext.save()
    }
}
