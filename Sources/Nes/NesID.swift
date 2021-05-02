enum NesID: Equatable {
    case stringId(_ id: String)
    case numberId(_ id: Double)
}

extension NesID: Codable {
    enum CodingKeys: CodingKey {
        case stringId
        case numberId
    }
    
    init(string: String) {
        self = .stringId(string)
    }
    
    init(number: Double) {
        self = .numberId(number)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let id = try? container.decode(String.self) {
            self = .stringId(id)
        } else if let id = try? container.decode(Double.self) {
            self = .numberId(id)
        } else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a string or number.")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .stringId(let id):
            try container.encode(id)
        case .numberId(let id):
            try container.encode(id)
        }
    }
}
