//
//  Map.swift
//  Ageone development (ageone.ru)
//
//  Created by Андрей Лихачев on 29/04/2019.
//  Copyright © 2019 Андрей Лихачев. All rights reserved.
//

import RxCocoa
import RxSwift
import PromiseKit
import RealmSwift
import GoogleMaps
import Alamofire
import SwiftyJSON

// MARK: Events

extension MapViewModel {
    public enum EventType: String, CaseIterable {
        case onFinish, onAccurancy, onFavorite
    }
}

// MARK: Initialize

extension MapViewModel {
    func initialize<T: ModelProtocol>(_ receivedModel: T, completion: @escaping () -> Void) {
        guard let unwarp = receivedModel as? MapModel else { unwarpError(); return }; model = unwarp
//        loadRealmData()
//        bindRealm()
    
        upCostAlert.addAction(UIAlertAction(title: "Увеличить цену", style: UIAlertAction.Style.default, handler: { [unowned self] _ in
            self.riseUpPrice()
        }))
        upCostAlert.addAction(UIAlertAction(title: "Продолжить поиск", style: UIAlertAction.Style.default, handler: { [unowned self] _ in
            self.startSearchingTimer()
        }))
        
        setDefaultTariff()
        completion()
    }
}

// MARK: View Model

final class MapViewModel: BaseViewModel, ViewModelProtocol {
    
    // MARK: Factory   -   [activate loadRealmData() in initialize]
    
//    public var realmData = [<# RealmClass #>]()
//    public func factory(_ index: IndexPath) -> Document {
//        return realmData[index.row]
//    }
//    fileprivate func loadRealmData() {
//        realmData = utils.realm.<# RealmClass #>.getObjects()
//    }
    
    // MARK: Observable Realm   -   [activate bindRealm() in initialize]
    
//    fileprivate func bindRealm() {
//        Observable
//            .array(from: utils.realm.<# object #>.getResults())
//            .subscribe(onNext: { [unowned self] _ in
//                self.loadRealmData()
//                self.onRealmUpdate?()
//            })
//            .disposed(by: disposeBag)
//    }

    public var model = MapModel()
    public var numberOfRows = Int()
    public var markers = [GMSMarker]()
    public var carsOnMap = [CarOnMap]()
    public var polylines = [GMSPolyline]()
    
    fileprivate var timer: Timer? = nil
    fileprivate var count = Int()
    let upCostAlert = alertAction.create("Увеличение стоимости", "Для более быстрой подачи автомобиля")
    
    
    // MARK: - Localization
    
    enum Localization {
        static let title                     = "Map.Title".localized()
    }
    
    // MARK: private
    
    // MARK: public
    
    public func showFire() {
        
        if rxData.isDiscountShow {
            return
        }
        rxData.isDiscountShow = true
        
//        guard let config = utils.realm.config.getObjects().first else {
//            return
//        }
        
        log.verbose(utils.realm.order.getObjects().filter({$0.__status == "arrived"}).count)
//        log.verbose(config.ridesToGetDiscount)
        
//        if utils.realm.order.getObjects().filter({$0.__status == "arrived"}).count % config.ridesToGetDiscount == 0 {
//            log.verbose("here")
//            let alert = alertAction.create("Поздравляем", "Сегодня для Вас скидка \(config.discount) рублей", R.image.fire())
//            alert.addAction(UIAlertAction(title: "ОК", style: UIAlertAction.Style.cancel, handler: { _ in
//                log.verbose("OK")
//                rxData.discount = config.discount
//            }))
//            alertAction.show(alert)
//        }

    }
    
    public func askAboutCard() {
//        if user.info.payments.count < 1 {
//            let alert = alertAction.create("Вы хотите привязать банковскую карту для оплаты в приложении?", "")
//            alert.addAction(UIAlertAction(title: "Привязать", style: UIAlertAction.Style.default, handler: { _ in
//                router.transition(.present, coordinator.stack.0[1].navigation)
//            }))
//            alert.addAction(UIAlertAction(title: "Отмена", style: UIAlertAction.Style.cancel, handler: nil))
//            alertAction.show(alert)
//        }
    }
    
    public func selectFavorite(completion: @escaping () -> Void) {
        let realm = try! Realm()
        let favorites = realm.objects(Favorite.self)
        var addresses = [AlertAction.ActionSheetElement]()
        for favorite in favorites {
            addresses.append(AlertAction.ActionSheetElement(name: favorite.name, value: favorite.hashId))
        }
        alertAction.actionSheet(title: "Выберите из любимых адресов", actions: addresses, selected: "") { (selected) in
            if let favorite = realm.object(ofType: Favorite.self, forPrimaryKey: selected) {
                var address = GoogleMapKit.Address()
                address.postalCode = favorite.postalCode
                address.country = favorite.country
                address.region = favorite.region
                address.city = favorite.city
                address.street = favorite.street
                address.home = favorite.home
                address.lat = favorite.lat
                address.lng = favorite.lng
                var order = rxData.order.value
                    order.to = address
                rxData.order.accept(order)
            }
        }
    }
    
