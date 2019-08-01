import Foundation
import Future

class WPSObservationToken {
    private let cancellationClosure: () -> Void
    
    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }
    
    public func invalidate() {
        cancellationClosure()
    }
}

struct WPSData {
    var celsius: Double?
    var humidity: Double?
    var pressure: Double?
    
    var fahrenheit: Double? {
        if let celsius = celsius {
            return (celsius * 9.0/5.0) + 32.0
        } else {
            return nil
        }
    }
}

protocol WeatherProviderService {
    func loadCurrentLocationData(from provider: WeatherProvider) -> Future<WPSData,RUError>
    
    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T, provider: WeatherProvider, interval: TimeInterval, closure: @escaping (T, WPSData?, RUError?) -> Void) -> WPSObservationToken
}
