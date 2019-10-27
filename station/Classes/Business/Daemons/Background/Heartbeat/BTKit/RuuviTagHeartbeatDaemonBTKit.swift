import Foundation
import BTKit
import RealmSwift

class RuuviTagHeartbeatDaemonBTKit: BackgroundWorker, RuuviTagHeartbeatDaemon {
    
    var background: BTBackground!
    var localNotificationsManager: LocalNotificationsManager!
    var connectionPersistence: ConnectionPersistence!
    var ruuviTagPersistence: RuuviTagPersistence!
    
    private var realm: Realm!
    private var ruuviTags: Results<RuuviTagRealm>?
    private var connectTokens = [String: ObservationToken]()
    private var disconnectTokens = [String: ObservationToken]()
    private var connectionAddedToken: NSObjectProtocol?
    private var connectionRemovedToken: NSObjectProtocol?
    private var savedDate = [String: Date]() // uuid:date
    lazy var syncLogsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    @objc private class RuuviTagHeartbeatDaemonPair: NSObject {
        var uuid: String
        var device: RuuviTag
        
        init(uuid: String, device: RuuviTag) {
            self.uuid = uuid
            self.device = device
        }
    }
    
    override init() {
        super.init()
        connectionAddedToken = NotificationCenter.default.addObserver(forName: .ConnectionPersistenceDidStartToKeepConnection, object: nil, queue: .main, using: { [weak self] (notification) in
            guard let sSelf = self else { return }
            if let userInfo = notification.userInfo, let uuid = userInfo[ConnectionPersistenceDidStartToKeepConnectionKey.uuid] as? String {
                sSelf.perform(#selector(RuuviTagHeartbeatDaemonBTKit.connect(uuid:)),
                on: sSelf.thread,
                with: uuid,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
            }
        })
        
        connectionRemovedToken = NotificationCenter.default.addObserver(forName: .ConnectionPersistenceDidStopToKeepConnection, object: nil, queue: .main, using: { [weak self] (notification) in
            guard let sSelf = self else { return }
            if let userInfo = notification.userInfo, let uuid = userInfo[ConnectionPersistenceDidStopToKeepConnectionKey.uuid] as? String {
                sSelf.perform(#selector(RuuviTagHeartbeatDaemonBTKit.disconnect(uuid:)),
                on: sSelf.thread,
                with: uuid,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
            }
        })
    }
    
    deinit {
        invalidateTokens()
        if let connectionAddedToken = connectionAddedToken {
            NotificationCenter.default.removeObserver(connectionAddedToken)
        }
        if let connectionRemovedToken = connectionRemovedToken {
            NotificationCenter.default.removeObserver(connectionRemovedToken)
        }
    }
    
    func start() {
        start { [weak self] in
            self?.realm = try! Realm()
            self?.ruuviTags = self?.realm.objects(RuuviTagRealm.self).filter("isConnectable == true")
            self?.invalidateTokens()
            self?.connectionPersistence.keepConnectionUUIDs.forEach({ self?.connect(uuid: $0)})
        }
    }
    
    func stop() {
        invalidateTokens()
        connectionPersistence.keepConnectionUUIDs.forEach({ disconnect(uuid: $0) })
        stopWork()
    }
    
    @objc private func connect(uuid: String) {
        disconnectTokens[uuid]?.invalidate()
        connectTokens[uuid] = background.connect(for: self, uuid: uuid, options: [.callbackQueue(.untouch)], connected: { (observer, result) in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagHeartbeatDaemonDidFail, object: nil, userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: RUError.btkit(error)])
                }
            case .disconnected:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    DispatchQueue.main.async { [weak observer] in
                        observer?.localNotificationsManager.showDidDisconnect(uuid: uuid)
                    }
                }
            case .already:
                break // do nothing
            case .just:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    DispatchQueue.main.async { [weak observer] in
                        observer?.localNotificationsManager.showDidConnect(uuid: uuid)
                    }
                }
                if observer.connectionPersistence.syncLogsOnDidConnect(uuid: uuid) {
                    observer.perform(#selector(RuuviTagHeartbeatDaemonBTKit.syncLogs(_:)),
                    on: observer.thread,
                    with: uuid,
                    waitUntilDone: false,
                    modes: [RunLoop.Mode.default.rawValue])
                }
            }
        }, heartbeat: { observer, device in
            if let ruuviTag = device.ruuvi?.tag,
                observer.connectionPersistence.saveHeartbeats(uuid: ruuviTag.uuid) {
                let uuid = ruuviTag.uuid
                let interval = observer.connectionPersistence.saveHeartbeatsInterval(uuid: uuid)
                if let date = observer.savedDate[uuid] {
                    if Date().timeIntervalSince(date) > TimeInterval(interval * 60) {
                        let pair = RuuviTagHeartbeatDaemonPair(uuid: uuid, device: ruuviTag)
                        observer.perform(#selector(RuuviTagHeartbeatDaemonBTKit.persist(_:)),
                        on: observer.thread,
                        with: pair,
                        waitUntilDone: false,
                        modes: [RunLoop.Mode.default.rawValue])
                        observer.savedDate[uuid] = Date()
                        
                    }
                } else {
                    let pair = RuuviTagHeartbeatDaemonPair(uuid: uuid, device: ruuviTag)
                    observer.perform(#selector(RuuviTagHeartbeatDaemonBTKit.persist(_:)),
                    on: observer.thread,
                    with: pair,
                    waitUntilDone: false,
                    modes: [RunLoop.Mode.default.rawValue])
                    observer.savedDate[uuid] = Date()
                }
            }
        }, disconnected: { observer, result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagHeartbeatDaemonDidFail, object: nil, userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: RUError.btkit(error)])
                }
            case .stillConnected:
                break // do nothing
            case .already:
                break // do nothing
            case .just:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    DispatchQueue.main.async { [weak observer] in
                        observer?.localNotificationsManager.showDidDisconnect(uuid: uuid)
                    }
                    
                }
            }
        })
    }
    
    @objc private func disconnect(uuid: String) {
        connectTokens[uuid]?.invalidate()
        disconnectTokens[uuid] = background.disconnect(for: self, uuid: uuid, options: [.callbackQueue(.untouch)], result: { (observer, result) in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagHeartbeatDaemonDidFail, object: nil, userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: RUError.btkit(error)])
                }
            case .just:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    DispatchQueue.main.async {
                        observer.localNotificationsManager.showDidDisconnect(uuid: uuid)
                    }
                }
            case .already:
                break // do nothing
            case .stillConnected:
                break // do nothing
            }
        })
    }
    
    @objc private func persist(_ pair: RuuviTagHeartbeatDaemonPair) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == pair.device.uuid }) {
            let ruuviTagData = RuuviTagDataRealm(ruuviTag: ruuviTag, data: pair.device)
            ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm)
                .on( failure: { error in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagHeartbeatDaemonDidFail, object: nil, userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: error])
                }
            })
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .RuuviTagHeartbeatDaemonDidFail, object: nil, userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: RUError.unexpected(.failedToFindRuuviTag)])
            }
        }
    }
    
    @objc private func syncLogs(_ uuid: String) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == uuid }) {
            let operation = RuuviTagReadLogsOperation(ruuviTagPersistence: ruuviTagPersistence, logSyncDate: ruuviTag.logSyncDate, uuid: uuid, background: background)
            syncLogsQueue.addOperation(operation)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .RuuviTagHeartbeatDaemonDidFail, object: nil, userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: RUError.unexpected(.failedToFindRuuviTag)])
            }
        }
    }
    
    private func invalidateTokens() {
        connectTokens.values.forEach({ $0.invalidate() })
        connectTokens.removeAll()
        disconnectTokens.values.forEach({ $0.invalidate() })
        disconnectTokens.removeAll()
    }
}