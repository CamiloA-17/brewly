import BrewlyDomain
import SwiftUI

/// Birth date form row: an "Add" button until a date is chosen, then a date picker limited to past days.
public struct BirthDateField: View {
    @Binding private var date: CalendarDate?

    public init(date: Binding<CalendarDate?>) {
        _date = date
    }

    public var body: some View {
        if let date {
            DatePicker(
                selection: Binding(
                    get: { date.date(in: .current) },
                    set: { self.date = CalendarDate(date: $0) }
                ),
                in: AccountRules.earliestBirthDate.date(in: .current)...Date(),
                displayedComponents: .date
            ) {
                Text("Birth date", bundle: .module)
            }
        } else {
            LabeledContent {
                Button {
                    let today = CalendarDate.today()
                    self.date = CalendarDate(year: today.year - 25, month: 1, day: 1)
                } label: {
                    Text("Add", bundle: .module)
                }
            } label: {
                Text("Birth date", bundle: .module)
            }
        }
    }
}

/// Country of residence, from every ISO region, sorted by its name in the user's language.
public struct CountryPicker: View {
    @Binding private var code: String?

    public init(code: Binding<String?>) {
        _code = code
    }

    public var body: some View {
        Picker(selection: $code) {
            Text("Not set", bundle: .module).tag(String?.none)
            ForEach(Self.countries, id: \.code) { country in
                Text(country.name).tag(Optional(country.code))
            }
        } label: {
            Text("Country", bundle: .module)
        }
        .pickerStyle(.navigationLink)
    }

    private static let countries: [(code: String, name: String)] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { AccountRules.isValidCountryCode($0) && $0 != "ZZ" }
        .compactMap { code in Locale.current.localizedString(forRegionCode: code).map { (code: code, name: $0) } }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

/// "City, Country" for a member's profile, or whichever part is set.
public func memberPlace(city: String?, countryCode: String?) -> String? {
    let country = countryCode.flatMap { Locale.current.localizedString(forRegionCode: $0) }
    let parts = [city, country].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
}
