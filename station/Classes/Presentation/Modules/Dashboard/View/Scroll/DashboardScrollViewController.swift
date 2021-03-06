import UIKit
import Localize_Swift

class DashboardScrollViewController: UIViewController {
    var output: DashboardViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var viewModels = [DashboardRuuviTagViewModel]() { didSet { updateUIViewModels() }  }
    
    private var views = [DashboardRuuviTagView]()
    private var currentPage: Int {
        return Int(scrollView.contentOffset.x / scrollView.frame.size.width)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - DashboardViewInput
extension DashboardScrollViewController: DashboardViewInput {

    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }

    func showBluetoothDisabled() {
        let alertVC = UIAlertController(title: "Dashboard.BluetoothDisabledAlert.title".localized(), message: "Dashboard.BluetoothDisabledAlert.message".localized(), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
    
    func scroll(to index: Int) {
        let key = "DashboardScrollViewController.hasShownSwipeAlert"
        if viewModels.count > 1 && !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            let alert = UIAlertController(title: "Dashboard.SwipeAlert.title".localized(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
            present(alert, animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let sSelf = self else { return }
            let x: CGFloat = sSelf.scrollView.frame.size.width * CGFloat(index)
            sSelf.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
        }
    }
}

// MARK: - IBActions
extension DashboardScrollViewController {
    @IBAction func settingsButtonTouchUpInside(_ sender: UIButton) {
        if currentPage >= 0 && currentPage < viewModels.count {
            output.viewDidTriggerSettings(for: viewModels[currentPage])
        }
    }
    
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerMenu()
    }
}

// MARK: - View lifecycle
extension DashboardScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        updateUI()
        configureViews()
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let page = CGFloat(currentPage)
        let width = size.width
        coordinator.animate(alongsideTransition: { [weak self] (context) in
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        }) { [weak self] (context) in
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
}

// MARK: - UITextFieldDelegate
extension DashboardScrollViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
                return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        return count <= 30
    }
}

// MARK: - Configure view
extension DashboardScrollViewController {
    private func bind(view: DashboardRuuviTagView, with viewModel: DashboardRuuviTagViewModel) {
        
        view.nameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        
        let temperatureUnit = viewModel.temperatureUnit
        let fahrenheit = viewModel.fahrenheit
        let celsius = viewModel.celsius
        
        let temperatureBlock: ((UILabel,Double?) -> Void) = { [weak temperatureUnit, weak fahrenheit, weak celsius] label, _ in
            if let temperatureUnit = temperatureUnit?.value {
                switch temperatureUnit {
                case .celsius:
                    if let celsius = celsius?.value {
                        label.text = String(format: "%.2f", celsius)
                    } else {
                        label.text = "N/A".localized()
                    }
                case .fahrenheit:
                    if let fahrenheit = fahrenheit?.value {
                        label.text = String(format: "%.2f", fahrenheit)
                    } else {
                        label.text = "N/A".localized()
                    }
                }
            } else {
                label.text = "N/A".localized()
            }
        }
        
        if let temperatureLabel = view.temperatureLabel {
            temperatureLabel.bind(viewModel.celsius, block: temperatureBlock)
            temperatureLabel.bind(viewModel.fahrenheit, block: temperatureBlock)
            
            view.temperatureUnitLabel.bind(viewModel.temperatureUnit) { [unowned temperatureLabel] label, temperatureUnit in
                if let temperatureUnit = temperatureUnit {
                    switch temperatureUnit {
                    case .celsius:
                        label.text = "°C".localized()
                    case .fahrenheit:
                        label.text = "°F".localized()
                    }
                } else {
                    label.text = "N/A".localized()
                }
                temperatureBlock(temperatureLabel, nil)
            }
        }
        
        let hu = viewModel.humidityUnit
        let rh = viewModel.relativeHumidity
        let ah = viewModel.absoluteHumidity
        let ho = viewModel.humidityOffset
        let tu = viewModel.temperatureUnit
        let dc = viewModel.dewPointCelsius
        let df = viewModel.dewPointFahrenheit
        
        let humidityBlock: ((UILabel, Double?) -> Void) = { [weak hu, weak rh, weak ah, weak ho, weak tu, weak dc, weak df] label, _ in
            if let hu = hu?.value {
                switch hu {
                case .percent:
                    if let rh = rh?.value, let ho = ho?.value {
                        let sh = rh + ho
                        if sh <= 100.0 {
                            label.text = String(format: "%.2f", rh + ho) + " " + "%".localized()
                        } else {
                            label.text = String(format: "%.2f", 100.0) + " " + "%".localized()
                        }
                    } else if let rh = rh?.value {
                        label.text = String(format: "%.2f", rh) + " " + "%".localized()
                    } else {
                        label.text = "N/A".localized()
                    }
                case .gm3:
                    if let ah = ah?.value {
                        label.text = String(format: "%.2f", ah) + " " + "g/m³".localized()
                    } else {
                        label.text = "N/A".localized()
                    }
                case .dew:
                    if let tu = tu?.value {
                        switch tu {
                        case .celsius:
                            if let dc = dc?.value {
                                label.text = String(format: "%.2f", dc) + " " + "°C".localized()
                            } else {
                                label.text = "N/A".localized()
                            }
                        case .fahrenheit:
                            if let df = df?.value {
                                label.text = String(format: "%.2f", df) + " " + "°F".localized()
                            } else {
                                label.text = "N/A".localized()
                            }
                        }
                    } else {
                        label.text = "N/A".localized()
                    }
                }
            } else {
                label.text = "N/A".localized()
            }
        }
        
        view.humidityLabel.bind(viewModel.relativeHumidity, block: humidityBlock)
        view.humidityLabel.bind(viewModel.absoluteHumidity, block: humidityBlock)
        view.humidityLabel.bind(viewModel.humidityOffset, block: humidityBlock)
        view.humidityLabel.bind(viewModel.humidityUnit) { label, _ in
            humidityBlock(label, nil)
        }
        view.humidityLabel.bind(viewModel.temperatureUnit) { label, _ in
            humidityBlock(label, nil)
        }
        
        view.pressureLabel.bind(viewModel.pressure) { label, pressure in
            if let pressure = pressure {
                label.text = "\(pressure)" + " " + "hPa".localized()
            } else {
                label.text = "N/A".localized()
            }
        }
        
        view.rssiLabel.bind(viewModel.rssi) { label, rssi in
            if let rssi = rssi {
                label.text = "\(rssi)" + " " + "dBm".localized()
            } else {
                label.text = "N/A".localized()
            }
        }
        view.updatedLabel.bind(viewModel.date) { [weak view] (label, date) in
            if let date = date {
                label.text = date.ruuviAgo
            } else {
                label.text = "N/A".localized()
            }
            view?.updatedAt = date
        }
        
        view.backgroundImage.bind(viewModel.background) { $0.image = $1 }
    }
    
}

// MARK: - View configuration
extension DashboardScrollViewController {
    private func configureViews() {
        configureEdgeGestureRecognozer()
    }
    
    private func configureEdgeGestureRecognozer() {
        let leftScreenEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer()
        leftScreenEdgeGestureRecognizer.cancelsTouchesInView = true
        scrollView.addGestureRecognizer(leftScreenEdgeGestureRecognizer)
        leftScreenEdgeGestureRecognizer.addTarget(menuPresentInteractiveTransition as Any, action:#selector(MenuTablePresentTransitionAnimation.handlePresentMenuLeftScreenEdge(_:)))
        leftScreenEdgeGestureRecognizer.edges = .left
    }
}

// MARK: - Update UI
extension DashboardScrollViewController {
    private func updateUI() {
        updateUIViewModels()
    }
    
    private func updateUIViewModels() {
        if isViewLoaded {
            views.forEach({ $0.removeFromSuperview() })
            views.removeAll()
            
            if viewModels.count > 0 {
                var leftView: UIView = scrollView
                for viewModel in viewModels {
                    let view = Bundle.main.loadNibNamed("DashboardRuuviTagView", owner: self, options: nil)?.first as! DashboardRuuviTagView
                    view.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(view)
                    position(view, leftView)
                    bind(view: view, with: viewModel)
                    views.append(view)
                    leftView = view
                }
                scrollView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .trailing, relatedBy: .equal
                    , toItem: scrollView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
            }
        }
    }
    
    private func position(_ view: DashboardRuuviTagView, _ leftView: UIView) {
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: leftView, attribute: leftView == scrollView ? .leading : .trailing, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: scrollView, attribute: .bottom, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: scrollView, attribute: .width, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: scrollView, attribute: .height, multiplier: 1.0, constant: 0.0))
    }
}
