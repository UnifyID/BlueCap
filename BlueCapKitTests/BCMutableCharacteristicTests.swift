//
//  BCMutableCharacteristicTests.swift
//  BlueCapKit
//
//  Created by Troy Stribling on 3/24/15.
//  Copyright (c) 2015 Troy Stribling. The MIT License (MIT).
//

import UIKit
import XCTest
import CoreBluetooth
import CoreLocation
@testable import BlueCapKit

// MARK: - BCMutableCharacteristicTests -
class BCMutableCharacteristicTests: XCTestCase {
    
    override func setUp() {
        GnosusProfiles.create()
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func addCharacteristics(onSuccess: (mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void) {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let (mock, peripheralManager) = createPeripheralManager(false, state: .PoweredOn)
        let services = createPeripheralManagerServices(peripheralManager)
        services[0].characteristics = services[0].profile.characteristics.map { profile in
            let characteristic = CBMutableCharacteristicMock(UUID:profile.UUID, properties: profile.properties, permissions: profile.permissions, isNotifying: false)
            return BCMutableCharacteristic(cbMutableCharacteristic: characteristic, profile: profile)
        }
        let future = peripheralManager.addService(services[0])
        future.onSuccess {
            expectation.fulfill()
            mock.isAdvertising = true
            onSuccess(mock: mock, peripheralManager: peripheralManager, service: services[0])
        }
        future.onFailure {error in
            XCTFail("onFailure called")
        }
        peripheralManager.didAddService(services[0].cbMutableService, error: nil)
        waitForExpectationsWithTimeout(20) {error in
            XCTAssertNil(error, "\(error)")
        }
    }

    // MARK: Add characteristics
    func testAddCharacteristics_WhenServiceAddWasSuccessfull_CompletesSuccessfully() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let chracteristics = peripheralManager.characteristics.map { $0.UUID }
            XCTAssertEqual(chracteristics.count, 2, "characteristic count invalid")
            XCTAssert(chracteristics.contains(CBUUID(string: Gnosus.HelloWorldService.Greeting.UUID)), "characteristic uuid is invalid")
            XCTAssert(chracteristics.contains(CBUUID(string: Gnosus.HelloWorldService.UpdatePeriod.UUID)), "characteristic uuid is invalid")
        }
    }

