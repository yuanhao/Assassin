//
//  ViewController.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import CoreLocation
import AudioToolbox


class VictimViewController: UIViewController {

    @IBOutlet weak var victimStatusImage: UIImageView!
    @IBOutlet weak var victimHPLabel: UILabel!
    
    let disposeBag = DisposeBag()

    var socket: SocketIOClient!
    var victimViewModel: VictimViewModel!
    let locationManager = CLLocationManager()
    var overlayView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initViews()
        self.setupSocketIO()
        self.setupLocationManager()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func initViews() {
        self.overlayView = UIView(frame: self.view.bounds)
        self.overlayView.backgroundColor = UIColor.redColor().colorWithAlphaComponent(0.5)
        let overlayLabel = UILabel()
        overlayLabel.text = "Run!"
        overlayLabel.font = overlayLabel.font.fontWithSize(100)
        overlayLabel.textColor = UIColor.whiteColor()
        overlayLabel.sizeToFit()
        overlayLabel.frame.origin = CGPoint(x: (self.view.bounds.width - overlayLabel.frame.width) / 2.0, y: (self.view.bounds.height - overlayLabel.frame.height) / 2.0)
        self.overlayView.addSubview(overlayLabel)
    }

    func setupSocketIO() {
        self.socket = SocketIOClient(socketURL: "127.0.0.1:3001", options: [.Log(true), .ForcePolling(true)])
        self.socket.on("connect", callback: { data, ack in
            print(data)
            print(ack)
            print(self.socket.sid)
            
            // create our victim model
            let model = Victim(socketId: self.socket.sid!)
            self.victimViewModel = VictimViewModel(model: model)
            
            // connect our victim view model with our view
            self.victimViewModel.currentHPPercent.bindTo(self.victimHPLabel.rx_text).addDisposableTo(self.disposeBag)

            self.victimViewModel.aliveStatus.map({
                $0.stateImage()
            }).bindTo(self.victimStatusImage.rx_image).addDisposableTo(self.disposeBag)
            
            self.victimViewModel.aliveStatus.subscribeNext({ status in
                if status == VictimAliveStatus.DEAD {
                    let alert = UIAlertController(title: "Game Over", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
                    let okAction = UIAlertAction(title: "Sure", style: UIAlertActionStyle.Default, handler: {(alert: UIAlertAction!) in
                        
                        self.socket.disconnect()
                        
                        let window = UIApplication.sharedApplication().windows.first
                        if arc4random_uniform(2) == 0 {
                            window!.rootViewController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("VictimVC")
                        } else {
                            window!.rootViewController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("AssassinVC")
                        }
                    })
                    
                    alert.addAction(okAction)
                    self.presentViewController(alert, animated: true, completion:{})
                }
            }).addDisposableTo(self.disposeBag)
            
        })
        
        self.socket.on("damage", callback: { data, ack in
            if data.count > 0 {
                if let socketId = data[0]["socketId"] as? String {
                    let damage = (data[0]["newHP"] as! NSString).doubleValue
                    if socketId == self.socket.sid {
                        self.victimViewModel.model.hitPoints.value = damage
                        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                        
                        // red overlay view, with run on it
                        self.view.addSubview(self.overlayView)
                        // Delay 0.5 seconds
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                            // remove red overlay view
                            self.overlayView.removeFromSuperview()
                        }
                    }
                }
            }
        })
        
        /* Debug purpose
        self.socket.on("updateLocation") { data, ack in
            print(data)
            print(data[0]["socketId"])
            print("\n\n\n\n")
        }
        */
        
        self.socket.connect()
    }
    
    func setupLocationManager() {
        self.locationManager.requestAlwaysAuthorization()
        
        // update locations to the server
        self.locationManager.rx_didUpdateLocations.subscribeNext({ locations in
            
            print("rx_didUpdateLocations: \(locations)")

            if self.victimViewModel != nil && locations.count > 0 {
                if let oldLocation = self.victimViewModel.model.location.value,
                   let newLocation = locations.first {
                    if oldLocation.coordinate != newLocation.coordinate {
                        self.victimViewModel.model.location.value = newLocation
                        self.socket.emit("updateLocation", [
                            "socketId": self.socket.sid!,
                            "lat": newLocation.coordinate.latitude,
                            "lng": newLocation.coordinate.longitude,
                            "isKiller": 0,
                        ])
                    }
                } else {
                    self.victimViewModel.model.location.value = locations.first
                    self.socket.emit("updateLocation", [
                        "socketId": self.socket.sid!,
                        "lat": self.victimViewModel.model.location.value!.coordinate.latitude,
                        "lng": self.victimViewModel.model.location.value!.coordinate.longitude,
                        "isKiller": 0,
                        ])
                }
            }
            
        }).addDisposableTo(self.disposeBag)
        
        self.locationManager.rx_didChangeAuthorizationStatus.subscribeNext({ [weak self] status in
            switch status! {
            case CLAuthorizationStatus.AuthorizedAlways:
                self?.locationManager.startUpdatingLocation()
            default:
                break
            }
        }).addDisposableTo(self.disposeBag)

        self.locationManager.startUpdatingLocation()
    }
}


func != (left: CLLocationCoordinate2D, right: CLLocationCoordinate2D) -> Bool {
    return left.latitude != right.latitude || left.longitude != right.longitude
}

