//
//  MapViewCarOnMap.swift
//  Template.ageone
//
//  Created by Андрей Лихачев on 25/06/2019.
//  Copyright © 2019 Андрей Лихачев. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

extension MapView {
    
    public func updateCarOnMap() {
        
        for car in rxData.carOnMap.value {
            if viewModel.carsOnMap.filter({$0.hashId == car.hashId}).isEmpty {
                // add car on map
                viewModel.carsOnMap.append(car)
                let pin = GoogleMapKit.Coordinates(lat: car.lat, lng: car.lng)
                
                var image: UIImage? = UIImage()
                switch car.color {
                case "blue": image = R.image.carBlue()
                case "yellow": image = R.image.carYellow()
                case "white": image = R.image.carWhite()
                case "red": image = R.image.carRed()
                case "grey": image = R.image.carGray()
                case "green": image = R.image.carGreen()
                case "beige": image = R.image.carBeige()
                case "burgundy": image = R.image.carBurgary()
                case "cherry": image = R.image.carCherry()
                case "lightBlue": image = R.image.carLightBlue()
                case "golden": image = R.image.carGolden()
                case "brown": image = R.image.carBrown()
                case "orange": image = R.image.carOrange()
                case "silver": image = R.image.carSilver()
                case "violet": image = R.image.carViolet()
                default: image = R.image.carBlack()
                }
                image = image?.rotate(radians: -2 *  (.pi/1))
                createMarker(pin, image, car.hashId)
            }
//            log.verbose("Car on Map: \(car)")
        }
        
        var toRemove = [CarOnMap]()
        
        for (index, car) in viewModel.carsOnMap.enumerated() {
            if let carFromServer = rxData.carOnMap.value.filter({$0.hashId == car.hashId}).first {
                if let marker = viewModel.markers.filter({$0.userData as? String == car.hashId}).first {

                    let toLat = carFromServer.lat
                    let toLng = carFromServer.lng

                    if rxData.calculateDistance(lat1: car.lat, lon1: car.lng, lat2: toLat, lon2: toLng) > 3.5 {
                        let animationDuration: Float = 3.0
                        CATransaction.begin()
                        CATransaction.setValue(NSNumber(value: animationDuration), forKey: kCATransactionAnimationDuration)
                        marker.position = CLLocationCoordinate2D(latitude: toLat, longitude: toLng)
                        marker.rotation = CLLocationDegrees(exactly: getBearingBetweenTwoPoints1(
                            point1: CLLocation(latitude: car.lat, longitude: car.lng),
                            point2: CLLocation(latitude: toLat, longitude: toLng))) ?? 0.0
                        CATransaction.commit()

                        viewModel.carsOnMap[index].lat = toLat
                        viewModel.carsOnMap[index].lng = toLng

//                        log.error("Move: \(viewModel.carsOnMap[index])")
                    }

                    // move var on map
                }
            } else {
                // delete cars from map
//                log.verbose("delete")
                for (index, marker) in viewModel.markers.enumerated() {
                    if let type = marker.userData as? String {
                        if type == car.hashId {
                            marker.map = nil
                            viewModel.markers.remove(at: index)
                        }
                    }
                }
            }
        }
        
        viewModel.carsOnMap = rxData.carOnMap.value
        
    }
    
    func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }
    
    func getBearingBetweenTwoPoints1(point1: CLLocation, point2: CLLocation) -> Double {
        
        let lat1 = degreesToRadians(degrees: point1.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: point1.coordinate.longitude)
        
        let lat2 = degreesToRadians(degrees: point2.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: point2.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansToDegrees(radians: radiansBearing)
    }
    
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
