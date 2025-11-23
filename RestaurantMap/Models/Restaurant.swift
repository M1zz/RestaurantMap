import Foundation
import SwiftData
import MapKit

@Model
final class Restaurant {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var notes: String
    var rating: Int
    var visitDate: Date
    var category: String
    var phoneNumber: String
    
    init(name: String, address: String, latitude: Double, longitude: Double, notes: String = "", rating: Int = 0, visitDate: Date = Date(), category: String = "", phoneNumber: String = "") {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.rating = rating
        self.visitDate = visitDate
        self.category = category
        self.phoneNumber = phoneNumber
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
