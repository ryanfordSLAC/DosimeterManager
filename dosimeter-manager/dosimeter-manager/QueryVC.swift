//
//  DataVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/19/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData

class QueryVC: UIViewController {
    
    var newEntity: [String: String] = [:]
    
    struct EntityNames {
        static let areaMonitor: String = "AreaMonitor"
        static let period: String = "Period"
    }
    
    enum QueryError: Error {
        case noAppDelegate
    }
    
    func query(withKey key: String?, withValue value: String?) throws -> [NSManagedObject] {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            throw QueryError.noAppDelegate
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: EntityNames.areaMonitor)
        
        if let key = key, let value = value {
            fetchRequest.predicate = NSPredicate(format: "%K like %@", key, value)
        }
        return try managedContext.fetch(fetchRequest)
    }
    
    func query(withKVPs kvps: [(String, String)]? = nil, fetchRetired: Bool = false) throws -> [NSManagedObject] {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            throw QueryError.noAppDelegate
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: EntityNames.areaMonitor)
        let notRetiredPredicate = NSPredicate(format: "NOT (%K like %@)", DataProperty.status, Status.retired)
        guard let kvps = kvps else {
            if (!fetchRetired) {
                fetchRequest.predicate = notRetiredPredicate
            }
            return try managedContext.fetch(fetchRequest)
        }
        if (kvps.count > 0) {
            var predicates: [NSPredicate] = []
            for (key, value) in kvps {
                predicates.append(NSPredicate(format: "%K like %@", key, value))
            }
            if (!fetchRetired) {
                predicates.append(notRetiredPredicate)
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else if (!fetchRetired) {
            fetchRequest.predicate = notRetiredPredicate
        }
        return try managedContext.fetch(fetchRequest)
    }
    
    func generateWarning(title: String, message: String, continueMsg: String?, cancelMsg: String?,
                         continueAction: ((UIAlertAction) -> Void)?, cancelAction: ((UIAlertAction) -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if (continueMsg != nil) {
            alertController.addAction(UIAlertAction(title: continueMsg, style: .default, handler: continueAction))
        }
        if (cancelMsg != nil) {
            alertController.addAction(UIAlertAction(title: cancelMsg, style: .cancel, handler: cancelAction))
        }
        self.present(alertController, animated: true, completion: nil)
    }
    
    func generateMessage(title: String, message: String, continueMsg: String, continueAction: ((UIAlertAction) -> Void)?) {
        generateWarning(title: title, message: message, continueMsg: nil, cancelMsg: continueMsg, continueAction: nil,
                cancelAction: continueAction)
    }
    
    func addEntity(entity: [String: String]) throws -> NSManagedObject {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            throw NSError()
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let coreDataEntity = NSEntityDescription.entity(forEntityName: EntityNames.areaMonitor, in: managedContext)!
        let areaMonitor = NSManagedObject(entity: coreDataEntity, insertInto: managedContext)
        
        for (propertyKey, propertyValue) in entity {
            var value: Any? = propertyValue
            if (propertyKey == DataProperty.pickupDate || propertyKey == DataProperty.placementDate) {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.setLocalizedDateFormatFromTemplate("dd-MMM-yy")
                value = dateFormatter.date(from: propertyValue)
            }
            areaMonitor.setValue(value, forKeyPath: propertyKey)
        }
        try saveMonitor(areaMonitor: areaMonitor)
        return areaMonitor
    }
    
    func saveMonitor(areaMonitor: NSManagedObject) throws {
        areaMonitor.setValue(true, forKey: DataProperty.modified)
        try areaMonitor.managedObjectContext?.save()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
