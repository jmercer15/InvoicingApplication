import Combine
import SwiftUI
import Observation

@Observable
/// Formats and validates Australian phone numbers as the user types.
public class PhoneNumberFormatter {
    public var phoneNumber: String = "" {
        didSet(oldValue) {
            let currentValue = phoneNumber
            var pureNationalDigits = self.extractPureNationalDigits(from: currentValue)
            let maxLength = self.determineMaxLength(forPureDigits: pureNationalDigits)
            if pureNationalDigits.count > maxLength {
                pureNationalDigits = String(pureNationalDigits.prefix(maxLength))
            }
            let formattedNumber = self.formatPhoneNumber(pureNationalDigits)

            let isDeletion = phoneNumber.count < oldValue.count

            if currentValue != formattedNumber {
                if !isDeletion {
                    self.phoneNumber = formattedNumber
                }
            }

            validate(rawDigits: pureNationalDigits)
        }
    }
    
    public var isValid: Bool = false
    public var validationMessage: String? = nil

    public init(initialPhoneNumber: String = "") {
        var processedText = initialPhoneNumber
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        processedText = processedText.replacingOccurrences(of: " ", with: "")

        if processedText.hasPrefix("+61") {
            var nationalPart = String(processedText.dropFirst(3))
            if !nationalPart.hasPrefix("0") {
                let nationalDigitsOnly = nationalPart.filter { $0.isNumber }
                if nationalDigitsOnly.count == 9 && (nationalDigitsOnly.first == "2" || nationalDigitsOnly.first == "3" || nationalDigitsOnly.first == "4" || nationalDigitsOnly.first == "7" || nationalDigitsOnly.first == "8") {
                     nationalPart = "0" + nationalDigitsOnly
                } else {
                     nationalPart = nationalDigitsOnly
                }
            } else {
                 nationalPart = nationalPart.filter { $0.isNumber }
            }
            processedText = nationalPart
        } else if processedText.hasPrefix("+") {
            processedText = String(processedText.dropFirst()).filter { $0.isNumber }
        } else {
            processedText = processedText.filter { $0.isNumber }
        }
        
        let currentRawDigitsUnfiltered = processedText
        let maxLength: Int
        if currentRawDigitsUnfiltered.hasPrefix("13") && !currentRawDigitsUnfiltered.hasPrefix("1300") {
            maxLength = 6
        } else if currentRawDigitsUnfiltered == "000" {
            maxLength = 3
        }
        else {
            maxLength = 10
        }
        let initialRawDigits = String(currentRawDigitsUnfiltered.prefix(maxLength))
        
        let formattedInitial = formatPhoneNumber(initialRawDigits)
        self.phoneNumber = formattedInitial
        validate(rawDigits: initialRawDigits)
    }

    private func formatPhoneNumber(_ digits: String) -> String {

        if digits.isEmpty {
            return ""
        }

        if digits.hasPrefix("000") {
            if digits.count <= 3 {
                return digits
            }
            let prefixVal = String(digits.prefix(3))
            return prefixVal
        }

        if digits.hasPrefix("13") && !digits.hasPrefix("1300") {
            let d = String(digits.prefix(6)) 
            var result = ""
            if d.count <= 2 { result = d } 
            else if d.count <= 4 { result = "\(d.prefix(2)) \(d.dropFirst(2))" } 
            else { result = "\(d.prefix(2)) \(d.dropFirst(2).prefix(2)) \(d.dropFirst(4))" } 
            return result
        }

        if digits.hasPrefix("1300") || digits.hasPrefix("1800") {
            let d = String(digits.prefix(10)) 
            var result = ""
            if d.count <= 4 { result = d } 
            else if d.count <= 7 { result = "\(d.prefix(4)) \(d.dropFirst(4))" } 
            else { result = "\(d.prefix(4)) \(d.dropFirst(4).prefix(3)) \(d.dropFirst(7))" } 
            return result
        }

        if digits.hasPrefix("04") {
            let d = String(digits.prefix(10)) 
            var result = ""
            if d.count <= 4 { result = d } 
            else if d.count <= 7 { result = "\(d.prefix(4)) \(d.dropFirst(4))" } 
            else { result = "\(d.prefix(4)) \(d.dropFirst(4).prefix(3)) \(d.dropFirst(7))" } 
            return result
        }

        if digits.hasPrefix("02") || digits.hasPrefix("03") || digits.hasPrefix("07") || digits.hasPrefix("08") {
            let d = String(digits.prefix(10)) 
            var result = ""

            if d.isEmpty {
                return ""
            } 

            if d.count == 1 { 
                result = "(0"
            } else if d.count == 2 { 
                result = "(\(d))" 
            } else {
                let areaCode = d.prefix(2) 
                let subscriberPart = d.dropFirst(2)

                if d.count <= 6 { 
                    result = "(\(areaCode)) \(subscriberPart)" 
                } else {
                    let firstHalfSubscriber = subscriberPart.prefix(4)
                    let secondHalfSubscriber = subscriberPart.dropFirst(4)
                    result = "(\(areaCode)) \(firstHalfSubscriber) \(secondHalfSubscriber)" 
                }
            }
            return result
        }
        
        if digits == "0" {
             return "(0" 
        }

        return digits
    }

