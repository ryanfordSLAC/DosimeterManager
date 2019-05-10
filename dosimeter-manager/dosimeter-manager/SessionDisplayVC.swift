//
//  SessionDisplayVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/20/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData

class SessionDisplayVC: QueryModeVC {
    
    @IBOutlet weak var errorButton: UIButton!
    @IBOutlet weak var descriptionDisplay: UITableView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var monitorView: UITableView!
    var session: Session?
    var areaMonitors: [NSManagedObject] = []
    
    struct Segues {
        static let listToInfo = "ListToInfo"
        static let listToVerify = "ListToVerify"
        static let unknownUnwind = "UnknownUnwind"
        static let resetUnwind = "ResetUnwind"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionDisplay.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.navigationController!.navigationBar.topItem!.title = "Back"
        if (self.currentMode == .error) {
            self.errorButton.setTitle("Flag All", for: .normal)
            areaMonitors = areaMonitors.sorted(by: monitorComparator)
            return
        }
        guard let session = self.session else {
            self.disableErrorButton()
            return
        }
        guard let facility = session.facility, let facilityNumber = session.facilityNumber else {
            print("Malformed session detected")
            return
        }
        if (facilityNumber == DataProperty.placeholder) {
            self.title = "Area monitors for \(facility.uppercased())"
        }
        else {
            self.title = "Area monitors for \(facility.uppercased()) \(facilityNumber)"
        }
        do {
            switch (self.currentMode) {
            case .normal:
                self.disableErrorButton()
                areaMonitors = try query(withKVPs: [(DataProperty.facility, facility),
                                                (DataProperty.facilityNumber, facilityNumber)])
            case .recovery:
                areaMonitors = try query(withKVPs: [(DataProperty.facility, facility),
                                                (DataProperty.facilityNumber, facilityNumber)], fetchRetired: true)
            default:
                break
            }
            areaMonitors = areaMonitors.sorted(by: monitorComparator)
        } catch {
            print("Error displaying session")
            return
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch (identifier) {
        case Segues.listToInfo:
            guard let destinationController = segue.destination as? MonitorInfoVC else {
                return
            }
            guard let areaMonitor = sender as? NSManagedObject else {
                print("Couldn't get sender from SessionDisplayVC")
                return
            }
            destinationController.areaMonitor = areaMonitor
            destinationController.currentMode = self.currentMode
        case Segues.listToVerify:
            guard let destinationController = segue.destination as? MonitorVerifyVC else {
                return
            }
            guard let areaMonitor = sender as? NSManagedObject else {
                return
            }
            guard let location = areaMonitor.value(forKey: DataProperty.location) as? String else {
                return
            }
            var tag = areaMonitor.value(forKey: DataProperty.tag) as? String
            if (tag == nil) {
                tag = ""
            }
            self.newEntity[DataProperty.location] = location
            self.newEntity[DataProperty.tag] = tag!
            destinationController.areaMonitor = areaMonitor
            destinationController.newEntity = self.newEntity
            destinationController.currentMode = self.currentMode
        case Segues.unknownUnwind:
            guard let destinationController = segue.destination as? BarcodeReaderVC,
                 let areaMonitor = sender as? NSManagedObject else {
                return
            }
            destinationController.areaMonitor = areaMonitor
            destinationController.newEntity = self.newEntity
        default:
            return
        }
    }
    
    func disableErrorButton() {
        self.errorButton.isHidden = true
        self.errorButton.isUserInteractionEnabled = false
        self.errorButton.frame.size.height = 0
        self.heightConstraint.constant = CGFloat(0)
    }
    
    @IBAction func didPressErrorButton(_ sender: UIButton) {
        switch (self.currentMode) {
        case .recovery:
            self.newEntity[DataProperty.facility] = DataProperty.placeholder
            self.newEntity[DataProperty.facilityNumber] = DataProperty.placeholder
            self.newEntity[DataProperty.tag] = DataProperty.placeholder
            self.newEntity[DataProperty.location] = DataProperty.placeholder
            self.newEntity[DataProperty.status] = Status.flagged
            do {
                let areaMonitor = try self.addEntity(entity: self.newEntity)
                generateWarning(title: "Flagged Successfully", message: "The area monitor has been flagged successfully. How do you want to proceed?",
                        continueMsg: "Replace this monitor", cancelMsg: "Replace a different monitor",
                        continueAction: {action in
                            self.performSegue(withIdentifier: Segues.unknownUnwind, sender: areaMonitor)
                        },
                        cancelAction: {action in
                            self.performSegue(withIdentifier: Segues.resetUnwind, sender: nil)
                        })
            } catch {
                return
            }
        case .error:
            var statusTracker: [String] = []
            var isModifiedTracker: [Bool] = []
            guard let managedContext = areaMonitors[0].managedObjectContext else {
                return
            }
            do {
                // TODO: Re-engineer this code to fit with the interface provided by QueryVC
                for areaMonitor in areaMonitors {
                    let status = areaMonitor.value(forKey: DataProperty.status) as? String ?? Status.flagged
                    let isModified = areaMonitor.value(forKey: DataProperty.modified) as? Bool ?? true
                    statusTracker.append(status)
                    isModifiedTracker.append(isModified)
                    areaMonitor.setValue(Status.flagged, forKey: DataProperty.status)
                    areaMonitor.setValue(true, forKey: DataProperty.modified)
                }
                try managedContext.save()
                generateMessage(title: "Monitors have been Flagged", message: "All the monitors have been successfully flagged.",
                        continueMsg: "Okay",
                        continueAction: {action in
                            self.performSegue(withIdentifier: Segues.resetUnwind, sender: nil)
                        })
            } catch {
                for (i, areaMonitor) in areaMonitors.enumerated() {
                    areaMonitor.setValue(statusTracker[i], forKey: DataProperty.status)
                    areaMonitor.setValue(isModifiedTracker[i], forKey: DataProperty.modified)
                }
                return
            }
        default:
            break
        }
    }
    
    @IBAction func didPressButtonUnwind(sender: UIStoryboardSegue) {
        self.monitorView.reloadData()
        return
    }
}

extension SessionDisplayVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.areaMonitors.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        return cell
    }
}

extension SessionDisplayVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let areaMonitor = self.areaMonitors[indexPath.row]
        switch (self.currentMode) {
        case .normal, .error:
            performSegue(withIdentifier: Segues.listToInfo, sender: areaMonitor)
        case .recovery:
            performSegue(withIdentifier: Segues.listToVerify, sender: areaMonitor)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let areaMonitor = self.areaMonitors[indexPath.row]
        let description: String = areaMonitor.value(forKeyPath: DataProperty.location) as? String ?? DataProperty.placeholder
        let status: String = areaMonitor.value(forKey: DataProperty.status) as? String ?? Status.flagged
        let tag: String? = areaMonitor.value(forKey: DataProperty.tag) as? String ?? DataProperty.placeholder
        if (tag == DataProperty.placeholder) {
            cell.textLabel?.text = "\(description)"
        }
        else {
            cell.textLabel?.text = "\(tag!) \(description)"
        }
        cell.textLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.backgroundColor = UIColor.white.withAlphaComponent(0)
        switch (status) {
        case Status.flagged:
            cell.backgroundColor = UIColor.yellow.withAlphaComponent(0.5)
        case Status.recovered:
            cell.backgroundColor = UIColor.green.withAlphaComponent(0.5)
        case Status.retired:
            cell.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        default:
            cell.backgroundColor = UIColor.white
        }
    }
}
