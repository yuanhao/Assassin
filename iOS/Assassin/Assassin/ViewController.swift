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

class VictimViewController: UIViewController {

    @IBOutlet weak var victimStatusImage: UIImageView!
    @IBOutlet weak var victimHPLabel: UILabel!
    
    var socket: SocketIOClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupSocketIO()
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
        })
        
        self.socket.connect()
    }
}

