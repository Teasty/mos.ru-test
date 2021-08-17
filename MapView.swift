//
//  Map.swift
//  Ageone development (ageone.ru)
//
//  Created by Андрей Лихачев on 29/04/2019.
//  Copyright © 2019 Андрей Лихачев. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import PromiseKit

import GoogleMaps
import GooglePlaces

final class MapView: BaseController {
    
    public var isMapAddressParsingBlock = false
    
    // MARK: viewModel
    
    public var carOnMap = [CarOnMap]()
    
    public var viewModel = MapViewModel()
    var alert = alertAction.create("Счастливой поездки", "", R.image.logoSingle())
    var timer = Timer()
    // MARK: ovveride
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !user.info.didAskForDiscount {
            api.askForDiscount(completion: { value in
                if value {
                    let alert = alertAction.create("", "Поздравляем, у вас скидочная поездка -70 руб.", R.image.fire())
                    alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: {_ in
                        
                        user.info.didAskForDiscount = true
                        // MARK: Add card Alert
                        //                        if user.info.paymentType.isEmpty {
                        //                            user.info.paymentType = "cash"
                        //                            let alert = alertAction.create("Вы хотите привязать банковскую карту для оплаты в приложении?", "")
                        //                            alert.addAction(UIAlertAction(title: "Отменить", style: UIAlertAction.Style.default, handler: nil))
                        //                            alert.addAction(UIAlertAction(title: "Привязать", style: UIAlertAction.Style.default, handler: { _ in
                        //                                router.transition(.present, coordinator.stack.0[1].navigation)
                        //                            }))
                        //                            alertAction.show(alert)
                        //                        }
                    }))
                    alertAction.show(alert)
                }
            })
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bindUI()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.askAboutCard()
        
        
        switch rxData.state.value {
        case .created:
            timer.invalidate()
            log.info("View Did Load with state created")
            self.createOrderRoute()
            self.viewModel.startSearchingTimer()
        case .accepted:
            timer.invalidate()
            
            log.info("View Did Load with state accepted")
            //            self.createOrderRoute()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.bodyTable.reloadData()
            }
        case .onWay:
            timer.invalidate()
            log.info("View Did Load with state onWay")
            //            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            //                self.bodyTable.reloadData()
        //            }
        case .waiting:
            timer.invalidate()
            log.info("View Did Load with state waiting")
            //            self.createOrderRoute()
            //            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            //                self.bodyTable.reloadData()
        //            }
        default :
            timer.invalidate()
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = MapViewModel.Localization.title
        renderUI()
        
        viewModel.showFire()
        
        if let tariff = utils.realm.tariff.getObjects().filter({$0.name == "Стандарт"}).first {
            var order = rxData.order.value
            order.tariff = tariff
            rxData.order.accept(order)
        }
        
        alert.addAction(UIAlertAction(title: "Ок", style: UIAlertAction.Style.default, handler: { _ in
            user.info.isOnWayAlertButtonTapped = true
            user.info.onWayAlertLastHashId = rxData.currentOrder?.hashId
        } ))
    }
    
    // MARK: UI
    
    public var map: GMSMapView
        = {
            let map = GMSMapView()
            map.camera = GMSCameraPosition(
                target: CLLocationCoordinate2D(
                    latitude: user.location.lat,
                    longitude: user.location.lng),
                zoom: 15
            )
            //        map.settings.myLocationButton = true
            map.isMyLocationEnabled = true
            return map
    }()
    
    // MARK: buttonCurrent
    
    public let buttonCurrent: BaseButton = {
        let button = BaseButton()
        button.setImage(R.image.myLocation(), for: UIControl.State.normal)
        button.layer.cornerRadius = 19.0
        button.layer.borderWidth = 0.0
        button.layer.borderColor = UIColor.clear.cgColor
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.8).cgColor
        button.layer.shadowOffset.height = 2.0
        return button
    }()
    
    // MARK: imagePin
    
    fileprivate let imagePin: UIImageView = {
        var imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = #imageLiteral(resourceName: "pinFrom").withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        return imageView
    }()
    
    fileprivate let mapSearchingView = MapSearchingView()
    fileprivate let mapRateView = MarkView()
    
}

