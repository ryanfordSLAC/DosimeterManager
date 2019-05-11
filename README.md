

![Logo](/Images/Logo.png)


# Dosimeter Manager
Version 0 of the Area Exchange App for iOS

Created by Guthrie Price

Created in Version 3.x of Swift

### Use Branch:  Swift_4_Migration for migration
- [x] Add App Icons - SLAC Logo
- [ ] Migrate to Swift 4 by revising depricated code
- [ ] Add a valid SLAC Team and Provisioning Profile
- [ ] Build and test

#### Installation

```
Open dosimeter-manager.xcodeproj in Xcode
Attach iPod Touch USB cable to Mac
Change device to device just attached
Click Play button, app will load to device
```
#### Connectivity

* The app runs locally and does not require connection to CloudKit, or the Web.   Sessions are initiated on the device, and the local file is e-mailed to the RP supervisor who combines the files into a master file.

#### Maintenance

* Periodic review of the Apple Developer console is necessary to verify the devices are registered correctly.  Prior to loading the app to a staff member's personal device, they should change their device name to something easily identifiable (e.g., RyanFord's iPhone).  This way, devices can be de-registered from the console by the administrator if necessary for security reasons.





