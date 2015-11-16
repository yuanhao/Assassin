//
//  Models.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import Foundation
import CoreLocation
import RxSwift


class Player {
    let socketId: String
    var location: Variable<CLLocation?> = Variable(Optional.None)
    
    init(socketId: String) {
        self.socketId = socketId
    }
}


class Victim: Player {
    static let maxHitPoints: Double = 42.0
    var hitPoints: Variable<Double> = Variable(Victim.maxHitPoints)
    
    func getHurt(damage: Double) {
        let newHP: Double = self.hitPoints.value - damage
        self.hitPoints.value = max(0, newHP)
    }
}