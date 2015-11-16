//
//  ViewModels.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import RxSwift


enum VictimAliveStatus: Int {
    case DEAD = 0
    case ALIVE
    
    func stateImage() -> UIImage {
        switch self {
        case .DEAD:
            return UIImage(named: "VictimDead")!
        case .ALIVE:
            return UIImage(named: "VictimAlive")!
        }
    }
}

class VictimViewModel {
    let disposeBag = DisposeBag()
    
    var currentHPPercent: PublishSubject<String> = PublishSubject<String>()
    var aliveStatus: PublishSubject<VictimAliveStatus> = PublishSubject<VictimAliveStatus>()
    var currentLocation: PublishSubject<CLLocation> = PublishSubject<CLLocation>()
    
    var model: Victim {
        didSet {
            let percentStr = NSString(format: "%.1f%%", self.model.hitPoints.value / Victim.maxHitPoints * 100)
            self.currentHPPercent.onNext(percentStr as String)

            if self.model.hitPoints.value > 0 {
                self.aliveStatus.onNext(VictimAliveStatus.ALIVE)
            } else {
                self.aliveStatus.onNext(VictimAliveStatus.DEAD)
            }
        }
    }
    
    init(model: Victim) {
        self.model = model
        self.bindModel()
    }
    
    func bindModel() {
        self.model.hitPoints.subscribeNext({ newHP in
            let percentStr = NSString(format: "%.1f%%", self.model.hitPoints.value / Victim.maxHitPoints * 100)
            self.currentHPPercent.onNext(percentStr as String)

            if newHP > 0 {
                self.aliveStatus.onNext(VictimAliveStatus.ALIVE)
            } else {
                self.aliveStatus.onNext(VictimAliveStatus.DEAD)
            }
        }).addDisposableTo(self.disposeBag)
        
        self.model.location.subscribeNext({ newLoc in
            if newLoc != nil {
                self.currentLocation.onNext(newLoc!)
            }
        }).addDisposableTo(self.disposeBag)
    }
    
}




