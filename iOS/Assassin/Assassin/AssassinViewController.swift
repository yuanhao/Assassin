//
//  AssassinViewController.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import MapKit
import RxSwift
import RxCocoa


class AssassinViewController: UIViewController {

    @IBOutlet weak var assassinTime: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var weaponLoadLabel: UILabel!
    @IBOutlet weak var weaponReloadButton: UIButton!

    var manager: AssassinManager!
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.manager = AssassinManager(controller: self)
        self.initViews()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func initViews() {
        self.mapView.delegate = self.manager
        self.mapView.showsPointsOfInterest = true

        self.weaponReloadButton.rx_tap.subscribeNext({ _ in
            self.manager.showReloadWeaponAction()
        }).addDisposableTo(self.disposeBag)
    }

}
