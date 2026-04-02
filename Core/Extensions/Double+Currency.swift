import Foundation

extension Double {
    func formattedCurrency(code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code

        if code == "NOK" {
            formatter.locale = Locale(identifier: "nb_NO")
        } else {
            formatter.locale = .current
        }

        formatter.maximumFractionDigits = self.rounded() == self ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