    private func validate(rawDigits: String) {
        var isValidFormat = false
        var message: String? = nil
        let digitCount = rawDigits.count

        if rawDigits.isEmpty {
            self.isValid = true 
            self.validationMessage = nil
            return
        }

        if rawDigits.hasPrefix("04") {
            if digitCount == 10 { isValidFormat = true }
            else { message = "Mobile numbers (04xx) must be 10 digits." }
        } else if rawDigits.hasPrefix("02") || rawDigits.hasPrefix("03") || rawDigits.hasPrefix("07") || rawDigits.hasPrefix("08") {
            if digitCount == 10 { isValidFormat = true }
            else { message = "Landline numbers (0x) must be 10 digits." }
        } else if rawDigits.hasPrefix("1300") || rawDigits.hasPrefix("1800") {
            if digitCount == 10 { isValidFormat = true }
            else { message = "1300/1800 numbers must be 10 digits." }
        } else if rawDigits.hasPrefix("13") { 
            if digitCount == 6 { isValidFormat = true }
            else { message = "13 numbers must be 6 digits." }
        } else if rawDigits == "000" {
            isValidFormat = true 
        } else {
            if digitCount < 3 && (rawDigits.hasPrefix("0") || rawDigits.hasPrefix("1")) { 
                 message = "Phone number is incomplete." 
            } else if digitCount < 6 && !rawDigits.isEmpty {
                 message = "Phone number is too short for most types."
            } else if (digitCount > 6 && digitCount < 10) && !(rawDigits.hasPrefix("0") || rawDigits.hasPrefix("1")) {
                message = "Phone number is incomplete."
            } else if !rawDigits.allSatisfy({$0.isNumber}) { 
                message = "Phone number contains invalid characters."
            } else {
                 message = "Enter a valid Australian phone number."
            }
        }

        var allCharactersAreSame = false
        if isValidFormat && digitCount > 2 && rawDigits != "000" {
            allCharactersAreSame = Set(rawDigits).count == 1
        }

        if allCharactersAreSame {
            self.isValid = false
            self.validationMessage = "Phone number cannot have all identical digits."
        } else if isValidFormat {
            self.isValid = true
            self.validationMessage = nil
        } else {
            self.isValid = false
            self.validationMessage = message ?? "Invalid phone number."
        }
    }
    
    // digitsOnly property removed - public property is shadowed by a private method used internally

    private func extractPureNationalDigits(from text: String) -> String {
        var processedText = text
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        processedText = processedText.replacingOccurrences(of: " ", with: "")

        if processedText.hasPrefix("+61") {
            var nationalPart = String(processedText.dropFirst(3)) 
            if !nationalPart.hasPrefix("0") { 
                let nationalDigitsOnly = nationalPart.filter { $0.isNumber }
                if nationalDigitsOnly.count == 9 &&
                   (nationalDigitsOnly.first == "2" || nationalDigitsOnly.first == "3" ||
                    nationalDigitsOnly.first == "4" || nationalDigitsOnly.first == "7" ||
                    nationalDigitsOnly.first == "8") {
                     nationalPart = "0" + nationalDigitsOnly
                } else {
                    nationalPart = nationalDigitsOnly
                }
            } else { 
                 nationalPart = nationalPart.filter { $0.isNumber } 
            }
            processedText = nationalPart
        } else if processedText.hasPrefix("+") {
            processedText = String(processedText.dropFirst()).filter { $0.isNumber }
        } else {
            processedText = processedText.filter { $0.isNumber }
        }
        return processedText 
    }

    private func determineMaxLength(forPureDigits digits: String) -> Int {
        var length: Int
        if digits.hasPrefix("13") && !digits.hasPrefix("1300") {
            length = 6 
        } else if digits == "000" { 
            length = 3
        } else if digits.hasPrefix("04") {
            length = 10
        } else if digits.hasPrefix("02") || digits.hasPrefix("03") || digits.hasPrefix("07") || digits.hasPrefix("08") {
            length = 10
        } else if digits.hasPrefix("1300") || digits.hasPrefix("1800") {
            length = 10
        } else {
            length = 10 
        }
        return length
    }
}
