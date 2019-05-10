//
//  ReaderVC.swift
//  dosimeter-manager
//
//  Created by Admin on 7/10/17.
//  Copyright © 2017 Guthrie Price. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData

class BarcodeReaderVC: QueryModeVC, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var whatsLeftButton: UIButton!
    @IBOutlet weak var flashlightButton: UIButton!
    var session: Session?
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var captureSessionPaused: Bool = false
    var currentReaderMode: ReaderMode = .verify
    var scannedBarcode: String?
    var areaMonitor: NSManagedObject?
    lazy var conflictedMonitors: [NSManagedObject] = []
    var currentStatus: String = ""
    var flashlightIsOn: Bool = false
    
    enum ReaderMode {
        case verify
        case replace
    }
    
    struct Messages {
        static let verifyMessage: String = "Please scan old barcode"
        static let replaceMessage: String = "Please scan new barcode"
    }
    
    struct Segues {
        static let readerToList: String = "ReaderToList"
        static let readerToVerify: String = "ReaderToVerify"
        static let readerToExchange: String = "ReaderToExchange"
        static let readerToRecovery: String = "ReaderToRecovery"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            if (captureSession == nil) {
                print("Setting up capture session")
                NotificationCenter.default.addObserver(self,
                                               selector: #selector(BarcodeReaderVC.formatNotification),
                                               name: NSNotification.Name.AVCaptureInputPortFormatDescriptionDidChange,
                                               object: nil)
                try setupCaptureSession()
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                videoPreviewLayer?.frame = view.layer.bounds
                view.layer.addSublayer(videoPreviewLayer!)
                view.bringSubview(toFront: messageLabel)
                view.bringSubview(toFront: whatsLeftButton)
                view.bringSubview(toFront: flashlightButton)
            }
        }

        // For now just handle the error simply for debugging purposes
        // TODO: Alert user how to fix the problem (needs research)
        catch {
            print(error)
            return
        }
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.captureSessionPaused = false
        self.title = "Barcode Reader"
        switch(self.currentReaderMode) {
        case .verify:
            self.messageLabel.text = Messages.verifyMessage
        case .replace:
            self.messageLabel.text = Messages.replaceMessage
        }
        captureSession?.startRunning()
        self.toggleTorch(on: self.flashlightIsOn)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifer = segue.identifier else {
            return
        }
        switch (identifer) {
        case Segues.readerToList:
            guard let destinationController = segue.destination as? SessionDisplayVC else {
                return
            }
            destinationController.session = self.session
            destinationController.currentMode = self.currentMode
            if (self.currentMode == .error) {
                destinationController.areaMonitors = self.conflictedMonitors
            }
        case Segues.readerToVerify:
            guard let destinationController = segue.destination as? MonitorVerifyVC,
                 let areaMonitor = sender as? NSManagedObject else {
                return
            }
            if (self.session == nil) {
                guard let facility = areaMonitor.value(forKey: DataProperty.facility) as? String,
                     let facilityNumber = areaMonitor.value(forKey: DataProperty.facilityNumber) as? String else {
                        return
                }
                self.session = Session(forFacility: facility, withNumber: facilityNumber)
            }
            guard let status = areaMonitor.value(forKey: DataProperty.status) as? String else {
                return
            }
            if (self.currentMode == .recovery) {
                let tag = areaMonitor.value(forKey: DataProperty.tag) as? String ?? DataProperty.placeholder
                self.newEntity[DataProperty.oldCode] = self.scannedBarcode
                self.newEntity[DataProperty.facility] = (areaMonitor.value(forKey: DataProperty.facility) as! String)
                self.newEntity[DataProperty.facilityNumber] = (areaMonitor.value(forKey: DataProperty.facilityNumber) as! String)
                self.newEntity[DataProperty.tag] = tag
            }
            self.currentStatus = status
            destinationController.areaMonitor = areaMonitor
            destinationController.newEntity = self.newEntity
            destinationController.currentMode = self.currentMode
        case Segues.readerToExchange:
            guard let destinationController = segue.destination as? MonitorExchangeVC else {
                return
            }
            destinationController.currentStatus = self.currentStatus
            destinationController.scannedBarcode = self.scannedBarcode!
            destinationController.areaMonitor = self.areaMonitor!
            destinationController.newEntity = self.newEntity
            destinationController.currentMode = self.currentMode
        case Segues.readerToRecovery:
            guard let destinationController = segue.destination as? SessionController else {
                return
            }
            destinationController.newEntity[DataProperty.oldCode] = self.scannedBarcode!
            destinationController.currentMode = .recovery
        default:
            return
        }
    }
    
    func setupCaptureSession() throws {
        // Attempts to setup the capture session and settings
        
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        // TODO: The settings configuration should be more robust and work for
        //       multiple devices. Right now it has only been tested on the
        //       iPhone 6s Plus (needs research)
        try captureDevice?.lockForConfiguration()
        captureDevice?.focusMode = .continuousAutoFocus
        captureDevice?.videoZoomFactor = (captureDevice?.activeFormat.videoMaxZoomFactor)!
        captureDevice?.unlockForConfiguration()
        captureSession = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: captureDevice)
        captureSession?.addInput(input)
        let output = AVCaptureMetadataOutput()
        captureSession?.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeDataMatrixCode]
        
    }
    
    func formatNotification() {
        guard let output = captureSession?.outputs[0] as? AVCaptureMetadataOutput else {
            print("Output capture session is incorrect")
            return
        }
        guard let videoPreviewLayer = self.videoPreviewLayer else {
            print("Video preview layer is not accessible")
            return
        }
        let scanRect = CGRect(x: self.view.frame.width / CGFloat(6),
                            y: self.view.frame.height / CGFloat(3),
                            width: self.view.frame.width / CGFloat(1.5),
                            height: 80)
        output.rectOfInterest = videoPreviewLayer.metadataOutputRectOfInterest(for: scanRect)
        let scanView = UIView()
        scanView.layer.borderColor = UIColor.green.cgColor
        scanView.layer.borderWidth = 2
        scanView.frame = scanRect
        view.addSubview(scanView)
        view.bringSubview(toFront: scanView)
    }
    
    func pauseCaptureSession() {
        self.captureSessionPaused = true
    }
    
    func unpauseCaptureSession() {
        self.captureSessionPaused = false
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                      didOutputMetadataObjects metadataObjects: [Any]!,
                      from connection: AVCaptureConnection!) {
        // Handles what should be done when a barcode is read
        if (self.captureSessionPaused) {
            return
        }
        
        if (metadataObjects == nil || metadataObjects.count == 0) {
            messageLabel.text = "No barcode is detected"
            return
        }
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if (metadataObj.type == AVMetadataObjectTypeDataMatrixCode ||
            metadataObj.type == AVMetadataObjectTypeCode128Code) {
            self.pauseCaptureSession()
            if (self.scannedBarcode == metadataObj.stringValue) {
                generateWarning(title: "Warning",
                        message: "You are trying to replace the old area monitor with the same area monitor",
                        continueMsg: nil, cancelMsg: "Rescan", continueAction: nil,
                        cancelAction: {action in
                        self.unpauseCaptureSession()
                })
                return
            }
            self.scannedBarcode = metadataObj.stringValue
            switch (self.currentReaderMode) {
            case .verify:
                verifyBarcode()
            case .replace:
                replaceBarcode()
            }
        }
    }
    
    func verifyBarcode() {
        do {
            let areaMonitors: [NSManagedObject] = try query(withKey: DataProperty.oldCode, withValue: self.scannedBarcode)
            let newAreaMonitors: [NSManagedObject] = try query(withKey: DataProperty.newCode, withValue: self.scannedBarcode)
            if (areaMonitors.count + newAreaMonitors.count > 1) {
                // TODO: Flag all conflicts
                generateWarning(title: "Error",
                    message: "The scanned barcode: \(self.scannedBarcode!) was found in multiple locations.",
                    continueMsg: "Flag Monitors", cancelMsg: "Rescan",
                    continueAction: {action in
                        self.currentMode = .error
                        self.conflictedMonitors = areaMonitors + newAreaMonitors
                        self.performSegue(withIdentifier: Segues.readerToList, sender: self)},
                    cancelAction: rescan)
                return
            }
            if (!newAreaMonitors.isEmpty) {
                generateWarning(title: "Warning",
                    message: "This area monitor is marked as new, are you sure you want to replace it?",
                    continueMsg: "Replace Anyway", cancelMsg: "Rescan",
                    continueAction: {action in
                        self.currentMode = .recovery
                        self.performSegue(withIdentifier: Segues.readerToVerify, sender: newAreaMonitors[0])
                    },
                    cancelAction: rescan)
                return
            }

            if (areaMonitors.isEmpty) {
                // No old area monitor found with this barcode
                generateWarning(title: "Warning",
                    message: "The scanned barcode: \(self.scannedBarcode!) was not found in the system, what do you want to do?",
                    continueMsg: "Pick Location", cancelMsg: "Rescan",
                    continueAction: {action in
                        self.performSegue(withIdentifier: Segues.readerToRecovery, sender: self)
                    },
                    cancelAction: rescan)
                return
            }
            let areaMonitor = areaMonitors[0]
            guard let status = areaMonitor.value(forKey: DataProperty.status) as? String else {
                return
            }
            if (status != Status.unrecovered) {
                generateWarning(title: "Warning",
                    message: "This area monitor has already been marked as replaced, are you sure you want to replace it?",
                    continueMsg: "Replace Anyway", cancelMsg: "Rescan",
                    continueAction: {action in
                        self.performSegue(withIdentifier: Segues.readerToVerify, sender: areaMonitors[0])
                    },
                    cancelAction: rescan)
                return
            }
            performSegue(withIdentifier: Segues.readerToVerify, sender: areaMonitors[0])
        } catch {
            print("Error: Query to database was unsuccessful")
            return
        }
    }
    
    
    
    func rescan(_: UIAlertAction) -> Void {
        self.scannedBarcode = ""
        self.unpauseCaptureSession()
    }
    
    func replaceBarcode() {
        guard let areaMonitor = self.areaMonitor else {
            print("Error: No areamonitor to replace")
            return
        }
        guard let _ = areaMonitor.managedObjectContext else {
            print("Error: No managed context for areamonitor")
            return
        }
        performSegue(withIdentifier: Segues.readerToExchange, sender: self)
    }
    
    func setReplaceMode(controller: QueryModeVC) {
        self.newEntity = controller.newEntity
        self.currentReaderMode = .replace
        self.messageLabel.text = Messages.replaceMessage
        self.currentMode = controller.currentMode
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else {
            return
        }
        do {
            try device.lockForConfiguration()
            if (on) {
                device.torchMode = .on
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch is currently being used by another application")
            return
        }
    }
    
    func resetState() {
        self.currentMode = .normal
        self.currentReaderMode = .verify
        self.messageLabel.text = Messages.verifyMessage
        self.newEntity = [:]
        self.scannedBarcode = ""
    }
    
    @IBAction func didPressWhatsLeftButton(_ sender: Any) {
        performSegue(withIdentifier: Segues.readerToList, sender: self)
    }
    
    @IBAction func didPressFlashlightButton(_ sender: Any) {
        if (self.flashlightIsOn) {
            self.flashlightButton.backgroundColor = Colors.salmon
        } else {
            self.flashlightButton.backgroundColor = Colors.blue
        }
        self.flashlightIsOn = !self.flashlightIsOn
        self.toggleTorch(on: self.flashlightIsOn)
    }
    
    @IBAction func didPressGoBackUnwindToBarcode(sender: UIStoryboardSegue) {
        return
    }
    
    @IBAction func didPressConfirmUnwind(sender: UIStoryboardSegue) {
        guard let sourceController = sender.source as? MonitorVerifyVC else {
            return
        }
        setReplaceMode(controller: sourceController)
        self.areaMonitor = sourceController.areaMonitor
        self.currentStatus = Status.recovered
        self.unpauseCaptureSession()
    }
    
    @IBAction func didPressFlagUnwind(sender: UIStoryboardSegue) {
        guard let sourceController = sender.source as? MonitorVerifyVC else {
            return
        }
        setReplaceMode(controller: sourceController)
        self.areaMonitor = sourceController.areaMonitor
        self.currentStatus = Status.flagged
        self.unpauseCaptureSession()
    }
    
    @IBAction func didPressCompleteUnwind(sender: UIStoryboardSegue) {
        guard let sourceController = sender.source as? MonitorExchangeVC else {
            print("Couldn't unwind from exchange")
            return
        }
        do {
            let areaMonitor = self.areaMonitor!
            let scannedBarcode = sourceController.scannedBarcode
            let currentDate = sourceController.currentDate!
            areaMonitor.setValue(scannedBarcode, forKey: DataProperty.newCode)
            areaMonitor.setValue(currentDate, forKey: DataProperty.pickupDate)
            areaMonitor.setValue(self.currentStatus, forKey: DataProperty.status)
            if (self.currentMode == .recovery) {
                areaMonitor.setValue(self.newEntity[DataProperty.oldCode], forKey: DataProperty.oldCode)
                areaMonitor.setValue(self.newEntity[DataProperty.facility], forKey: DataProperty.facility)
                areaMonitor.setValue(self.newEntity[DataProperty.facilityNumber], forKey: DataProperty.facilityNumber)
                areaMonitor.setValue(self.newEntity[DataProperty.tag], forKey: DataProperty.tag)
            }
            try self.saveMonitor(areaMonitor: areaMonitor)
            self.resetState()
            self.unpauseCaptureSession()
        } catch {
            print("Couldn't save areamonitor exchange")
            return
        }
    }
    
    @IBAction func didPressCancelUnwind(sender: UIStoryboardSegue) {
        return
    }
    
    @IBAction func didPressUnknownLocationButtonUnwind(sender: UIStoryboardSegue) {
        guard let sourceController = sender.source as? SessionDisplayVC else {
            return
        }
        self.currentStatus = Status.flagged
        self.setReplaceMode(controller: sourceController)
        self.unpauseCaptureSession()
    }
    
    @IBAction func didPressResetUnwind(sender: UIStoryboardSegue) {
        self.resetState()
        self.unpauseCaptureSession()
    }

}
