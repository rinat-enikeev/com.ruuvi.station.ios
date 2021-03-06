import Foundation

protocol DashboardRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover()
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openTagSettings(ruuviTag: RuuviTagRealm, humidity: Double?)
}
