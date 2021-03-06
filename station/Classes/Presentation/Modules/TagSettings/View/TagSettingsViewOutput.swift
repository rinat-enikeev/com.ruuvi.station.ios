import UIKit

protocol TagSettingsViewOutput {
    func viewDidAskToDismiss()
    func viewDidAskToRandomizeBackground()
    func viewDidAskToRemoveRuuviTag()
    func viewDidConfirmTagRemoval()
    func viewDidAskToCalibrateHumidity()
    func viewDidChangeTag(name: String)
    func viewDidAskToSelectBackground(sourceView: UIView)
    func viewDidTapOnMacAddress()
    func viewDidTapOnUUID()
    func viewDidAskToLearnMoreAboutFirmwareUpdate()
    func viewDidTapOnTxPower()
    func viewDidTapOnMovementCounter()
    func viewDidTapOnMeasurementSequenceNumber()
    func viewDidTapOnNoValuesView()
    func viewDidTapOnHumidityAccessoryButton()
    func viewDidAskToFixHumidityAdjustment()
}
