//
//  ViewController.swift
//  Zhihua Temple
//
//  Created by Jeff Majek on 8/8/17.
//  Copyright © 2017 PMA. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase
import mobileFramework

// MARK: Main Methods
class ViewController: UIViewController {
    
    @IBOutlet weak var webView: UIWebView!
    
    let iBeaconUUIDString = "f7826da6-4fa2-4e98-8024-bc5b71e0893e"
    var rangeTimer: Timer? = nil
    var batteryTimer: Timer? = nil
    let rangeInterval = 1.0     // production: 5*60
    let batteryInterval = 5.0   // production: 10*60
    let batteryChargingWarningTime = 5.0 // production: 10.0 * 60.0
    var batteryStopChargingTime: Date?
    var locationManager: CLLocationManager = CLLocationManager()
    
    private let downloadQueue = QueueController.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        CacheService.sharedInstance.purgeEnvironment(environment: Constants.cache.environment.staging, completion: {_ in})
        self.downloadQueue.reset()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.batteryStateDidChange), name: NSNotification.Name.UIDeviceBatteryStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.batteryLevelDidChange), name: NSNotification.Name.UIDeviceBatteryLevelDidChange, object: nil)
        
        rangeTimer = Timer.scheduledTimer(timeInterval: rangeInterval, target: self, selector: #selector(ViewController.rangeTimerMethod), userInfo: nil, repeats: true)
        batteryTimer = Timer.scheduledTimer(timeInterval: batteryInterval, target: self, selector: #selector(ViewController.batteryTimerMethod), userInfo: nil, repeats: true)
        rangeTimer!.fire()
        batteryTimer!.fire()
        
        //todo setupCacheMethod
        
         self.downloadQueue.delegate = self
        URLProtocol.registerClass(mobileFrameworkURLProtocol.self)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        
        print("Downloading content in viewDidAppear");
        self.startDownloadingContent();
    }
    
    func getFilesToDownloadFromDataFile(jsonObject: [String: AnyObject]) -> [URL] {
        
        var urls = [URL]()
        
        let objects = jsonObject["items"] as! [[String: Any]]
        
        for objectArray in objects {
            
            //Temple Data
            let relatedHotSpots = objectArray["field_related_hotspots"] as! [[String : Any]]
            
            for hotspot in relatedHotSpots {
                
                let header = hotspot["field_hotspot_detail_image"] as! String
                let host = URL(string: "http://dev.interactivemechanics.com/")?.appendingPathComponent(header)
                urls.append(host!)
            }
        }
        return urls
    }
    
    func startDownloadingContent() {
        
        //API call
        let jsonURL = URL(string: "http://dev.interactivemechanics.com/pma.json");
        
        // let's download some data (just an example, you would probably want to download asset data here)
        
        //self.publishDataButton?.isEnabled = false
        
        // let's make this controller our delegate so we can track progress
        
        // let's start off fresh by deleting everything in staging
        CacheService.sharedInstance.purgeEnvironment(environment: Constants.cache.environment.staging, completion: { _ in })
        
        CacheService.sharedInstance.requestData(url: jsonURL!, forceUncached: true, completion: { localPath, data in
            if data != nil {
                //let image = UIImage(data: data!)
                
                do {
                    let JSON = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: AnyObject]
                    
                    // we process the JSON file and get an array of files to download back
                    let filesToDownload = self.getFilesToDownloadFromDataFile(jsonObject: JSON)
                    print("Files to download: \(filesToDownload.count)")
                    
                    for file in filesToDownload {
                        self.downloadQueue.addItem(url: file)
                    }
                    self.downloadQueue.startDownloading()
                    
                } catch {
                    print("Error parsing")
                }

                
                DispatchQueue.main.async {
                    //self.imageView.image = image
                }
            }
        })
    }
    
    

}

// MARK: iBeacon
extension ViewController {
    
    func setupIBeacon() {
        
        guard let uuid = UUID(uuidString: iBeaconUUIDString) else {
            //println("Fatal error: \(iBeaconUUIDString) is an invalid UUID string, please amend.")
            return
        }
        
        let beaconRegion = CLBeaconRegion(
            proximityUUID: uuid,
            major: 63791,
            minor: 47809,
            identifier: "iBeacon")
        
        locationManager.startMonitoring(for: beaconRegion)
    }
    
}