    public func cancelRequest(completion: @escaping () -> Void) {
        let alert = alertAction.create("Вы действительно хотите отменить заказ?", "")
        alert.addAction(UIAlertAction(title: "Да", style: UIAlertAction.Style.default, handler: { [unowned self] _ in
            self.hardStopSearchingTimer()
            completion()
        }))
        alert.addAction(UIAlertAction(title: "Нет", style: UIAlertAction.Style.default, handler: nil))
        alertAction.show(alert)
    }
    
    public func riseUpPriceRequest() {
        alertAction.show(upCostAlert)
    }
    
    public func riseUpPrice() {
        let actions = [
            AlertAction.ActionSheetElement(name: "20 руб.", value: "20"),
            AlertAction.ActionSheetElement(name: "40 руб.", value: "40"),
            AlertAction.ActionSheetElement(name: "60 руб.", value: "60"),
            AlertAction.ActionSheetElement(name: "80 руб.", value: "80"),
            AlertAction.ActionSheetElement(name: "100 руб.", value: "100"),
            AlertAction.ActionSheetElement(name: "120 руб.", value: "120")
        ]
        alertAction.actionSheet(title: "На какую сумму увеличить ?", actions: actions, selected: "") { [unowned self] value in
            
            api.request(["router": "upCost", "orderHashId": rxData.currentOrder?.hashId, "upCost": Double(value) ?? 0], completion: { _ in
                var order = rxData.order.value
                order.price += Double(value) ?? 0
                order.upCost += Int(value) ?? 0
                rxData.order.accept(order)
//                rxData.currentOrder?.upCost += Int(value) ?? 0
//                rxData.currentOrder?.price += Double(Int(value) ?? 0)
            })
            
            self.startSearchingTimer()
        }
    }
    
    public func stopSearchingTimer() {
        log.info("Timer stopped")
        timer?.invalidate()
        timer = nil
        if Int(Date().timeIntervalSince1970) - user.info.startTimerTime > 60 {
            user.info.startTimerTime = 0
        }
        count = 0
    }
    
    public func hardStopSearchingTimer() {
        user.info.startTimerTime = 0
        timer?.invalidate()
        timer = nil
        count = 0
    }

    public func startSearchingTimer() {
        stopSearchingTimer()
        var addedTime: Int = 0
        log.verbose(user.info.startTimerTime)
        if user.info.startTimerTime != 0 {
            addedTime +=  Int(Date().timeIntervalSince1970) - user.info.startTimerTime
        } else {
            user.info.startTimerTime = Int(Date().timeIntervalSince1970)
        }
        log.verbose("New: \(user.info.startTimerTime)")
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.count += 1
            log.verbose((self?.count ?? 0) + addedTime)
            if let count = self?.count {
                if count + addedTime > 5 {
                    self?.riseUpPriceRequest()
                    self?.stopSearchingTimer()
                }
            }
//            let seconds = order.expectedTime + order.created - Int(Date().timeIntervalSince1970)
//            self?.labelTime.text = self?.formatSecondsToString(seconds)
        }
//        model.searchingTimer?.stop()
//        model.searchingTimer = CustomTimer(CustomTimer.Types.decrement, onCount: { [unowned self] count in
//            log.verbose(count)
//            if count == 0 {
//                self.riseUpPriceRequest()
//            }
//        })
//        model.searchingTimer?.start(count: model.searchingTimerCount) { [unowned self] in
//            log.verbose("Timer stopped")
//        }
    }
    
    fileprivate func setDefaultTariff() {
        if let tariff = utils.realm.tariff.getObjects().filter({$0.coefficient == 1}).first {
            var order = rxData.order.value
            order.tariff = tariff
            rxData.order.accept(order)
        } else {
            if let tariff = utils.realm.tariff.getObjects().first {
                var order = rxData.order.value
                order.tariff = tariff
                rxData.order.accept(order)
            }
        }
    }
    
// MARK: CalcPrice
    public func getRidePrice() -> String {
        
        if rxData.order.value.basePrice == 0.0 || rxData.order.value.basePrice == 111 {
            return "\(rxData.order.value.tariff.info)"
        }

        return  "\(Int(rxData.order.value.basePrice)) руб."
        
    }
    
    public func openFavorites(completion: @escaping (Bool) -> Void) {
        let realm = try! Realm()
        let favorits = realm.objects(Favorite.self)
        if favorits.isEmpty {
            completion(true)
        } else {
            let alert = UIAlertController.init(title: "Выберите адрес", message: "", preferredStyle: UIAlertController.Style.actionSheet)
            for favorit in favorits {
                alert.addAction(UIAlertAction(title: favorit.name, style: UIAlertAction.Style.default, handler: { _ in
                    var order = rxData.order.value
                    order.to = GoogleMapKit.Address(home: favorit.home, postalCode: favorit.postalCode, street: favorit.street, region: favorit.region, city: favorit.city, country: favorit.country, isPlace: false, lat: favorit.lat, lng: favorit.lng, stringName: "\(favorit.street) \(favorit.home)")
                    rxData.order.accept(order)
                    
                    api.requestPrice {
                    }
                    completion(false)
                })
                )
            }
            alert.addAction(UIAlertAction(title: "Отмена", style: UIAlertAction.Style.default, handler: nil))
            utils.controller()?.present(alert, animated: true, completion: nil)
        }
    }
    
}

// MARK: Model

class MapModel: ModelProtocol {
    public var searchingTimer: CustomTimer?
    public var searchingTimerCount = 15
}
