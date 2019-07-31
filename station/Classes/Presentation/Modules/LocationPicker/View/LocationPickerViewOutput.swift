import Foundation
import CoreLocation

protocol LocationPickerViewOutput {
    func viewDidTriggerDone()
    func viewDidTriggerCancel()
    func viewDidEnterSearchQuery(_ query: String)
    func viewDidLongPressOnMap(at coordinate: CLLocationCoordinate2D)
    func viewDidTriggerCurrentLocation()
}
