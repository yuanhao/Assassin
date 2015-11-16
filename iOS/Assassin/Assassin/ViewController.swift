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


class VictimViewController: UIViewController {

    @IBOutlet weak var victimStatusImage: UIImageView!
    @IBOutlet weak var victimHPLabel: UILabel!
    
    let disposeBag = DisposeBag()

    var socket: SocketIOClient!
    var victimViewModel: VictimViewModel!
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupSocketIO()
        self.setupLocationManager()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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

