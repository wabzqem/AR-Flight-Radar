//
//  Aeroplane.swift
//  AR Flight Radar
//
//  Created by Richard Nelson on 24/9/21.
//

import Foundation

struct Aeroplane {
    var id: String
    var lat: Float
    var lon: Float
    var call: String
    var altitude: Int
    var heading: Int
    var source: String
    var destination: String
}

struct FlightRadarResponse: Decodable {
    var aircraft: [Aeroplane]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var planes: [Aeroplane] = []
        for key in container.allKeys {
            let planeData = try? container.decode(RawAircraftData.self, forKey: key)
            if let planeData = planeData?.data {
                let a = Aeroplane(id: key.stringValue, lat: planeData[1].floatValue(), lon: planeData[2].floatValue(), call: planeData[13].stringValue(), altitude: planeData[4].intValue(), heading: planeData[3].intValue(), source: planeData[11].stringValue(), destination: planeData[12].stringValue())
                planes.append(a)
            }
        }
        aircraft = planes
    }
    
    struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = ""
        }
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
    }
}

struct RawAircraftData: Decodable {
    var data: [StringOrIntType] = []
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while (!container.isAtEnd) {
            do {
                let item = try container.decode(StringOrIntType.self)
                data.append(item)
            } catch {
                print("Couldn't decode item at \(container.currentIndex)")
            }
        }
    }
}

enum StringOrIntType: Codable {
    case string(String)
    case int(Int)
    case float(Float)
    
    func floatValue() -> Float {
        switch self {
        case .float(let float):
            return float
        case .string(_):
            return 0
        case .int(_):
            return 0
        }
    }
    
    func stringValue() -> String {
        switch self {
        case .float(_):
            return ""
        case .string(let string):
            return string
        case .int(_):
            return ""
        }
    }
    
    func intValue() -> Int {
        switch self {
        case .float(let float):
            return Int(float)
        case .string( _):
            return 0
        case .int(let int):
            return int
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self = try .string(container.decode(String.self))
        } catch {
            do {
                self = try .int(container.decode(Int.self))
            } catch {
                do {
                    self = try .float(container.decode(Float.self))
                } catch {
                    throw DecodingError.typeMismatch(StringOrIntType.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Encoded payload not of an expected type"))
                }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .float(let float):
            try container.encode(float)
        case .int(let int):
            try container.encode(int)
        case .string(let string):
            try container.encode(string)
        }
    }
}
