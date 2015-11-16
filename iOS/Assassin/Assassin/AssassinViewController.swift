//
//  AssassinViewController.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreBluetooth
import RxSwift
import RxCocoa

class AssassinViewController: UIViewController {

    @IBOutlet weak var assassinTime: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var weaponLoadLabel: UILabel!
    @IBOutlet weak var weaponReloadButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    var assassinViewModel: AssassinViewModel!
    var socket: SocketIOClient!
    let locationManager = CLLocationManager()
    var victimMapAnnotations: [String: VictimMapAnnotation] = [String: VictimMapAnnotation]()
    var bleCentralManager: CBCentralManager!
    var blePeripherals: [String: CBPeripheral] = [String: CBPeripheral]()
    var huntingTimer: NSTimer!
    var huntingTime: Int = 120

    override func viewDidLoad() {
        super.viewDidLoad()
        self.initViews()
        self.setupSocketIO()
        self.setupLocationManager()
        self.setupBluetooth()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func initViews() {
        self.mapView.delegate = self
        self.mapView.showsPointsOfInterest = true
        
        // debug
        //self.weaponReloadButton.enabled = true

        self.weaponReloadButton.rx_tap.subscribeNext({ _ in
            
            let alert: UIAlertController = UIAlertController(title: "Reload Weapon", message: "Pair with a bluetooth device to reload the weapon", preferredStyle: UIAlertControllerStyle.ActionSheet)
            for (k, v) in self.blePeripherals {
                let action = UIAlertAction(title: k, style: UIAlertActionStyle.Default, handler: { alert in
                    self.bleCentralManager.connectPeripheral(v, options: nil)
                    print("connecting \(k)")
                })
                alert.addAction(action)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: {
                (alert: UIAlertAction) in
            })
            alert.addAction(cancelAction)
            self.presentViewController(alert, animated: true, completion: nil)
            
        }).addDisposableTo(self.disposeBag)
        
        // hunting timer
        self.huntingTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "timerUpdate:", userInfo: "", repeats: true)
    }
    
    func timerUpdate(sender: NSTimer) {
        self.huntingTime -= 1
        self.assassinTime.text = "\(self.huntingTime)"
        if self.huntingTime <= 0 {
            sender.invalidate()

            let alert = UIAlertController(title: "Game Over", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
            let okAction = UIAlertAction(title: "Sure", style: UIAlertActionStyle.Default, handler: {(alert: UIAlertAction!) in
                
                self.socket.disconnect()
                
                let window = UIApplication.sharedApplication().windows.first
                window!.rootViewController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("VictimVC")
                
            })
            
            alert.addAction(okAction)
            self.presentViewController(alert, animated: true, completion:{})
        }
    }

    func setupSocketIO() {
        self.socket = SocketIOClient(socketURL: "46.101.187.63:3001", options: [.Log(true), .ForcePolling(true)])
        
        self.socket.on("connect", callback: { data, ack in
            
            let model = Killer(socketId: self.socket.sid!)
            self.assassinViewModel = AssassinViewModel(model: model)
            
            self.assassinViewModel.currentWeaponLoad.map({
                "\($0)"
            }).bindTo(self.weaponLoadLabel.rx_text).addDisposableTo(self.disposeBag)
            
            self.assassinViewModel.currentWeaponLoad.subscribeNext({ load in
                
                if load == Killer.maxWeaponLoad {
                    self.weaponReloadButton.enabled = false
                } else {
                    self.weaponReloadButton.enabled = true
                }
                
            }).addDisposableTo(self.disposeBag)
        })
        
        self.socket.on("updateLocation", callback: { data, ack in
            if data.count > 0 {
                let victimSocketId = data[0]["socketId"] as! String
                let victimLat = (data[0]["lat"] as! NSString).doubleValue
                let victimLng = (data[0]["lng"] as! NSString).doubleValue
                let newLocation = CLLocation(latitude: victimLat, longitude: victimLng)
                
                if let victimMapAnnotation = self.victimMapAnnotations[victimSocketId] {
                    victimMapAnnotation.model.location.value = newLocation
                } else {
                    let victim = Victim(socketId: victimSocketId)
                    victim.location.value = newLocation
                    
                    // subscribe the damage from assassin
                    victim.hitPoints.subscribeNext({ hp in
                        
                        let newHP = max(0, hp)
                        self.socket.emit("damage", [
                            "socketId": victim.socketId,
                            "newHP": newHP
                        ])
                        
                    }).addDisposableTo(self.disposeBag)
                    
                    let victimMapAnnoation = VictimMapAnnotation(model: victim)
                    self.victimMapAnnotations[victimSocketId] = victimMapAnnoation
                    self.mapView.addAnnotation(victimMapAnnoation)
                }
                
                // notify the assassin for hunting if a victim enter the range (50 meters)
                if UIApplication.sharedApplication().applicationState != .Active {
                    if self.locationManager.location?.distanceFromLocation(newLocation) < 50 {
                        let notification = UILocalNotification()
                        notification.alertBody = "Hunting time."
                        notification.soundName = "Default"
                        UIApplication.sharedApplication().scheduleLocalNotification(notification)
                    }
                }
            }
            
        })
        
        self.socket.connect()
    }
    
    func setupLocationManager() {
        self.locationManager.requestAlwaysAuthorization()

        self.locationManager.rx_didChangeAuthorizationStatus.subscribeNext({ [weak self] status in
            switch status! {
            case CLAuthorizationStatus.AuthorizedAlways:
                self?.locationManager.startUpdatingLocation()
                if let location = self?.locationManager.location {
                    // range 50 meters
                    let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 50, 50)
                    self?.mapView.setRegion(coordinateRegion, animated: true)
                }
            default:
                break
            }
            
        }).addDisposableTo(self.disposeBag)
        
        self.locationManager.rx_didUpdateLocations.subscribeNext({ locations in
            
            if self.assassinViewModel != nil && locations.count > 0 {
                if let locationObj = self.assassinViewModel.model.location.value,

                   let newLocation = locations.first {
                    if locationObj.coordinate != newLocation.coordinate {
                        self.assassinViewModel.model.location.value = newLocation
                        self.socket.emit("updateLocation", [
                            "socketId": self.socket.sid!,
                            "lat": newLocation.coordinate.latitude,
                            "lng": newLocation.coordinate.longitude,
                            "isKiller": 1,
                        ])
                    }

                } else {

                    self.assassinViewModel.model.location.value = locations.first
                    self.socket.emit("updateLocation", [
                        "socketId": self.socket.sid!,
                        "lat": self.assassinViewModel.model.location.value!.coordinate.latitude,
                        "lng": self.assassinViewModel.model.location.value!.coordinate.longitude,
                        "isKiller": 1,
                    ])

                }
            }
            
        }).addDisposableTo(self.disposeBag)
        
        self.locationManager.startUpdatingLocation()
        if let location = self.locationManager.location {
            // range 50 meters
            let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 50, 50)
            self.mapView.setRegion(coordinateRegion, animated: true)
        }
    }
    
    func setupBluetooth() {
        self.bleCentralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }

}