// MARK: private

extension MapView {
    
    fileprivate func renderUI() {
        
        // MARK: map
        
        view.addSubview(map)
        map.delegate = self
        map.snp.makeConstraints { (make) in
            make.top.equalTo(0)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        view.addSubview(imagePin)
        imagePin.snp.makeConstraints { (make) in
            make.centerY.equalTo(map.snp.centerY).offset(-14)
            make.centerX.equalTo(map.snp.centerX)
            make.height.equalTo(44)
            make.width.equalTo(44)
        }
        
        // MARK: bodyTable
        
        view.addSubview(bodyTable)
        bodyTable.delegate = self
        bodyTable.dataSource = self
        bodyTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        bodyTable.bounces = false
        bodyTable.register(RowCompositeField.self)
        bodyTable.register(RowButton.self)
        bodyTable.register(MapTariffsTableCell.self)
        bodyTable.register(MapOptionsTableCell.self)
        bodyTable.register(MapHydroButtonTableCell.self)
        bodyTable.register(MapMovingTableCell.self)
        bodyTable.register(MapCompositeFieldFrom.self)
        bodyTable.snp.makeConstraints { (make) in
            make.top.equalTo(map.snp.bottom)
            make.bottom.equalTo(0)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        // MARK: buttonCurrent
        
        view.addSubview(buttonCurrent)
        buttonCurrent.snp.makeConstraints { (make) in
            make.bottom.equalTo(bodyTable.snp.top).offset(-11)
            make.right.equalTo(-14)
            make.height.equalTo(38)
            make.width.equalTo(38)
        }
        buttonCurrent.onTap = { [unowned self] in
            self.map.animate(to: GMSCameraPosition(
                latitude: user.location.lat,
                longitude: user.location.lng,
                zoom: 16)
            )
        }
        
        // MARK: mapSearchingView
        //
        view.addSubview(mapSearchingView)
        mapSearchingView.snp.makeConstraints { (make) in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        mapSearchingView.buttonCancel.onTap = { [unowned self] in
            self.viewModel.cancelRequest {
                log.info("cancel button tapped")
                if let currentOrder = rxData.currentOrder {
                    loading.show()
                    api.cancelOrder(currentOrder.hashId, completion: {
                        loading.hide()
                        self.deleteAllMarkers()
                        self.deleteAllPolylines()
                        self.viewModel.model.searchingTimer?.stop()
                        rxData.order.accept(RxData.OrderStruct())
                        rxData.state.accept(.current)
                    })
                } else {
                    log.info("no current order")
                }
            }
        }
    }
    
    fileprivate func bindUI() {
        log.info("BindUi")
        
        rxData.carOnMap
            .distinctUntilChanged()
            .bind(onNext: { _ in
//            log.info(self.viewModel.carsOnMap)
            self.updateCarOnMap()
            
        })
        
        rxData.state.asObservable()
            .asObservable()
            .distinctUntilChanged()
            .bind { [unowned self] _ in
                self.imagePin.tintColor = UIColor.clear
                self.mapSearchingView.hide()
                self.viewModel.upCostAlert.dismiss(animated: true, completion: nil)
                switch rxData.state.value {
                case .current:
                    self.timer.invalidate()
                    log.info("State: current")
                    self.deleteAllPolylines()
                    self.deleteAllMarkers()
                    self.imagePin.tintColor = utils.constants.colors.red
                    self.viewModel.stopSearchingTimer()
                case .destination:
                    self.timer.invalidate()
                    log.info("State: destination")
                    self.deleteAllPolylines()
                    self.deleteAllMarkers()
                    socket.lookForClosestDrivers()
                    self.viewModel.stopSearchingTimer()
                    self.imagePin.tintColor = UIColor(hexString: "#4681F6") ?? UIColor()
                case .to:
                    self.timer.invalidate()
                    log.info("State: to")
                    self.imagePin.tintColor = UIColor(hexString: "#4681F6") ?? UIColor()
                    self.viewModel.stopSearchingTimer()
                case .created:
                    self.timer.invalidate()
                    log.info("State: created")
                    //                    socket.stopWatchingDriver()
                    self.mapSearchingView.show()
                case .waiting:
                    self.timer.invalidate()
                    log.info("State: waiting")
                    self.viewModel.stopSearchingTimer()
                    self.viewModel.model.searchingTimer?.stop()
                    //                    if let driverHashId = rxData.currentOrder?.driver?.hashId {
                    //                        socket.chooseCertainDriver(driverId: "\(driverHashId);RED")
                    //                    }
                    self.deleteAllPolylines()
                    self.deleteAllMarkers()
                case .accepted:
                    self.timer.invalidate()
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        self.bodyTable.reloadData()
                    }
                    self.deleteAllPolylines()
                    self.deleteAllMarkers()
                    log.info("State: accepted")
                    self.viewModel.stopSearchingTimer()
                    //                    if let driverHashId = rxData.currentOrder?.driver?.hashId {
                    //                        socket.chooseCertainDriver(driverId: "\(driverHashId);RED")
                //                    }
                case .onWay:
                    self.timer.invalidate()
                    log.info("State: onWay")
                    self.viewModel.stopSearchingTimer()
                    if user.info.isNeedToShowOnWayAlert && !user.info.isOnWayAlertButtonTapped {
                        user.info.isNeedToShowOnWayAlert = false
                        DispatchQueue.main.async {
                            alertAction.show(self.alert)
                        }
                    }
                case .arrived:
                    self.timer.invalidate()
                    log.info("State: arrived")
                    if user.info.isNeedToShowRateOrderView && !user.info.rateOrderViewButtonIsTapped {
                        DispatchQueue.main.async {
                            user.info.isNeedToShowRateOrderView = false
                            if !user.info.isNeedToShowOnWayAlert && !user.info.isOnWayAlertButtonTapped {
                                self.alert.dismiss(animated: true, completion: { user.info.isOnWayAlertButtonTapped = true
                                    let controller = MarkView()
                                    controller.modalPresentationStyle = .fullScreen
                                    self.present(controller, animated: true)
                                    
                                })
                            } else {
                                user.info.isOnWayAlertButtonTapped = true
                                let controller = MarkView()
                                controller.modalPresentationStyle = .fullScreen
                                self.present(controller, animated: true)
                            }
                        }
                    }
                }
                
                self.reload()
        }.disposed(by: disposeBag)
        
        rxData.order
            .asObservable()
            .bind { [unowned self] _ in
                self.reload()
        }.disposed(by: disposeBag)
    }
    
}

// MARK: Factory

extension MapView: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch rxData.state.value {
        case .current: return 2
        case .destination: return 5 + rxData.order.value.waypoints.count
        case .created: return 0
        case .waiting: return 1
        case .accepted: return 1
        case .to: return 2
        case .onWay: return 0
        case .arrived: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch rxData.state.value {
            
            // MARK: Current state
            
        case .current:
            switch indexPath.row {
            case 0:
                let cell = reuse(tableView, indexPath, "RowCompositeField") as? RowCompositeField
                //                let place = "\(rxData.order.value.from.street) \(rxData.order.value.from.home)"
                var place = rxData.order.value.from.stringName
                place = place == " " ? "" : place
                cell?.initialize(place, "Место посадки", R.image.pinFrom(), R.image.pencil())
                cell?.onTap = { [unowned self] in
                    
                    utils.googleMapKit.autocomplite(GMSPlacesAutocompleteTypeFilter.establishment, completion: { [unowned self] address in
                        log.verbose(address)
                        
                        self.isMapAddressParsingBlock = true
                        var order = rxData.order.value
                        order.from = address
                        rxData.order.accept(order)
                        if !address.isPlace {
                            DispatchQueue.main.async { [unowned self] in
                                let accurancy2 = Accurancy2View()
                                accurancy2.onSelect = { [unowned self] value in
                                    let adr = "\(rxData.order.value.from.country), город \(rxData.order.value.from.city), \(rxData.order.value.from.street) \(value)"
                                    utils.googleMapKit.getAddressFromLatLong(address: adr, completion: { [unowned self] accAddress in
                                        var order = rxData.order.value
                                        order.from = accAddress
                                        order.from.stringName = "\(rxData.order.value.from.street) \(value)"
                                        rxData.order.accept(order)
                                        api.requestPrice {}
                                        DispatchQueue.main.async { [unowned self] in
                                            self.map.animate(toLocation: CLLocationCoordinate2D(latitude: accAddress.lat, longitude: accAddress.lng))
                                            self.map.animate(toZoom: 16.0)
                                        }
                                    })
                                }
                                utils.controller()?.present(accurancy2, animated: true, completion: {
                                    if let filed = accurancy2.bodyTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? RowFieldText {
                                        filed.textField.becomeFirstResponder()
                                    }
                                })
                            }
                        } else {
                            DispatchQueue.main.async { [unowned self] in
                                self.map.animate(toLocation: CLLocationCoordinate2D(latitude: address.lat, longitude: address.lng))
                            }
                        }
                        
                    })
                }
                return cell!
            default:
                let cell = reuse(tableView, indexPath, "RowButton") as? RowButton
                cell?.initialize("Я здесь")
                cell?.button.onTap = {
                    self.emitEvent?(MapViewModel.EventType.onAccurancy.rawValue)
                }
                return cell!
            }
            
            // MARK: Destination State
            
        case .destination:
            switch indexPath.row {
                
                // MARK: From
                
            case 0:
                let cell = reuse(tableView, indexPath, "MapTariffsTableCell") as? MapTariffsTableCell
                cell?.initialize()
                return cell!
            case 1:
                let cell = reuse(tableView, indexPath, "MapCompositeFieldFrom") as? MapCompositeFieldFrom
                //                let place = "\(rxData.order.value.from.street) \(rxData.order.value.from.home)"
                let place = "\(rxData.order.value.from.stringName)"
                cell?.initialize(place, "Место посадки", rxData.order.value.porch, R.image.pinFrom(), R.image.pencil())
                cell?.buttonRight.onTap = {
                    rxData.state.accept(RxData.StateType.current)
                }
                cell?.onTap = {
                    rxData.state.accept(RxData.StateType.current)
                }
                
                return cell!
                
                // MARK: To
                
            case (5 + rxData.order.value.waypoints.count - 3):
                let cell = reuse(tableView, indexPath, "RowCompositeField") as? RowCompositeField
                //                var place = "\(rxData.order.value.to.street) \(rxData.order.value.to.home)"
                var place = "\(rxData.order.value.to.stringName)"
                place = place.count == 1 ? "" : place
                
                if rxData.order.value.to.street.isEmpty && rxData.order.value.to.stringName.isEmpty {
                    cell?.initialize(place, "Куда", R.image.pinTo(), R.image.heart())
                    cell?.buttonRight.onTap = { [unowned self] in
                        self.viewModel.openFavorites(completion: { (state) in
                            if state {
                                self.emitEvent?(MapViewModel.EventType.onFavorite.rawValue)
                            } else {
                                DispatchQueue.main.async { [unowned self] in
                                    self.map.animate(toLocation: CLLocationCoordinate2D(latitude: rxData.order.value.to.lat, longitude:  rxData.order.value.to.lng))
                                    self.map.animate(toZoom: 16.0)
                                }
                            }
                        })
                    }
                } else {
                    cell?.initialize(place, "Куда", R.image.pinTo(), R.image.plus())
                    cell?.buttonRight.onTap = {
                        if rxData.order.value.waypoints.count < 2 {
                            var order = rxData.order.value
                            order.waypoints.append(GoogleMapKit.Address())
                            rxData.order.accept(order)
                        }
                    }
                }
                cell?.onTap = {
                    rxData.state.accept(RxData.StateType.to)
                }
                
                return cell!
                
                // MARK: Options
                
            case (5 + rxData.order.value.waypoints.count - 2):
                let cell = reuse(tableView, indexPath, "MapOptionsTableCell") as? MapOptionsTableCell
                cell?.initialize()
                return cell!
                
                // MARK: Button
                
            case (5 + rxData.order.value.waypoints.count - 1):
                let cell = reuse(tableView, indexPath, "MapHydroButtonTableCell") as? MapHydroButtonTableCell
                cell?.initialize(self.viewModel.getRidePrice())
                cell?.button.onTap = { [unowned self] in

                    loading.show()
                    api.createOrder { [unowned self] in
                        loading.hide()
                        self.createOrderRoute()
                        self.viewModel.startSearchingTimer()
                    }
                }
                return cell!
                
                // MARK: Waymark
                
            default:
                let cell = reuse(tableView, indexPath, "RowCompositeField") as? RowCompositeField
                //                var place = "\(rxData.order.value.waypoints[indexPath.row - 2].street) \(rxData.order.value.waypoints[indexPath.row - 2].home)"
                var place = "\(rxData.order.value.waypoints[indexPath.row - 2].stringName)"
                place = place.count == 1 ? "" : place
                cell?.initialize(place, "Остановка", R.image.point(), R.image.deleteStep())
                cell?.onTap = {
                    utils.googleMapKit.autocomplite(GMSPlacesAutocompleteTypeFilter.establishment, completion: { address in
                        self.isMapAddressParsingBlock = true
                        var order = rxData.order.value
                        order.waypoints[indexPath.row - 2] = address
                        rxData.order.accept(order)
                        if !address.isPlace {
                            DispatchQueue.main.async {
                                let accurancy2 = Accurancy2View()
                                accurancy2.onSelect = { value in
                                    let adr = "\(rxData.order.value.waypoints[indexPath.row - 2].country), город \(rxData.order.value.waypoints[indexPath.row - 2].city), \(rxData.order.value.waypoints[indexPath.row - 2].street) \(value)"
                                    utils.googleMapKit.getAddressFromLatLong(address: adr, completion: { accAddress in
                                        var order = rxData.order.value
                                        order.waypoints[indexPath.row - 2] = accAddress
                                        order.waypoints[indexPath.row - 2].stringName = "\(rxData.order.value.waypoints[indexPath.row - 2].street) \(value)"
                                        rxData.order.accept(order)
                                        api.requestPrice {}
                                    })
                                }
                                utils.controller()?.present(accurancy2, animated: true, completion: {
                                    if let filed = accurancy2.bodyTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? RowFieldText {
                                        filed.textField.becomeFirstResponder()
                                        
                                    }
                                })
                            }
                        } else {
                            api.requestPrice {}
                        }
                    })
                }
                cell?.buttonRight.onTap = {
                    var order = rxData.order.value
                    order.waypoints.remove(at: (indexPath.row - 2))
                    rxData.order.accept(order)
                    api.requestPrice {}
                }
                return cell!
            }
            
        case .to:
            switch indexPath.row {
            case 0:
                let cell = reuse(tableView, indexPath, "RowCompositeField") as? RowCompositeField
                //                var place = "\(rxData.order.value.to.street) \(rxData.order.value.to.home)"
                var place = rxData.order.value.to.stringName
                place = place == " " ? "" : place
                cell?.initialize(place, "Куда?", R.image.pinTo(), R.image.pencil())
                cell?.onTap = { [unowned self] in
                    utils.googleMapKit.autocomplite(GMSPlacesAutocompleteTypeFilter.establishment, completion: { [unowned self] address in
                        self.isMapAddressParsingBlock = true
                        var order = rxData.order.value
                        order.to = address
                        rxData.order.accept(order)
                        if !address.isPlace {
                            DispatchQueue.main.async { [unowned self] in
                                let accurancy2 = Accurancy2View()
                                accurancy2.onSelect = { [unowned self] value in
                                    let adr = "\(rxData.order.value.to.country), город \(rxData.order.value.to.city), \(rxData.order.value.to.street) \(value)"
                                    utils.googleMapKit.getAddressFromLatLong(address: adr, completion: { [unowned self] accAddress in
                                        var order = rxData.order.value
                                        order.to = accAddress
                                        order.to.stringName = "\(rxData.order.value.to.street) \(value)"
                                        rxData.order.accept(order)
                                        api.requestPrice {}
                                        DispatchQueue.main.async { [unowned self] in
                                            self.map.animate(toLocation: CLLocationCoordinate2D(latitude: accAddress.lat, longitude: accAddress.lng))
                                            self.map.animate(toZoom: 16.0)
                                        }
                                    })
                                }
                                utils.controller()?.present(accurancy2, animated: true, completion: {
                                    if let filed = accurancy2.bodyTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? RowFieldText {
                                        filed.textField.becomeFirstResponder()
                                    }
                                })
                            }
                        } else {
                            DispatchQueue.main.async { [unowned self] in
                                self.map.animate(toLocation: CLLocationCoordinate2D(latitude: address.lat, longitude: address.lng))
                            }
                            api.requestPrice {}
                        }
                    })
                }
                return cell!
            default:
                let cell = reuse(tableView, indexPath, "RowButton") as? RowButton
                cell?.initialize("Продолжить")
                cell?.button.onTap = {
                    rxData.state.accept(RxData.StateType.destination)
                    api.requestPrice {}
                }
                return cell!
            }
            
            // MARK: Searching state
            
        case .created: break
        case .arrived: break
            
            // MARK: Waiting state
            
        case .waiting:
            let cell = reuse(tableView, indexPath, "MapMovingTableCell") as? MapMovingTableCell
            cell?.initialize(currentOrder: rxData.currentOrder)
            cell?.buttonCall.onTap = {
                if let driver = rxData.currentOrder?.driver {
                    utils.makePhoneCall(number: "+7\(driver.phone)")
                }
            }
            cell?.buttonCancel.onTap = { [unowned self] in
                guard let order = rxData.currentOrder else { return }
                self.viewModel.cancelRequest {
                    loading.show()
                    api.cancelOrder(order.hashId, completion: { [unowned self] in
                        loading.hide()
                        self.deleteAllPolylines()
                        self.deleteAllMarkers()
                        rxData.order.accept(RxData.OrderStruct())
                        rxData.state.accept(.current)
                    })
                }
            }
            return cell!
            
            // MARK: Moving state
            
        case .accepted:
            let cell = reuse(tableView, indexPath, "MapMovingTableCell") as? MapMovingTableCell
            cell?.initialize(currentOrder: rxData.currentOrder)
            cell?.buttonCall.onTap = {
                if let driver = rxData.currentOrder?.driver {
                    utils.makePhoneCall(number: "+7\(driver.phone)")
                }
            }
            cell?.buttonCancel.onTap = { [unowned self] in
                guard let order = rxData.currentOrder else { return }
                self.viewModel.cancelRequest {
                    loading.show()
                    api.cancelOrder(order.hashId, completion: { [unowned self] in
                        loading.hide()
                        self.deleteAllPolylines()
                        self.deleteAllMarkers()
                        rxData.order.accept(RxData.OrderStruct())
                        rxData.state.accept(.destination)
                    })
                }
            }
            return cell!
        case .onWay: BaseTableCell()
        }
        return BaseTableCell()
    }
}
