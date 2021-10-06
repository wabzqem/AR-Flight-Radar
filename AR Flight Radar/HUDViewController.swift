//
//  HUDViewController.swift
//  AR Flight Radar
//
//  Created by Richard Nelson on 2/10/21.
//

import Foundation
import ARKit

class HUDViewController: UIViewController {
    @IBOutlet weak private var flightNumberLabel: UILabel?
    @IBOutlet weak private var flightDestinationLabel: UILabel?
    @IBOutlet weak private var flightSpeedLabel: UILabel?
    @IBOutlet weak private var flightAltitubeLabel: UILabel?
    @IBOutlet weak private var flightArrivalLabel: UILabel?
    
    func setData(status: FlightData) {
        let arrival = Date(timeIntervalSince1970: status.time.estimated.arrival ?? 0)
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: status.airport.destination.timezone.name)
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short
        self.flightNumberLabel?.text = "\(status.identification.number.default)"
        self.flightDestinationLabel?.text = "\(status.airport.origin.code.iata)✈️\(status.airport.destination.code.iata)"
        self.flightSpeedLabel?.text = "Speed: \(status.trail.first?.spd ?? 0)knts"
        self.flightAltitubeLabel?.text = "Altitude: \(status.trail.first?.alt ?? 0)ft"
        self.flightArrivalLabel?.text = "\(status.airport.destination.code.iata) arrival: \(dateFormatter.string(from: arrival))"
    }
}
