//
//  VictimManager.swift
//  Assassin
//
//  Created by Yuanhao Li on 22/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//


import UIKit
import RxSwift
import RxCocoa
import CoreLocation
import AudioToolbox


class VictimManager: NSObject {
    let disposeBag = DisposeBag()
    var controller: VictimViewController
    var victimViewModel: VictimViewModel!
    var socketManager: SocketManager!
    let locationManager = CLLocationManager()
    
    init(controller: VictimViewController) {
        self.controller = controller
        
        super.init()

        self.initSocketManager()
        self.initLocationManager()        
    }
    
    func initSocketManager() {
        let socket = SocketIOClient(socketURL: "46.101.187.63:3001", options: [.Log(true), .ForcePolling(true)])
        self.socketManager = SocketManager(socket: socket, delegate: self)
    }
    
    func showGameOverAlert(socket: SocketIOClient) {
        let alert = UIAlertController(title: "Game Over", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        let okAction = UIAlertAction(title: "Sure", style: UIAlertActionStyle.Default, handler: {(alert: UIAlertAction!) in
            
            socket.disconnect()
            
            let window = UIApplication.sharedApplication().windows.first
            if arc4random_uniform(2) == 0 {
                window!.rootViewController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("VictimVC")
            } else {
                window!.rootViewController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("AssassinVC")
            }
        })
        
        alert.addAction(okAction)
        self.controller.presentViewController(alert, animated: true, completion:{})
    }
    
    func initLocationManager() {
        self.locationManager.requestAlwaysAuthorization()
        
        // update locations to the server
        self.locationManager.rx_didUpdateLocations.subscribeNext({ locations in
            if let location = locations.first,
               let viewModel = self.victimViewModel {
                viewModel.model.location.value = location

                self.socketManager.socket.emit("updateLocation", [
                    "socketId": self.socketManager.socket.sid!,
                    "lat": viewModel.model.location.value!.coordinate.latitude,
                    "lng": viewModel.model.location.value!.coordinate.longitude,
                    "isKiller": 0,
                ])
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


extension VictimManager: SocketManagerDelegate {
    func message(socket: SocketIOClient, onConnect data: AnyObject, ack: SocketAckEmitter?) {
        
        let model = Victim(socketId: socket.sid!)
        self.victimViewModel = VictimViewModel(model: model)
        self.victimViewModel.currentHPPercent.bindTo(self.controller.victimHPLabel.rx_text).addDisposableTo(self.disposeBag)
        self.victimViewModel.aliveStatus.map({
            $0.stateImage()
        }).bindTo(self.controller.victimStatusImage.rx_image).addDisposableTo(self.disposeBag)
        
        self.victimViewModel.aliveStatus.subscribeNext({ status in
            if status == VictimAliveStatus.DEAD {
                self.showGameOverAlert(socket)
            }
        }).addDisposableTo(self.disposeBag)
    }
    
    func message(socket: SocketIOClient, onDamage data: AnyObject, ack: SocketAckEmitter?) {
        if let socketId = data["socketId"] as? String {
            let damage = (data["newHP"] as! NSNumber).doubleValue
            
            if socketId == socket.sid && damage < Victim.maxHitPoints {
                self.victimViewModel.model.hitPoints.value = damage
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                self.controller.flashDamageWarning()
            }
        }
    }
    
    func message(socket: SocketIOClient, onUpdateLocation data: AnyObject, ack: SocketAckEmitter?) {}
}
