//
//  DataDisplayVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/13/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData

class DataDisplayVC: FileManagerVC {

    @IBOutlet weak var userUpdateLabel: UILabel!
    
    let fileName: String = "dosimeters_last-period.csv"
    var propertyFilter: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Attempt to load core data on startup
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Right now this dumps coredata for testing purposes
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

//    func importRemote() {
//        // Fetch the file from a static URL to download.
//        // Note that right now this is extremely unsafe because the app can access any HTML site (see Info.plist)
//        
//        let documentsUrl: URL = FileManager.default.urls(for: .documentDirectory,
//                                                   in: .userDomainMask).first as URL!
//        let destinationUrl = documentsUrl.appendingPathComponent(fileName)
//        let fileUrl = Addresses.importURL
//        let session = URLSession(configuration: URLSessionConfiguration.default)
//        let request = URLRequest(url: fileUrl!)
//        let task = session.downloadTask(with: request) {
//            (tempLocalUrl, response, error) in
//            guard let tempLocalUrl = tempLocalUrl,
//                 error == nil,
//                 let _ = (response as? HTTPURLResponse)?.statusCode else {
//                    self.updateUser(userUpdate: "Error downloading the file", completionHandler: nil)
//                    return
//            }
//
//            do {
//                try FileManager.default.moveItem(at: tempLocalUrl, to: destinationUrl)
//            } catch {
//                self.updateUser(userUpdate: "Error copying file", completionHandler: nil)
//            }
//        }
//
//        task.resume()
//    }
    
