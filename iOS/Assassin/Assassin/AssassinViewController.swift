//
//  AssassinViewController.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import MapKit

class AssassinViewController: UIViewController {

    @IBOutlet weak var assassinTime: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var weaponLoadLabel: UILabel!
    @IBOutlet weak var weaponReloadButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initViews()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func initViews() {
        
    }
}
