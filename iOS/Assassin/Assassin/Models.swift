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


protocol Weapon {
    func shoot(player: Victim, distance: Double)
}


class Shuriken: Weapon {
    static let range: Double = 5
    static let maxDamage: Double = 2
    
    func shoot(player: Victim, distance: Double) {
        if distance < Shuriken.range {
            player.getHurt(self.getDamage(distance))
        }
    }
    
    func getDamage(distance: Double) -> Double {
        return Shuriken.maxDamage * (1 - distance / Shuriken.range)
    }
}


class Pistol: Weapon {
    static let range: Double = 10
    static let maxDamage: Double = 5
    
    func shoot(player: Victim, distance: Double) {
        if distance < Pistol.range {
            player.getHurt(self.getDamage(distance))
        }
    }
    
    func getDamage(distance: Double) -> Double {
        return Pistol.maxDamage * (1 - distance / Pistol.range)
    }
}

class Shotgun: Weapon {
    static let range: Double = 5
    static let maxDamage: Double = 10
    
    func shoot(player: Victim, distance: Double) {
        if distance < Shotgun.range {
            player.getHurt(self.getDamage(distance))
        }
    }
    
    func getDamage(distance: Double) -> Double {
        return Shotgun.maxDamage * (1 - distance / Shotgun.range)
    }
}


class Killer: Player {
    static let maxWeaponLoad: Int = 9
    var weapon: Weapon!
    var weaponLoad: Variable<Int> = Variable(Killer.maxWeaponLoad)
    
    func attack(victim: Victim) {
        if self.weaponLoad.value > 0 {
            let distance = self.location.value!.distanceFromLocation(victim.location.value!)
            self.weapon.shoot(victim, distance: distance)
            self.weaponLoad.value -= 1
        }
    }
}


