import Foundation

protocol WebTagSettingsViewInput: ViewInput {
    var viewModel: WebTagSettingsViewModel { get set }
    
    func showTagRemovalConfirmationDialog()
    func showClearLocationConfirmationDialog()
}