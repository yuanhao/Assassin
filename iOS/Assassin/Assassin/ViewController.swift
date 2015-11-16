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
        
        self.socket.connect()
    }
    
    func setupLocationManager() {
        self.locationManager.requestAlwaysAuthorization()
    }
}

