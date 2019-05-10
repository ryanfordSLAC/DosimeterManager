//
//  SessionController.swift
//  dosimeter-manager
//
//  Created by Admin on 7/19/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import CoreData

class SessionController: QueryModeVC, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var noDataLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var facilityPicker: UIPickerView!
    let pickerComponents = 2
    var session: Session?
    var facilities: [String] = []
    var facilityNumbers: [[String]] = []
    var selectedFacility: Int = 0
    var selectedFacilityNumber: Int = 0
    var noData = false
    
    struct facilityComponents {
        static let facility: Int = 0
        static let facilityNumber: Int = 1
    }
    
    struct Segues {
        static let sessionToReader: String = "SessionToReader"
        static let sessionToDisplay: String = "SessionToDisplay"
        static let sessionToMain: String = "SessionToMain"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        if (self.facilities.count > 0) {
            return
        }
        do {
            let areaMonitors = try query()
            if (areaMonitors.count == 0) {
                facilityPicker.isHidden = true
                noDataLabel.isHidden = false
                button.setTitle("Go Back", for: .normal)
                self.noData = true
                return
            }
            (self.facilities, self.facilityNumbers) = getUniqueFacilities(from: areaMonitors)
        } catch {
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
        case Segues.sessionToReader:
            guard let destinationController = segue.destination as? BarcodeReaderVC else {
                return
            }
            destinationController.session = self.session
        case Segues.sessionToDisplay:
            guard let destinationController = segue.destination as? SessionDisplayVC else {
                return
            }
            destinationController.session = self.session
            destinationController.currentMode = self.currentMode
            destinationController.newEntity = self.newEntity
        default:
            return
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return self.pickerComponents
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch (component) {
        case facilityComponents.facility:
            return facilities.count
        case facilityComponents.facilityNumber:
            if (self.facilityNumbers.count == 0) {
                return 0
            }
            return self.facilityNumbers[self.selectedFacility].count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch (component) {
        case facilityComponents.facility:
            return self.facilities[row]
        case facilityComponents.facilityNumber:
            return self.facilityNumbers[self.selectedFacility][row]
        default:
            return ""
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch (component) {
        case facilityComponents.facility:
            self.selectedFacility = row
            self.facilityPicker.reloadComponent(facilityComponents.facilityNumber)
        case facilityComponents.facilityNumber:
            self.selectedFacilityNumber  = row
        default:
            return
        }
    }
        
    @IBAction func didPressSubmit(_ sender: Any) {
        if (noData) {
            performSegue(withIdentifier: Segues.sessionToMain, sender: self)
            return
        }
        let facility: String = self.facilities[self.selectedFacility]
        let facilityNumber: String = self.facilityNumbers[self.selectedFacility][self.selectedFacilityNumber]
        
        self.session = Session(forFacility: facility, withNumber: facilityNumber)
    
        switch (self.currentMode) {
        case .normal:
            performSegue(withIdentifier: Segues.sessionToReader, sender: self)
        case .recovery:
            self.newEntity[DataProperty.facility] = facility
            self.newEntity[DataProperty.facilityNumber] = facilityNumber
            performSegue(withIdentifier: Segues.sessionToDisplay, sender: self)
        case .error:
            break
        }
    }
}