    // MARK: Subscribe to charcteristic updates
    func testUpdateValueWithData_WithNoSubscribers_AddsUpdateToPengingQueue() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            XCTAssertFalse(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssertEqual(characteristic.subscribers.count, 0, "characteristic has subscribers")
            XCTAssertFalse(characteristic.updateValueWithData("aa".dataFromHexString()), "updateValueWithData invalid return status")
            XCTAssertFalse(mock.updateValueCalled, "updateValue called")
            XCTAssertEqual(characteristic.pendingUpdates.count, 1, "pendingUpdates is invalid")
        }
    }

    func testUpdateValueWithData_WithSubscriber_IsSendingUpdates() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssert(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssert(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssert(mock.updateValueCalled, "updateValue not called")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
        }
    }


    func testUpdateValueWithData_WithSubscribers_IsSendingUpdates() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock1 = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        let centralMock2 = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock1)
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock2)
            let centrals = characteristic.subscribers
            let centralIDs = centrals.map { $0.identifier }
            XCTAssert(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssert(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssert(mock.updateValueCalled, "updateValue not called")
            XCTAssertEqual(centrals.count, 2, "characteristic subscriber count invalid")
            XCTAssert(centralIDs.contains(centralMock1.identifier), "invalid central identifier")
            XCTAssert(centralIDs.contains(centralMock2.identifier), "invalid central identifier")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscriberOnUnsubscribe_IsNotSendingUpdates() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            peripheralManager.didUnsubscribeFromCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssertFalse(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssertFalse(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssertFalse(mock.updateValueCalled, "updateValue called")
            XCTAssertEqual(characteristic.subscribers.count, 0, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 1, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscribersWhenOneUnsubscribes_IsSendingUpdates() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock1 = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        let centralMock2 = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock1)
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock2)
            XCTAssertEqual(characteristic.subscribers.count, 2, "characteristic subscriber count invalid")
            peripheralManager.didUnsubscribeFromCharacteristic(characteristic.cbMutableChracteristic, central: centralMock1)
            let centrals = characteristic.subscribers
            XCTAssert(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssert(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssert(mock.updateValueCalled, "updateValue not called")
            XCTAssertEqual(centrals.count, 1, "characteristic subscriber count invalid")
            XCTAssertEqual(centrals[0].identifier, centralMock2.identifier, "invalid central identifier")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscriberWhenUpdateFailes_UpdatesAreSavedToPendingQueue() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value1 = "aa".dataFromHexString()
            let value2 = "bb".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssert(characteristic.isUpdating, "isUpdating not set")
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            mock.updateValueReturn = false
            XCTAssertFalse(characteristic.updateValueWithData(value1), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.updateValueWithData(value2), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.isUpdating, "isUpdating not set")
            XCTAssert(mock.updateValueCalled, "updateValue not called")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscriberWithPendingUpdatesThatResume_PendingUpdatesAreSent() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value1 = "aa".dataFromHexString()
            let value2 = "bb".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssert(characteristic.isUpdating, "isUpdating not set")
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            XCTAssert(characteristic.updateValueWithData("11".dataFromHexString()), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
            mock.updateValueReturn = false
            XCTAssertFalse(characteristic.updateValueWithData(value1), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.updateValueWithData(value2), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
            XCTAssertFalse(characteristic.isUpdating, "isUpdating not set")
            XCTAssert(mock.updateValueCalled, "updateValue not called")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
            mock.updateValueReturn = true
            peripheralManager.isReadyToUpdateSubscribers()
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
            XCTAssert(characteristic.isUpdating, "isUpdating not set")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
        }
    }

    func testupdateValueWithData_WithPendingUpdatesPriorToSubscriber_SEndPensingUpdates() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            expectation.fulfill()
            let characteristic = peripheralManager.characteristics[0]
            let value1 = "aa".dataFromHexString()
            let value2 = "bb".dataFromHexString()
            XCTAssertFalse(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssertFalse(characteristic.updateValueWithData(value1), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.updateValueWithData(value2), "updateValueWithData invalid return status")
            XCTAssertFalse(mock.updateValueCalled, "updateValue called")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
            XCTAssertEqual(characteristic.subscribers.count, 0, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
            XCTAssert(mock.updateValueCalled, "updateValue not called")
        }
    }


    // MARK: Respond to write requests
    func testStartRespondingToWriteRequests_WhenRequestIsRecieved_CompletesSuccessfullyAndResponds() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            let requestMock = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: value)
            let future = characteristic.startRespondingToWriteRequests()
            future.onSuccess {(request, central) in
                expectation.fulfill()
                characteristic.respondToRequest(request, withResult: CBATTError.Success)
                XCTAssertEqual(centralMock.identifier, central.identifier, "invalid central identifier")
                XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID, "characteristic UUID invalid")
                XCTAssertEqual(peripheralManager.result, CBATTError.Success, "result is invalid")
                XCTAssertEqual(request.value, value, "request value is invalid")
                XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
            }
            future.onFailure {error in
                XCTFail("onFailure called")
            }
            peripheralManager.didReceiveWriteRequest(requestMock, central: centralMock)
        }
    }

    func testStartRespondingToWriteRequests_WhenMultipleRequestsAreReceived_CompletesSuccessfullyAndRespondstoAll() {
        let expectation = expectationWithDescription("onSuccess fulfilled for future")
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        var writeCount = 0
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let values = ["aa".dataFromHexString(), "a1".dataFromHexString(), "a2".dataFromHexString(), "a3".dataFromHexString(), "a4".dataFromHexString(), "a5".dataFromHexString()]
            let requestMocks = values.map { CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: $0) }
            let future = characteristic.startRespondingToWriteRequests()
            future.onSuccess {(request, central) in
                if writeCount == 0 {
                    expectation.fulfill()
                }
                characteristic.respondToRequest(request, withResult: CBATTError.Success)
                XCTAssertEqual(centralMock.identifier, central.identifier, "invalid central identifier")
                XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID, "characteristic UUID invalid")
                XCTAssertEqual(peripheralManager.result, CBATTError.Success, "result is invalid")
                XCTAssertEqual(request.value, values[writeCount], "request value is invalid")
                XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
                writeCount += 1
            }
            future.onFailure {error in
                XCTFail("onFailure called")
            }
            for requestMock in requestMocks {
                peripheralManager.didReceiveWriteRequest(requestMock, central: centralMock)
            }
        }
    }

    func testStartRespondingToWriteRequests_WhenNotCalled_RespondsToRequestWithRequestNotSupported() {
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: value)
            peripheralManager.didReceiveWriteRequest(request, central: centralMock)
            XCTAssertEqual(peripheralManager.result, CBATTError.RequestNotSupported, "result is invalid")
            XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
        }
    }

    func testStartRespondingToWriteRequests_WhenNotCalledAndCharacteristicNotAddedToService_RespondsToRequestWithUnlikelyError() {
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        let (_, peripheralManager) = createPeripheralManager(false, state: .PoweredOn)
        let characteristic = BCMutableCharacteristic(profile: BCStringCharacteristicProfile<Gnosus.HelloWorldService.Greeting>())
        let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: nil)
        let value = "aa".dataFromHexString()
        characteristic.value = value
        peripheralManager.didReceiveWriteRequest(request, central: centralMock)
        XCTAssertEqual(request.value, nil, "value is invalid")
        XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
        XCTAssertEqual(peripheralManager.result, CBATTError.UnlikelyError, "result is invalid")
    }

    func testStopRespondingToWriteRequests_WhenRespondingToWriteRequests_StopsRespondingToWriteRequests() {
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: value)
            let future = characteristic.startRespondingToWriteRequests()
            characteristic.stopRespondingToWriteRequests()
            future.onSuccess {_ in
                XCTFail("onSuccess called")
            }
            future.onFailure {error in
                XCTFail("onFailure called")
            }
            peripheralManager.didReceiveWriteRequest(request, central: centralMock)
            XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
            XCTAssertEqual(peripheralManager.result, CBATTError.RequestNotSupported, "result is invalid")
        }
    }

    // MARK: Respond to read requests
    func testDidReceiveReadRequest_WhenCharacteristicIsInService_RespondsToRequest() {
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: BCMutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: nil)
            let value = "aa".dataFromHexString()
            characteristic.value = value
            peripheralManager.didReceiveReadRequest(request, central: centralMock)
            XCTAssertEqual(request.value, value, "value is invalid")
            XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
            XCTAssertEqual(peripheralManager.result, CBATTError.Success, "result is invalid")
        }
    }
    
    func testDidReceiveReadRequest_WhenCharacteristicIsNotInService_RespondsWithUnlikelyError() {
        let centralMock = CBCentralMock(identifier: NSUUID(), maximumUpdateValueLength: 20)
        let (_, peripheralManager) = createPeripheralManager(false, state: .PoweredOn)
        let characteristic = BCMutableCharacteristic(profile: BCStringCharacteristicProfile<Gnosus.HelloWorldService.Greeting>())
        let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: nil)
        let value = "aa".dataFromHexString()
        characteristic.value = value
        peripheralManager.didReceiveReadRequest(request, central: centralMock)
        XCTAssertEqual(request.value, nil, "value is invalid")
        XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
        XCTAssertEqual(peripheralManager.result, CBATTError.UnlikelyError, "result is invalid")
    }

}
