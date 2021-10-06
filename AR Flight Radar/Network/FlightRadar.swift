//
//  FlightRadar.swift
//  AR Flight Radar
//
//  Created by Richard Nelson on 24/9/21.
//

import Foundation

class AeroplaneData {
    func getRealtimePositioning(callSign: String, completion: @escaping ([Aeroplane]) -> Void) {
        URLSession.shared.dataTask(with: URL(string: "https://data-live.flightradar24.com/zones/fcgi/feed.js?faa=1&satellite=1&mlat=1&flarm=1&adsb=1&gnd=1&air=1&vehicles=1&estimated=1&maxage=14400&gliders=1&callsign=\(callSign)&pk=&stats=0")!) { data, response, error in
            
            guard let data = data else { return }
            do {
                let res = try JSONDecoder().decode(FlightRadarResponse.self, from: data)
                completion(res.aircraft)
            } catch {
                print("Couldn't decode JSON")
            }
        }.resume()
    }
    
    func getFlightInfo(plane: Aeroplane, completion: @escaping (FlightData) -> Void) {
        URLSession.shared.dataTask(with: URL(string: "https://data-live.flightradar24.com/clickhandler/?version=1.5&flight=\(plane.id)")!) { data, response, error in
            guard let data = data else { return }
            do {
                let res = try JSONDecoder().decode(FlightData.self, from: data)
                completion(res)
            } catch let error {
                print("Couldn't decode JSON: \(error)")
            }
        }.resume()
    }
}

struct FlightData: Decodable {
    struct Aircraft: Decodable {
        struct model {
            var code: String
            var text: String
        }
        var registration: String
    }
    struct Time: Decodable {
        var scheduled: PlaneTime
        var real: PlaneTime
        var estimated: PlaneTime
    }
    struct AirportInformation: Decodable {
        var origin: Airport
        var destination: Airport
    }
    struct Identification: Decodable {
        struct IdentificationNumber: Decodable {
            var `default`: String
        }
        var number: IdentificationNumber
    }
    var identification: Identification
    var aircraft: Aircraft
    var time: Time
    var airport: AirportInformation
    var trail: [PlaneTrail]
}

struct PlaneTrail: Decodable {
    var lat: Float
    var lng: Float
    var alt: Int
    var spd: Int
    var ts: Double
    var hd: Int
}

struct PlaneTime: Decodable {
    var departure: Double?
    var arrival: Double?
}

struct Airport: Decodable {
    var name: String
    var code: Code
    var position: Position
    var timezone: Timezone
    struct Code: Decodable {
        var iata: String
        var icao: String
    }
    struct Position: Decodable {
        var latitude: Float
        var longitude: Float
    }
    struct Timezone: Decodable {
        var offset: Double
        var name: String
    }
}
