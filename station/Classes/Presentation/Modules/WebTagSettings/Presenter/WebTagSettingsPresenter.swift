import UIKit

class WebTagSettingsPresenter: WebTagSettingsModuleInput {
    weak var view: WebTagSettingsViewInput!
    var router: WebTagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var errorPresenter: ErrorPresenter!
    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet {
            photoPickerPresenter.delegate = self
        }
    }
    
    private var webTag: WebTagRealm! {
        didSet {
            syncViewModel()
        }
    }
    
    func configure(webTag: WebTagRealm) {
        self.webTag = webTag
    }
}

// MARK: - WebTagSettingsViewOutput
extension WebTagSettingsPresenter: WebTagSettingsViewOutput {
    func viewDidAskToDismiss() {
        router.dismiss()
    }
    
    func viewDidAskToRandomizeBackground() {
        view.viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: webTag.uuid)
    }
    
    func viewDidAskToSelectBackground() {
        photoPickerPresenter.pick()
    }
}

// MARK: - PhotoPickerPresenterDelegate
extension WebTagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        let set = backgroundPersistence.setCustomBackground(image: photo, for: webTag.uuid)
        set.on(success: { [weak self] _ in
            self?.view.viewModel.background.value = photo
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - Private
extension WebTagSettingsPresenter {
    private func syncViewModel() {
        view.viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)
        
        if webTag.name == webTag.provider.displayName {
            view.viewModel.name.value = nil
        } else {
            view.viewModel.name.value = webTag.name
        }

        view.viewModel.uuid.value = webTag.uuid
    }
}
