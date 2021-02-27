// https://bugs.swift.org/browse/SR-8458
extension Never: Codable {
    public init(from decoder: Decoder) throws {
        fatalError("Cannot construct Never")
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("Should not have constructed Never")
    }
}
