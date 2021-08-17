//
//  MapViewMapDelegate.swift
//  Template.ageone
//
//  Created by Андрей Лихачев on 05/05/2019.
//  Copyright © 2019 Андрей Лихачев. All rights reserved.
//

import GoogleMaps
import GooglePlaces

// MARK: GMSMapViewDelegate

extension MapView: GMSMapViewDelegate {
    
    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        
        log.verbose(self.isMapAddressParsingBlock)
        if self.isMapAddressParsingBlock {
            self.isMapAddressParsingBlock = false
            return
        }
        log.verbose(self.isMapAddressParsingBlock)
        
        self.isMapAddressParsingBlock = true
        if rxData.state.value == .current || rxData.state.value == .destination || rxData.state.value == .to {
            // geodecodeByCoordinatesByAPI
            DispatchQueue.global(qos: .background).async {
                
                let parameters: [String:Any] = [
                    "router":"geocodeReverse",
                    "lat": position.target.latitude,
                    "lng": position.target.longitude
                ]
                api.geocode(parameters, completion: { json in
                    utils.googleMapKit.parseResultFromServer(json) { address in
                        var order = rxData.order.value
                        if rxData.state.value == .current {
                            order.from = address
                            order.from.lat = position.target.latitude
                            order.from.lng = position.target.longitude
                            order.from.stringName = "\(address.street) \(address.home)"
                        }
                        if rxData.state.value == .destination || rxData.state.value == .to {
                            order.to = address
                            order.to.lat = position.target.latitude
                            order.to.lng = position.target.longitude
                            order.to.stringName = "\(address.street) \(address.home)"
                            DispatchQueue.main.async {
                                api.requestPrice {}
                            }
                        }
                        rxData.order.accept(order)
                        self.isMapAddressParsingBlock = false
                    }
                })
                
                
//                utils.googleMapKit.geodecodeByCoordinatesByAPI(GoogleMapKit.Coordinates(
//                    lat: position.target.latitude, lng: position.target.longitude)) { address in
//                        var order = rxData.order.value
//                        if rxData.state.value == .current {
//                            order.from = address
//                            order.from.stringName = "\(address.street) \(address.home)"
//                        }
//                        if rxData.state.value == .destination || rxData.state.value == .to {
//                            order.to = address
//                            order.to.stringName = "\(address.street) \(address.home)"
//                            DispatchQueue.main.async {
//                                api.requestPrice {}
//                            }
//                        }
//                        rxData.order.accept(order)
//                        self.isMapAddressParsingBlock = false
//                }
            }
        }
    }
    
}

extension MapView {
    
    public func createRouteMarkers() {
        if rxData.order.value.from.street.isEmpty && rxData.order.value.from.stringName.isEmpty {
            let from = GoogleMapKit.Coordinates(lat: rxData.currentOrder?.departure?.lat ?? 0, lng: rxData.currentOrder?.departure?.lng ?? 0)
            createMarker(from, R.image.pinFrom())
            let to = GoogleMapKit.Coordinates(lat: rxData.currentOrder?.arrival?.lat ?? 0, lng: rxData.currentOrder?.arrival?.lng ?? 0)
            createMarker(to, R.image.pinTo())
        } else {
            let from = GoogleMapKit.Coordinates(lat: rxData.order.value.from.lat, lng: rxData.order.value.from.lng)
            createMarker(from, R.image.pinFrom())
            let to = GoogleMapKit.Coordinates(lat: rxData.order.value.to.lat, lng: rxData.order.value.to.lng)
            createMarker(to, R.image.pinTo())
        }     
    }
    
    public func createMarker(_ coordinates: GoogleMapKit.Coordinates, _ image: UIImage?, _ type: String = "waymark") {
        let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: coordinates.lat, longitude: coordinates.lng))
        if let image = image {
            marker.icon = image
            
        }
        marker.map = map
        marker.userData = type
        viewModel.markers.append(marker)
    }
    
    public func drawPolilyne() {
        guard let road = rxData.currentOrder?.roadToArrival else { return }
        deleteAllPolylines()
        let newPath = GMSPath(fromEncodedPath: road.roadPolyline)
        let polyline = GMSPolyline(path: newPath)
        polyline.strokeColor = utils.constants.colors.red
        polyline.strokeWidth = 4
        polyline.map = self.map
        map.animate(with: GMSCameraUpdate.fit(GMSCoordinateBounds(path: newPath!), withPadding: 50.0))
        viewModel.polylines.append(polyline)
    }
    
    public func deleteAllMarkers() {
        for marker in viewModel.markers {
            if let type = marker.userData as? String {
                if type == "waymark" {
                    marker.map = nil
                }
            }
        }
    }
    
    public func deleteAllPolylines() {
        for polyline in viewModel.polylines {
            polyline.map = nil
        }
    }
    
    public func createOrderRoute() {
        deleteAllPolylines()
        deleteAllMarkers()
        var waypoints = [GoogleMapKit.Coordinates]()
        var to = GoogleMapKit.Coordinates()
        var from = GoogleMapKit.Coordinates()
        
        if rxData.order.value.from.street.isEmpty && rxData.order.value.from.stringName.isEmpty {
            log.info("Order is empty, current order: \(rxData.currentOrder)")
            
            if let point = rxData.currentOrder?.departure {
                from = GoogleMapKit.Coordinates(lat: point.lat, lng: point.lng)
            }
            
            if let point = rxData.currentOrder?.arrival {
                to = GoogleMapKit.Coordinates(lat: point.lat, lng: point.lng)
            }
            
            if let point = rxData.currentOrder?.intermediatePoint1, rxData.currentOrder?.intermediatePoint1?.lng != 0 && rxData.currentOrder?.intermediatePoint1?.lat != 0 {
                waypoints.append(GoogleMapKit.Coordinates(lat: point.lat, lng: point.lng))
            }
            if let point = rxData.currentOrder?.intermediatePoint2, rxData.currentOrder?.intermediatePoint2?.lng != 0 && rxData.currentOrder?.intermediatePoint2?.lat != 0 {
                waypoints.append(GoogleMapKit.Coordinates(lat: point.lat, lng: point.lng))
            }
            self.drawPolilyne()
            self.createRouteMarkers()
            
        } else {
            
            from = GoogleMapKit.Coordinates(lat: rxData.order.value.from.lat, lng: rxData.order.value.from.lng)
            
            to = GoogleMapKit.Coordinates(lat: rxData.order.value.to.lat, lng: rxData.order.value.to.lng)
            
            for waypoint in rxData.order.value.waypoints {
                waypoints.append(GoogleMapKit.Coordinates(lat: waypoint.lat, lng: waypoint.lng))
            }
            self.drawPolilyne()
            self.createRouteMarkers()
        }
    }
    
}
