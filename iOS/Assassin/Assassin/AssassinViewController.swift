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
        /*
        self.mapView.delegate = self
        self.mapView.showsPointsOfInterest = true
        */
    }
    
    func setupSocketIO() {
        self.socket = SocketIOClient(socketURL: "127.0.0.1:3001", options: [.Log(true), .ForcePolling(true)])
        
        self.socket.on("connect", callback: { data, ack in
            
            let model = Killer(socketId: self.socket.sid!)
            self.assassinViewModel = AssassinViewModel(model: model)
            
            self.assassinViewModel.currentWeaponLoad.map({
                "\($0)"
            }).bindTo(self.weaponLoadLabel.rx_text).addDisposableTo(self.disposeBag)
            
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
                    
                    let victimMapAnnoation = VictimMapAnnotation(model: victim)
                    self.victimMapAnnotations[victimSocketId] = victimMapAnnoation
                    self.mapView.addAnnotation(victimMapAnnoation)
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
        
        self.locationManager.startUpdatingLocation()
        if let location = self.locationManager.location {
            // range 50 meters
            let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 50, 50)
            self.mapView.setRegion(coordinateRegion, animated: true)
        }
    }

}