extension AssassinViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        if let annotation = annotation as? VictimMapAnnotation {
            let reuseId = "victimPlace"
            var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                if annotation.model.hitPoints.value > 0 {
                    annotationView!.image = UIImage(named: "VictimAlivePin")
                } else {
                    annotationView!.image = UIImage(named: "VictimDeadPin")
                }
            } else {
                annotationView!.annotation = annotation
            }
            
            return annotationView
        }
        return nil
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        self.mapView.deselectAnnotation(view.annotation, animated: false)
        
        if self.assassinViewModel.model.weaponLoad.value <= 0 {
            return
        }
        
        guard let annotation = view.annotation as? VictimMapAnnotation else {
            return
        }
        let victim = annotation.model
        if victim.hitPoints.value <= 0 {
            return
        }
        
        guard let victimLocation = annotation.model.location.value else {
            return
        }
        
        let distance = self.locationManager.location?.distanceFromLocation(victimLocation)

        let weaponAlert: UIAlertController = UIAlertController(title: "Weapon List", message: "Choose a weapon to attack. ", preferredStyle: UIAlertControllerStyle.ActionSheet)

        let shurikenAction = UIAlertAction(title: "Shuriken (\(Shuriken.range)m)", style: UIAlertActionStyle.Default, handler: { alert in
            self.assassinViewModel.model.weapon = Shuriken()
            self.assassinViewModel.model.attack(victim)
            if victim.hitPoints.value <= 0 {
                if let av = self.mapView.viewForAnnotation(annotation) {
                    av.image = UIImage(named: "VictimDeadPin")
                }
            }
        })
        let pistolAction = UIAlertAction(title: "Pistol (\(Pistol.range)m)", style: UIAlertActionStyle.Default, handler: { alert in
            self.assassinViewModel.model.weapon = Pistol()
            self.assassinViewModel.model.attack(victim)
            if victim.hitPoints.value <= 0 {
                if let av = self.mapView.viewForAnnotation(annotation) {
                    av.image = UIImage(named: "VictimDeadPin")
                }
            }
        })
        let shotgunAction = UIAlertAction(title: "Shotgun (\(Shotgun.range)m)", style: UIAlertActionStyle.Default, handler: { alert in
            self.assassinViewModel.model.weapon = Shotgun()
            self.assassinViewModel.model.attack(victim)
            if victim.hitPoints.value <= 0 {
                if let av = self.mapView.viewForAnnotation(annotation) {
                    av.image = UIImage(named: "VictimDeadPin")
                }
            }
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: {
            (alert: UIAlertAction) in
        })
        
        if distance > Shuriken.range {
            shurikenAction.enabled = false
        }
        
        if distance > Pistol.range {
            pistolAction.enabled = false
        }
        
        if distance > Shotgun.range {
            shotgunAction.enabled = false
        }
        
        weaponAlert.addAction(shurikenAction)
        weaponAlert.addAction(pistolAction)
        weaponAlert.addAction(shotgunAction)
        weaponAlert.addAction(cancelAction)
        
        self.presentViewController(weaponAlert, animated: true, completion: nil)
    }
}

extension AssassinViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(central: CBCentralManager) {
        switch central.state {
        case CBCentralManagerState.PoweredOn:
            self.bleCentralManager.scanForPeripheralsWithServices(nil, options: nil)

        default:
            print(central.state)
            break
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if let name = peripheral.name {
            print("\(name) discovered")
            self.blePeripherals[name] = peripheral
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        if peripheral.state == CBPeripheralState.Connected {
            print("connected with \(peripheral.name)")
            if let viewModel = self.assassinViewModel {
                viewModel.model.weaponLoad.value = Killer.maxWeaponLoad
            }
        }
    }
}