// MARK: Webview
extension ViewController {
    func setupWebview() {
        self.webView.allowsInlineMediaPlayback = true;
        self.webView.mediaPlaybackRequiresUserAction = false
        
        guard let url = Bundle.main.path(forResource: "pma_index", ofType: "html", inDirectory: "pma") else {
            print("Failed to load local HTML")
            return
        }
        
        let request = URLRequest(url: URL(fileURLWithPath: url)) //URLRequest(url: url)
        self.webView.loadRequest(request)
    }
}

// MARK: Timer Methods
extension ViewController {
    @objc
    func rangeTimerMethod() {
        //print(self.webView.stringByEvaluatingJavaScript(from: "methodName"))
        
        if let batteryStopChargingTime = self.batteryStopChargingTime {
            //println("we have a 'stop charging time event' of: \(batteryStopChargingTime)")
            if ((batteryStopChargingTime.timeIntervalSinceNow * -1) >= self.batteryChargingWarningTime) {
                // fire analytics event?
                // fire JS function
               // println("device has not been charging for over \(self.batteryChargingWarningTime) seconds, fire appropriate events")
                
                //Todo add Firebase Not Charging Event
                
                // self.batteryStopChargingTime = nil
                // CDM ^^ - this will nil out this condition so we don't ever enter the greater if statement (line 44)
                // this means we will not hammer the same event over and over if the phone is unplugged or a long period.
            } else {
                //println("device has not been charging for \(batteryStopChargingTime.timeIntervalSinceNow) seconds which is under \(self.batteryChargingWarningTime)")
            }
        } else {
           // println("we don't have a 'stop charging' date, so presumably we're still charging.")
        }
    }
    
    @objc
    func batteryTimerMethod() {
        //println("batt timer firing")
        
        if (UIDevice.current.batteryState != UIDeviceBatteryState.charging) && UIDevice.current.batteryLevel < 0.15 {
            //println("battery is charging + is below 15 percent.")
            //println(self.webView.stringByEvaluatingJavaScript(from: "showBatteryModal") ?? "")
        }
    }
}

// MARK: iBeacon Callbacks
extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("DID ENTER REGION: uuid: \(beaconRegion.proximityUUID.uuidString)")
            //todo hideOutOfRangeModal -> JS Method
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("DID EXIT REGION: uuid: \(beaconRegion.proximityUUID.uuidString)")
            //Event Beacon Left Range
            //println(self.webView.stringByEvaluatingJavaScript(from: "showOutOfRangeModal") ?? "")
        }
    }
    
}

// MARK: Battery Methods
extension ViewController {
    
    @objc
    func batteryStateDidChange(notification: NSNotification) {
        //println("battery state did change notification.")
        if(UIDevice.current.batteryState == UIDeviceBatteryState.charging) {
            //Send device is charging event
           // println("event: battery is charging!")
            batteryStopChargingTime = nil
        } else if(UIDevice.current.batteryState == UIDeviceBatteryState.unplugged) {
            //println("event: battery is not charging!")
            batteryStopChargingTime = Date()
        }
    }
    
    @objc
    func batteryLevelDidChange(notification: NSNotification){
        // The battery's level did change (98%, 99%, ...)
    }
}


// MARK: Progress Bar Delegate
extension ViewController : QueueControllerDelegate {
    
    func QueueControllerDownloadInProgress(queueController: QueueController, withProgress progress: Float, tasksTotal: Int, tasksLeft: Int) {
        print("Download queue progress update: Task \(tasksLeft) of \(tasksTotal)")
        DispatchQueue.main.async {
            //self.downloadQueue?.setProgress(progress, animated: false)
        }
    }
    
    func QueueControllerDidFinishDownloading(queueController: QueueController) {
        print("Download queue finished downloading.")
        DispatchQueue.main.async {
            //self.publishDataButton?.isEnabled = true
            
            //Start Setting up the project
            self.setupWebview()
            //self.setupIBeacon()
            
        }
    }
    
    
}
