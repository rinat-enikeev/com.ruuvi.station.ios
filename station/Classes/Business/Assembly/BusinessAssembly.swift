import Swinject
import BTKit

class BusinessAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(AppStateService.self) { r in
            let service = AppStateServiceImpl()
            service.ruuviTagDaemon = r.resolve(RuuviTagDaemon.self)
            return service
        }.inObjectScope(.container)
        
        container.register(CalibrationService.self) { r in
            let service = CalibrationServiceImpl()
            service.calibrationPersistence = r.resolve(CalibrationPersistence.self)
            service.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return service
        }
        
        container.register(RuuviTagDaemon.self) { r in
            let daemon = RuuviTagDaemonRealmBTKit()
            daemon.scanner = r.resolve(BTScanner.self)
            daemon.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return daemon
        }.inObjectScope(.container)
        
        container.register(MigrationManager.self) { r in
            let manager = MigrationManagerToVIPER()
            manager.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            manager.settings = r.resolve(Settings.self)
            return manager
        }
        
        container.register(RuuviTagService.self) { r in
            let service = RuuviTagServiceImpl()
            service.calibrationService = r.resolve(CalibrationService.self)
            service.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            service.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            return service
        }
    }
}