    func importRemote2() {
        self.updateUser(userUpdate: "Importing now... Please wait", completionHandler: nil)
        do {
            let areaMonitors = try self.query(withKVPs: nil, fetchRetired: true)
            if (!areaMonitors.isEmpty) {
//                self.backupData()
                self.purgeCoreData()
//                self.deleteOldData()
            }
            
            let documentsUrl: URL = FileManager.default.urls(for: .documentDirectory,
                                                             in: .userDomainMask).first as URL!
            let destinationUrl = documentsUrl.appendingPathComponent(fileName)

            let fileUrl = Addresses.importURL
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let request = URLRequest(url: fileUrl!)
            let task = session.downloadTask(with: request) {
                (tempLocalUrl, response, error) in
                guard let tempLocalUrl = tempLocalUrl,
                    error == nil,
                    let _ = (response as? HTTPURLResponse)?.statusCode else {
                        self.updateUser(userUpdate: "Error downloading the file", completionHandler: nil)
                        return
                }
                do {
                    if FileManager.default.fileExists(atPath: destinationUrl.path) {
                        do {
                            try FileManager.default.removeItem(at: destinationUrl)
                        } catch {
                            self.updateUser(userUpdate: "Error deleting old file", completionHandler: nil)
                        }
                    }
                    try FileManager.default.moveItem(at: tempLocalUrl, to: destinationUrl)
                    do {
                        let _ = try self.generateCoreData()
                    } catch {
                        self.updateUser(userUpdate: "Error generating core data", completionHandler: nil)
                        return
                    }
                    self.updateUser(userUpdate: "Data loaded successfully", completionHandler: nil)
                } catch {
                    self.updateUser(userUpdate: "Error moving file", completionHandler: nil)
                }
                
            }
            task.resume()
        } catch {
            self.updateUser(userUpdate: "Error while query area monitor data", completionHandler: nil)
        }
    }
    
 
    func deleteOldData() {
        // Removes the current old data csv file thats stored locally
        let documentsUrl: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first as URL!
        let destinationFileUrl = documentsUrl.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: destinationFileUrl)
            self.updateUser(userUpdate: "Successfully deleted file", completionHandler: nil)
        } catch {
            self.updateUser(userUpdate: "Error deleteing file", completionHandler: nil)
        }
        purgeCoreData()
    }
    
    
    
    func generateCoreData() throws -> Bool {
        // Attemps to save an old data file to core data
        //
        // :no params:
        //
        // :returns: true if successful, false if there was an error
        
        guard let oldData = self.readOldData() else {
            // TODO: Alert the user to verify that the old data has been downloaded
            self.updateUser(userUpdate: "There was an error while downloading the file, please ensure you are connected to the internet", completionHandler: nil)
            return false
        }
        var entity: [String: String] = [:]
        let formatMapping: [Int: String] = getFormat(formatLine: oldData[0])
        for line in oldData.dropFirst() {
            guard let formatLine: [String] = format(line: line) else {
                //self.updateUser(userUpdate: "The file you are trying to import is malformed")
                return false
            }
            if (formatLine[0] == "") {
                continue
            }
            for key in formatMapping.keys {
//                if (key >= formatLine.count) {
//                    continue
//                }
                entity[formatMapping[key]!] = formatLine[key]
            }
            entity[DataProperty.placementDate] = entity[DataProperty.pickupDate]
            entity[DataProperty.pickupDate] = DataProperty.placeholder
            if let facilityNumber = formatLine.last {
                entity[DataProperty.facilityNumber] = facilityNumber
            }
            let tag = formatLine[formatLine.count - 2]
            if (tag != "") {
                entity[DataProperty.tag] = tag
            }
            entity[DataProperty.status] = Status.unrecovered
            // TODO: Finding if the entry is retired can probably be optimized by looking at the data
            for property in formatLine {
                if (property.uppercased() == "RETIRED" || property.uppercased() == "REMOVED") {
                    entity[DataProperty.status] = Status.retired
                    break
                }
            }
            try self.saveData(entity: entity)
        }
        self.setDeleteDate()
        return true
    }
    
    func saveData(entity: [String: String]) throws {
        // Attempts to write a single value and key to core data
        //
        // :propertyValue: The value of the property you want to save
        // :propertyKey: The key of the property you want to save
        //
        // :no return:
        
        // TODO: Alert the user of a fatal error
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("Couldn't get the app delegate")
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let coreDataEntity = NSEntityDescription.entity(forEntityName: EntityNames.areaMonitor, in: managedContext)!
        let areaMonitor = NSManagedObject(entity: coreDataEntity, insertInto: managedContext)

        for (propertyKey, propertyValue) in entity {
            var value: Any? = propertyValue
            if (propertyKey == DataProperty.pickupDate || propertyKey == DataProperty.placementDate) {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US")
//                dateFormatter.setLocalizedDateFormatFromTemplate("dd-MMM-yy")
                dateFormatter.dateFormat = "dd-MMM-yy"
                value = dateFormatter.date(from: propertyValue)
            }
            areaMonitor.setValue(value, forKeyPath: propertyKey)
        }
        areaMonitor.setValue(false, forKey: DataProperty.modified)
        try managedContext.save()
    }
    
    func readOldData() -> [String]? {
        // Attemps to read the old csv file at the location specified in the member variables
        //
        // :no params:
        //
        // :returns: An array of strings representing the lines of the csv file or nil if there was an error
        
        let documentsUrl: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first as URL!
        let fileUrl: URL = documentsUrl.appendingPathComponent(fileName)
        do {
            let data = try String(contentsOf: fileUrl, encoding: String.Encoding.ascii)
            return data.components(separatedBy: "\n")
        } catch {
            print("fail to read:", fileUrl)
            return nil
        }
    }
    
    func getFormat(formatLine: String) -> [Int: String] {
        // Gets the format of a csv file by reading the format line metadata
        //
        // :formatLine: A line in the csv file that gives hints of what column corresponds to what property
        //
        // :returns: A dictionary of column positions to property names
        
        var format: [Int: String] = [:]
        let fields: [String: String] = ["bldg": DataProperty.facility,
                                     "description": DataProperty.location,
                                     "placement date": DataProperty.placementDate,
                                     "pick up date": DataProperty.pickupDate,
                                     "new inlight": DataProperty.oldCode]
        
        for (i, word) in formatLine.components(separatedBy: ",").enumerated() {
            let word = word.lowercased().trimmingCharacters(in: .whitespaces)
            guard let field = fields[word] else {
                continue
            }
            format[i] = field
        }
        return format
    }
    
    func updateUser(userUpdate: String, completionHandler: (() -> Void)?) {
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.main.async {
            self.userUpdateLabel.text = userUpdate
            group.leave()
        }
        group.notify(queue: .main) {
            if (completionHandler != nil) {
                completionHandler!()
            }
        }
    }
    
    func confirmImport() {
        let alertController = UIAlertController(title: "Import Data?", message: "Existing data will be deleted. Enter the pass code to confirm or cancel.", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter Pass Code"
        }
        
        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { (_) in
            let code = alertController.textFields?[0].text
            if (code == "Do update") {
                self.importRemote2()
            } else {
                self.generateMessage(title: "Error", message: "Wrong Pass Code!", continueMsg: "Continue", continueAction: nil)
            }
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    @IBAction func didPressImportLocal(_ sender: Any) {
        // This is currently not used. Later you can use this to import data locally
    }
    
    @IBAction func didPressImportRemote(_ sender: Any) {
        confirmImport()
//        generateWarning(title: "Are you sure you want to import?",
//                    message: "Importing will overwrite the master file. Are you sure you want to import?",
//                    continueMsg: "Import Now", cancelMsg: "Cancel",
//                    continueAction: {action in self.importRemote2()},
////                        self.updateUser(userUpdate: "Importing now... Please wait") {
////                            do {
////                                let areaMonitors = try self.query(withKVPs: nil, fetchRetired: true)
////                                if (!areaMonitors.isEmpty) {
////                                    self.backupData()
////                                    self.purgeCoreData()
////                                }
////                                self.importRemote()
////                                do {
////                                    let _ = try self.generateCoreData()
////                                } catch {
////                                    self.updateUser(userUpdate: "Error writing data to the phone", completionHandler: nil)
////                                    return
////                                }
////                                self.updateUser(userUpdate: "Data loaded successfully", completionHandler: nil)
////                            } catch {
////                                self.updateUser(userUpdate: "An unknown error occured", completionHandler: nil)
////                            }
////                        }
////                    },
//                    cancelAction: {action in
//                        return
//        })
    }
}

