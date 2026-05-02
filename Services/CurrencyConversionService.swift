import Foundation

enum CurrencyConversionService {
    enum ConversionError: Error {
        case rateNotFound
        case networkFailure
    }

    static func fetchRate(from fromCode: String, to toCode: String) async throws -> Double {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(fromCode.uppercased())") else {
            throw ConversionError.networkFailure
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(RateResponse.self, from: data)
        guard let rate = response.rates[toCode.uppercased()] else {
            throw ConversionError.rateNotFound
        }
        return rate
    }

    private struct RateResponse: Decodable {
        let rates: [String: Double]
    }
}
