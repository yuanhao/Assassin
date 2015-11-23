//
//  Operator.swift
//  Assassin
//
//  Created by Yuanhao Li on 23/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import CoreLocation


func != (left: CLLocationCoordinate2D, right: CLLocationCoordinate2D) -> Bool {
    return left.latitude != right.latitude || left.longitude != right.longitude
}


func locationForAngle(angle: Double, center: CLLocation, distance: Double) -> CLLocation {
    let center = center.coordinate
    let distRadians = distance / (6372797.6)
    let rbearing = angle * M_PI / 180.0
    
    let lat1 = center.latitude * M_PI / 180
    let lon1 = center.longitude * M_PI / 180
    
    let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(rbearing))
    let lon2 = lon1 + atan2(sin(rbearing) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
    
    return CLLocation(latitude: lat2 * 180 / M_PI, longitude: lon2 * 180 / M_PI)
}