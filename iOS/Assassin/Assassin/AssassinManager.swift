//
//  AssassinManager.swift
//  Assassin
//
//  Created by Yuanhao Li on 23/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import MapKit
import RxSwift
import RxCocoa
import CoreLocation
import CoreBluetooth


class AssassinManager: NSObject {
    let disposeBag = DisposeBag()
    var controller: AssassinViewController
    var assassinViewModel: AssassinViewModel!
    var socketManager: SocketManager!
    var victimMapAnnotations: [String: VictimMapAnnotation] = [String: VictimMapAnnotation]()
    
    let locationManager = CLLocationManager()
    var bleCentralManager: CBCentralManager!
    var blePeripherals: [String: CBPeripheral] = [String: CBPeripheral]()
    
    var huntingTimer: NSTimer!
    var huntingTime: Int = 120
    
    init(controller: AssassinViewController) {
        self.controller = controller
        
        super.init()
        
        self.initSocketManager()
        self.initLocationManager()
        self.initBluetooth()
        self.initHuntingTimer()

    }
    
    func initHuntingTimer() {
        self.huntingTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "huntingTimerUpdate:", userInfo: "", repeats: true)
    }

    func initSocketManager() {
        let socket = SocketIOClient(socketURL: "46.101.187.63:3001", options: [.Log(true), .ForcePolling(true)])
        self.socketManager = SocketManager(socket: socket, delegate: self)
    }
    
    func notifyForHuntingIfNeeded(victionLocation: CLLocation) {
        // notify the assassin for hunting if a victim enter the range (50 meters)
        if UIApplication.sharedApplication().applicationState != .Active {
            if self.locationManager.location?.distanceFromLocation(victionLocation) < 50 {
                let notification = UILocalNotification()
                notification.alertBody = "Hunting time."
                notification.soundName = "Default"
                UIApplication.sharedApplication().scheduleLocalNotification(notification)
            }
        }
    }
    
    func initBluetooth() {
        self.bleCentralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }
    
    func initLocationManager() {
        self.locationManager.requestAlwaysAuthorization()
        
        self.locationManager.rx_didChangeAuthorizationStatus.subscribeNext({ [weak self] status in
            switch status! {
            case CLAuthorizationStatus.AuthorizedAlways:
                self?.locationManager.startUpdatingLocation()
                if let location = self?.locationManager.location {
                    // range 50 meters
                    let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 50, 50)
                    self?.controller.mapView.setRegion(coordinateRegion, animated: true)
                }
            default:
                break
            }
        }).addDisposableTo(self.disposeBag)
        
        self.locationManager.rx_didUpdateLocations.subscribeNext({ locations in
            if let viewModel = self.assassinViewModel,
               let location = locations.first {
                if let currentLocation = viewModel.model.location.value {
                    if currentLocation.coordinate != location.coordinate {
                        viewModel.model.location.value = location
                        self.socketManager.socket.emit("updateLocation", [
                            "socketId": self.socketManager.socket.sid!,
                            "lat": location.coordinate.latitude,
                            "lng": location.coordinate.longitude,
                            "isKiller": 1,
                        ])
                    }
                } else {
                    viewModel.model.location.value = location
                    self.socketManager.socket.emit("updateLocation", [
                        "socketId": self.socketManager.socket.sid!,
                        "lat": viewModel.model.location.value!.coordinate.latitude,
                        "lng": viewModel.model.location.value!.coordinate.longitude,
                        "isKiller": 1,
                    ])
                    
                    self.createMovingVictimDummy(location)
                }
            }
            
        }).addDisposableTo(self.disposeBag)
        
        self.locationManager.startUpdatingLocation()

        if let location = self.locationManager.location {
            // range 50 meters
            let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 50, 50)
            self.controller.mapView.setRegion(coordinateRegion, animated: true)
        }
    }
    
    func createMovingVictimDummy(loc: CLLocation) {
        
        let movingDummy = Victim(socketId: "movingDummy")
        movingDummy.location.value = loc
        let victimMapAnnoation = VictimMapAnnotation(model: movingDummy)
        self.victimMapAnnotations["movingDummy"] = victimMapAnnoation
        self.controller.mapView.addAnnotation(victimMapAnnoation)

    }

    func showReloadWeaponAction() {
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
        self.controller.presentViewController(alert, animated: true, completion: nil)
    }
    
    func huntingTimerUpdate(sender: NSTimer) {
        self.huntingTime -= 1
        self.controller.assassinTime.text = "\(self.huntingTime)"

        if self.huntingTime <= 0 {
            sender.invalidate()
            self.showGameOverAlert()
        }
        
        if let dummyMapAnnoation = self.victimMapAnnotations["movingDummy"] {
            let victimDummy = dummyMapAnnoation.model
            let oldLoc = victimDummy.location.value!
            var distance: Double
            var angle: Double
            if self.huntingTime / 20 % 2 == 1 {
                distance = 1
                angle = 5.0
            } else {
                distance = -1
                angle = -5.0
            }
            victimDummy.location.value = locationForAngle(angle, center: oldLoc, distance: distance)
        }
    }
    
    func showGameOverAlert() {
        let alert = UIAlertController(title: "Game Over", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        let okAction = UIAlertAction(title: "Sure", style: UIAlertActionStyle.Default, handler: {(alert: UIAlertAction!) in
            
            self.socketManager.socket.disconnect()
            
            let window = UIApplication.sharedApplication().windows.first
            window!.rootViewController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("VictimVC")
            
        })
        
        alert.addAction(okAction)
        self.controller.presentViewController(alert, animated: true, completion:{})
    }
}

extension AssassinManager: SocketManagerDelegate {
    func message(socket: SocketIOClient, onConnect data: AnyObject, ack: SocketAckEmitter?) {

        let model = Killer(socketId: socket.sid!)
        self.assassinViewModel = AssassinViewModel(model: model)

        self.assassinViewModel.currentWeaponLoad.map({
            "\($0)"
        }).bindTo(self.controller.weaponLoadLabel.rx_text).addDisposableTo(self.disposeBag)
        
        self.assassinViewModel.currentWeaponLoad.subscribeNext({ load in
            
            if load == Killer.maxWeaponLoad {
                self.controller.weaponReloadButton.enabled = false
            } else {
                self.controller.weaponReloadButton.enabled = true
            }
            
        }).addDisposableTo(self.disposeBag)
    }
    
    func message(socket: SocketIOClient, onDamage data: AnyObject, ack: SocketAckEmitter?) {}
    
    func message(socket: SocketIOClient, onUpdateLocation data: AnyObject, ack: SocketAckEmitter?) {
        if let victimSocketId = data["socketId"] as? String,
            let latNumber = data["lat"] as? NSNumber,
            let lngNumber = data["lng"] as? NSNumber {
                let victimLat = latNumber.doubleValue
                let victimLng = lngNumber.doubleValue
                let newLocation = CLLocation(latitude: victimLat, longitude: victimLng)
                
                if let victimMapAnnotation = self.victimMapAnnotations[victimSocketId] {
                    victimMapAnnotation.model.location.value = newLocation
                } else {
                    let victim = Victim(socketId: victimSocketId)
                    victim.location.value = newLocation
                    victim.hitPoints.subscribeNext({ hp in
                        
                        let newHP = max(0, hp)
                        socket.emit("damage", [
                            "socketId": victim.socketId,
                            "newHP": newHP
                        ])
                        
                    }).addDisposableTo(self.disposeBag)
                    
                    let victimMapAnnoation = VictimMapAnnotation(model: victim)
                    self.victimMapAnnotations[victimSocketId] = victimMapAnnoation
                    self.controller.mapView.addAnnotation(victimMapAnnoation)
                }
                
                self.notifyForHuntingIfNeeded(newLocation)
        }

    }
}


extension AssassinManager: CBCentralManagerDelegate {
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


extension AssassinManager: MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        if let annotation = annotation as? VictimMapAnnotation {
            let reuseId = "victimPlace"
            var annotationView = self.controller.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
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
        self.controller.mapView.deselectAnnotation(view.annotation, animated: false)
        
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
                if let av = self.controller.mapView.viewForAnnotation(annotation) {
                    av.image = UIImage(named: "VictimDeadPin")
                }
            }
        })
        let pistolAction = UIAlertAction(title: "Pistol (\(Pistol.range)m)", style: UIAlertActionStyle.Default, handler: { alert in
            self.assassinViewModel.model.weapon = Pistol()
            self.assassinViewModel.model.attack(victim)
            if victim.hitPoints.value <= 0 {
                if let av = self.controller.mapView.viewForAnnotation(annotation) {
                    av.image = UIImage(named: "VictimDeadPin")
                }
            }
        })
        let shotgunAction = UIAlertAction(title: "Shotgun (\(Shotgun.range)m)", style: UIAlertActionStyle.Default, handler: { alert in
            self.assassinViewModel.model.weapon = Shotgun()
            self.assassinViewModel.model.attack(victim)
            if victim.hitPoints.value <= 0 {
                if let av = self.controller.mapView.viewForAnnotation(annotation) {
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
        
        self.controller.presentViewController(weaponAlert, animated: true, completion: nil)
    }
}
