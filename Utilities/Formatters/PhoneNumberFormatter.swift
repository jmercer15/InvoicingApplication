import Combine
import SwiftUI

class PhoneNumberFormatter: ObservableObject {
    @Published var phoneNumber: String = "" {
        didSet(oldValue) {
            print("[PNF didSet] Entered. Current phoneNumber: '\(phoneNumber)', oldValue: '\(oldValue)'")
            let currentValue = phoneNumber
            print("[PNF didSet] currentValue captured: '\(currentValue)'")
            var pureNationalDigits = self.extractPureNationalDigits(from: currentValue)
            print("[PNF didSet] pureNationalDigits after extraction: '\(pureNationalDigits)'")
            let maxLength = self.determineMaxLength(forPureDigits: pureNationalDigits)
            print("[PNF didSet] maxLength determined: \(maxLength)")
            if pureNationalDigits.count > maxLength {
                let originalCount = pureNationalDigits.count
                pureNationalDigits = String(pureNationalDigits.prefix(maxLength))
                print("[PNF didSet] pureNationalDigits truncated from \(originalCount) to \(pureNationalDigits.count). Now: '\(pureNationalDigits)'")
            }
            let formattedNumber = self.formatPhoneNumber(pureNationalDigits)
            print("[PNF didSet] formattedNumber after formatPhoneNumber: '\(formattedNumber)'")

            let isDeletion = phoneNumber.count < oldValue.count
            print("[PNF didSet] isDeletion: \(isDeletion) (oldValue.count: \(oldValue.count), phoneNumber.count: \(phoneNumber.count))")

            if currentValue != formattedNumber {
                if !isDeletion {
                    print("[PNF didSet] NOT a deletion AND currentValue ('\(currentValue)') != formattedNumber ('\(formattedNumber)'). Scheduling update.")
                    DispatchQueue.main.async {
                        print("[PNF didSet] DispatchQueue.main.async: Attempting to set self.phoneNumber = '\(formattedNumber)' for non-deletion.")
                        self.phoneNumber = formattedNumber
                        print("[PNF didSet] DispatchQueue.main.async: self.phoneNumber set for non-deletion.")
                    }
                } else {
                    print("[PNF didSet] IS a deletion AND currentValue ('\(currentValue)') != formattedNumber ('\(formattedNumber)'). Honoring deletion, no re-format scheduled.")
                }
            } else {
                print("[PNF didSet] currentValue ('\(currentValue)') == formattedNumber ('\(formattedNumber)'). No re-formatting needed.")
            }
            
            print("[PNF didSet] Calling validate(rawDigits: '\(pureNationalDigits)')")
            validate(rawDigits: pureNationalDigits)
            print("[PNF didSet] Exited.")
        }
    }
    
    @Published var isValid: Bool = false
    @Published var validationMessage: String? = nil

    init(initialPhoneNumber: String = "") {
        print("[PNF init] Entered with initialPhoneNumber: '\(initialPhoneNumber)'")
        var processedText = initialPhoneNumber
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        processedText = processedText.replacingOccurrences(of: " ", with: "")
        print("[PNF init] After removing parens and spaces: '\(processedText)'")

        if processedText.hasPrefix("+61") {
            print("[PNF init] Has prefix +61.")
            var nationalPart = String(processedText.dropFirst(3))
            print("[PNF init] +61 nationalPart initial: '\(nationalPart)'")
            if !nationalPart.hasPrefix("0") {
                let nationalDigitsOnly = nationalPart.filter { $0.isNumber }
                print("[PNF init] +61 nationalPart does not start with 0. nationalDigitsOnly: '\(nationalDigitsOnly)'")
                if nationalDigitsOnly.count == 9 && (nationalDigitsOnly.first == "2" || nationalDigitsOnly.first == "3" || nationalDigitsOnly.first == "4" || nationalDigitsOnly.first == "7" || nationalDigitsOnly.first == "8") {
                     nationalPart = "0" + nationalDigitsOnly
                     print("[PNF init] +61 nationalPart prefixed with 0: '\(nationalPart)'")
                } else {
                     nationalPart = nationalDigitsOnly
                     print("[PNF init] +61 nationalPart unchanged (not 9 digits or not matching prefix): '\(nationalPart)'")
                }
            } else {
                 nationalPart = nationalPart.filter { $0.isNumber }
                 print("[PNF init] +61 nationalPart started with 0. Filtered to digits: '\(nationalPart)'")
            }
            processedText = nationalPart
        } else if processedText.hasPrefix("+") {
            print("[PNF init] Has prefix + but not +61.")
            processedText = String(processedText.dropFirst()).filter { $0.isNumber }
            print("[PNF init] After dropping + and filtering digits: '\(processedText)'")
        } else {
            print("[PNF init] No + prefix.")
            processedText = processedText.filter { $0.isNumber }
            print("[PNF init] Filtered to digits: '\(processedText)'")
        }
        
        let currentRawDigitsUnfiltered = processedText
        print("[PNF init] currentRawDigitsUnfiltered: '\(currentRawDigitsUnfiltered)'")
        let maxLength: Int
        if currentRawDigitsUnfiltered.hasPrefix("13") && !currentRawDigitsUnfiltered.hasPrefix("1300") {
            maxLength = 6
            print("[PNF init] Max length for 13xx: 6")
        } else if currentRawDigitsUnfiltered == "000" {
            maxLength = 3
            print("[PNF init] Max length for 000: 3")
        }
        else {
            maxLength = 10
            print("[PNF init] Default max length: 10")
        }
        let initialRawDigits = String(currentRawDigitsUnfiltered.prefix(maxLength))
        print("[PNF init] initialRawDigits after length limiting: '\(initialRawDigits)'")
        
        let formattedInitial = formatPhoneNumber(initialRawDigits)
        print("[PNF init] Formatted initialRawDigits: '\(formattedInitial)'")
        self.phoneNumber = formattedInitial
        print("[PNF init] self.phoneNumber set to '\(self.phoneNumber)'. Calling validate.")
        validate(rawDigits: initialRawDigits)
        print("[PNF init] Exited.")
    }

    private func formatPhoneNumber(_ digits: String) -> String {
        print("[PNF formatPhoneNumber] Entered with digits: '\(digits)'")

        if digits.isEmpty {
            print("[PNF formatPhoneNumber] Digits are empty. Returning empty string.")
            return ""
        }

        if digits.hasPrefix("000") {
            print("[PNF formatPhoneNumber] Digits start with 000.")
            if digits.count <= 3 {
                print("[PNF formatPhoneNumber] Digits are '\(digits)' (<=3 chars). Returning as is.")
                return digits
            }
            let prefixVal = String(digits.prefix(3))
            print("[PNF formatPhoneNumber] Digits have >3 chars starting with 000. Returning prefix '\(prefixVal)'.")
            return prefixVal
        }

        if digits.hasPrefix("13") && !digits.hasPrefix("1300") {
            print("[PNF formatPhoneNumber] Digits start with 13 (not 1300).")
            let d = String(digits.prefix(6)) 
            print("[PNF formatPhoneNumber] 13xx: d = '\(d)' (prefixed to 6)")
            var result = ""
            if d.count <= 2 { result = d } 
            else if d.count <= 4 { result = "\(d.prefix(2)) \(d.dropFirst(2))" } 
            else { result = "\(d.prefix(2)) \(d.dropFirst(2).prefix(2)) \(d.dropFirst(4))" } 
            print("[PNF formatPhoneNumber] 13xx: Returning '\(result)'")
            return result
        }

        if digits.hasPrefix("1300") || digits.hasPrefix("1800") {
            print("[PNF formatPhoneNumber] Digits start with 1300 or 1800.")
            let d = String(digits.prefix(10)) 
            print("[PNF formatPhoneNumber] 1X00: d = '\(d)' (prefixed to 10)")
            var result = ""
            if d.count <= 4 { result = d } 
            else if d.count <= 7 { result = "\(d.prefix(4)) \(d.dropFirst(4))" } 
            else { result = "\(d.prefix(4)) \(d.dropFirst(4).prefix(3)) \(d.dropFirst(7))" } 
            print("[PNF formatPhoneNumber] 1X00: Returning '\(result)'")
            return result
        }

        if digits.hasPrefix("04") {
            print("[PNF formatPhoneNumber] Digits start with 04.")
            let d = String(digits.prefix(10)) 
            print("[PNF formatPhoneNumber] 04xx: d = '\(d)' (prefixed to 10)")
            var result = ""
            if d.count <= 4 { result = d } 
            else if d.count <= 7 { result = "\(d.prefix(4)) \(d.dropFirst(4))" } 
            else { result = "\(d.prefix(4)) \(d.dropFirst(4).prefix(3)) \(d.dropFirst(7))" } 
            print("[PNF formatPhoneNumber] 04xx: Returning '\(result)'")
            return result
        }

        if digits.hasPrefix("02") || digits.hasPrefix("03") || digits.hasPrefix("07") || digits.hasPrefix("08") {
            print("[PNF formatPhoneNumber] Digits start with 02, 03, 07, or 08.")
            let d = String(digits.prefix(10)) 
            print("[PNF formatPhoneNumber] Landline: d = '\(d)' (prefixed to 10)")
            var result = ""

            if d.isEmpty {
                print("[PNF formatPhoneNumber] Landline: d is empty. Returning empty string.")
                return ""
            } 

            if d.count == 1 { 
                result = "(0"
                print("[PNF formatPhoneNumber] Landline: d.count == 1 ('\(d)'). Returning '\(result)'")
            } else if d.count == 2 { 
                result = "(\(d))" 
                print("[PNF formatPhoneNumber] Landline: d.count == 2 ('\(d)'). Returning '\(result)'")
            } else {
                let areaCode = d.prefix(2) 
                let subscriberPart = d.dropFirst(2)
                print("[PNF formatPhoneNumber] Landline: areaCode='\(areaCode)', subscriberPart='\(subscriberPart)'")

                if d.count <= 6 { 
                    result = "(\(areaCode)) \(subscriberPart)" 
                } else {
                    let firstHalfSubscriber = subscriberPart.prefix(4)
                    let secondHalfSubscriber = subscriberPart.dropFirst(4)
                    result = "(\(areaCode)) \(firstHalfSubscriber) \(secondHalfSubscriber)" 
                }
                print("[PNF formatPhoneNumber] Landline: d.count > 2. Returning '\(result)'")
            }
            return result
        }
        
        if digits == "0" {
             print("[PNF formatPhoneNumber] Digits is '0' (special case). Returning '(0'.")
             return "(0" 
        }

        print("[PNF formatPhoneNumber] No specific pattern matched. Returning digits as is: '\(digits)'")
        return digits
    }

    private func validate(rawDigits: String) {
        print("[PNF validate] Entered with rawDigits: '\(rawDigits)'")
        var isValidFormat = false
        var message: String? = nil
        let digitCount = rawDigits.count
        print("[PNF validate] digitCount: \(digitCount)")

        if rawDigits.isEmpty {
            print("[PNF validate] rawDigits is empty. Setting isValid=true, message=nil.")
            self.isValid = true 
            self.validationMessage = nil
            print("[PNF validate] Exited (empty).")
            return
        }

        if rawDigits.hasPrefix("04") {
            print("[PNF validate] Has prefix 04.")
            if digitCount == 10 { isValidFormat = true }
            else { message = "Mobile numbers (04xx) must be 10 digits." }
        } else if rawDigits.hasPrefix("02") || rawDigits.hasPrefix("03") || rawDigits.hasPrefix("07") || rawDigits.hasPrefix("08") {
            print("[PNF validate] Has prefix 02/03/07/08.")
            if digitCount == 10 { isValidFormat = true }
            else { message = "Landline numbers (0x) must be 10 digits." }
        } else if rawDigits.hasPrefix("1300") || rawDigits.hasPrefix("1800") {
            print("[PNF validate] Has prefix 1300/1800.")
            if digitCount == 10 { isValidFormat = true }
            else { message = "1300/1800 numbers must be 10 digits." }
        } else if rawDigits.hasPrefix("13") { 
            print("[PNF validate] Has prefix 13 (not 1300).")
            if digitCount == 6 { isValidFormat = true }
            else { message = "13 numbers must be 6 digits." }
        } else if rawDigits == "000" {
            print("[PNF validate] Is 000.")
            isValidFormat = true 
        } else {
            print("[PNF validate] Prefix not recognized for standard lengths.")
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
        print("[PNF validate] Initial validation: isValidFormat=\(isValidFormat), message='\(message ?? "nil")'")

        var allCharactersAreSame = false
        if isValidFormat && digitCount > 2 && rawDigits != "000" {
            allCharactersAreSame = Set(rawDigits).count == 1
            print("[PNF validate] Checked for allCharactersAreSame: \(allCharactersAreSame)")
        }

        if allCharactersAreSame {
            print("[PNF validate] All characters are same. Setting isValid=false.")
            self.isValid = false
            self.validationMessage = "Phone number cannot have all identical digits."
        } else if isValidFormat {
            print("[PNF validate] isValidFormat is true. Setting isValid=true.")
            self.isValid = true
            self.validationMessage = nil
        } else {
            print("[PNF validate] isValidFormat is false. Setting isValid=false.")
            self.isValid = false
            self.validationMessage = message ?? "Invalid phone number."
        }
        print("[PNF validate] Final state: self.isValid=\(self.isValid), self.validationMessage='\(self.validationMessage ?? "nil")'")
        print("[PNF validate] Exited.")
    }
    
    var digitsOnly: String {
        print("[PNF digitsOnly] Entered. Current self.phoneNumber: '\(self.phoneNumber)'")
        var textToProcess = self.phoneNumber 
        print("[PNF digitsOnly] textToProcess initial: '\(textToProcess)'")

        if textToProcess.hasPrefix("+61") {
            print("[PNF digitsOnly] Has prefix +61.")
            var nationalPart = String(textToProcess.dropFirst(3))
            print("[PNF digitsOnly] +61 nationalPart initial: '\(nationalPart)'")
            if !nationalPart.hasPrefix("0") {
                let nationalDigitsOnly = nationalPart.filter { $0.isNumber }
                 print("[PNF digitsOnly] +61 nationalPart does not start with 0. nationalDigitsOnly: '\(nationalDigitsOnly)'")
                if nationalDigitsOnly.count == 9 && (nationalDigitsOnly.first == "2" || nationalDigitsOnly.first == "3" || nationalDigitsOnly.first == "4" || nationalDigitsOnly.first == "7" || nationalDigitsOnly.first == "8") {
                     nationalPart = "0" + nationalDigitsOnly
                     print("[PNF digitsOnly] +61 nationalPart prefixed with 0: '\(nationalPart)'")
                } else {
                    nationalPart = nationalDigitsOnly
                    print("[PNF digitsOnly] +61 nationalPart unchanged: '\(nationalPart)'")
                }
            } else {
                nationalPart = nationalPart.filter{ $0.isNumber }
                print("[PNF digitsOnly] +61 nationalPart started with 0. Filtered to digits: '\(nationalPart)'")
            }
            textToProcess = nationalPart
        } else if textToProcess.hasPrefix("+") {
            print("[PNF digitsOnly] Has prefix + but not +61.")
            textToProcess = String(textToProcess.dropFirst()).filter { $0.isNumber }
            print("[PNF digitsOnly] After dropping + and filtering digits: '\(textToProcess)'")
        }
        
        let rawDigits = textToProcess.filter { $0.isNumber }
        print("[PNF digitsOnly] rawDigits after filtering non-digits: '\(rawDigits)'")
        
        var result: String
        if rawDigits.hasPrefix("13") && !rawDigits.hasPrefix("1300") {
            result = String(rawDigits.prefix(6))
            print("[PNF digitsOnly] 13xx number. Result: '\(result)'")
        } else if rawDigits == "000" {
            result = "000"
            print("[PNF digitsOnly] 000 number. Result: '\(result)'")
        } else {
            result = String(rawDigits.prefix(10)) 
            print("[PNF digitsOnly] Default (mobile/landline/1X00). Result: '\(result)'")
        }
        print("[PNF digitsOnly] Exited. Returning '\(result)'")
        return result
    }

    private func extractPureNationalDigits(from text: String) -> String {
        print("[PNF extractPureNationalDigits] Entered with text: '\(text)'")
        var processedText = text
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        processedText = processedText.replacingOccurrences(of: " ", with: "")
        print("[PNF extractPureNationalDigits] After removing parens and spaces: '\(processedText)'")

        if processedText.hasPrefix("+61") {
            print("[PNF extractPureNationalDigits] Has prefix +61.")
            var nationalPart = String(processedText.dropFirst(3)) 
            print("[PNF extractPureNationalDigits] +61 nationalPart initial: '\(nationalPart)'")
            if !nationalPart.hasPrefix("0") { 
                let nationalDigitsOnly = nationalPart.filter { $0.isNumber }
                print("[PNF extractPureNationalDigits] +61 nationalPart does not start with 0. nationalDigitsOnly: '\(nationalDigitsOnly)'")
                if nationalDigitsOnly.count == 9 &&
                   (nationalDigitsOnly.first == "2" || nationalDigitsOnly.first == "3" ||
                    nationalDigitsOnly.first == "4" || nationalDigitsOnly.first == "7" ||
                    nationalDigitsOnly.first == "8") {
                     nationalPart = "0" + nationalDigitsOnly
                     print("[PNF extractPureNationalDigits] +61 nationalPart prefixed with 0: '\(nationalPart)'")
                } else {
                    nationalPart = nationalDigitsOnly
                    print("[PNF extractPureNationalDigits] +61 nationalPart unchanged (not 9 digits or not matching prefix): '\(nationalPart)'")
                }
            } else { 
                 nationalPart = nationalPart.filter { $0.isNumber } 
                 print("[PNF extractPureNationalDigits] +61 nationalPart started with 0. Filtered to digits: '\(nationalPart)'")
            }
            processedText = nationalPart
        } else if processedText.hasPrefix("+") {
            print("[PNF extractPureNationalDigits] Has prefix + but not +61.")
            processedText = String(processedText.dropFirst()).filter { $0.isNumber }
            print("[PNF extractPureNationalDigits] After dropping + and filtering digits: '\(processedText)'")
        } else {
            print("[PNF extractPureNationalDigits] No + prefix.")
            processedText = processedText.filter { $0.isNumber }
            print("[PNF extractPureNationalDigits] Filtered to digits: '\(processedText)'")
        }
        print("[PNF extractPureNationalDigits] Exited. Returning '\(processedText)'")
        return processedText 
    }

    private func determineMaxLength(forPureDigits digits: String) -> Int {
        print("[PNF determineMaxLength] Entered with digits: '\(digits)'")
        var length: Int
        if digits.hasPrefix("13") && !digits.hasPrefix("1300") {
            length = 6 
            print("[PNF determineMaxLength] 13xx: length = 6")
        } else if digits == "000" { 
            length = 3
            print("[PNF determineMaxLength] 000: length = 3")
        } else if digits.hasPrefix("04") {
            length = 10
            print("[PNF determineMaxLength] 04xx: length = 10")
        } else if digits.hasPrefix("02") || digits.hasPrefix("03") || digits.hasPrefix("07") || digits.hasPrefix("08") {
            length = 10
            print("[PNF determineMaxLength] Landline (0x): length = 10")
        } else if digits.hasPrefix("1300") || digits.hasPrefix("1800") {
            length = 10
            print("[PNF determineMaxLength] 1300/1800: length = 10")
        } else {
            length = 10 
            print("[PNF determineMaxLength] Default: length = 10")
        }
        print("[PNF determineMaxLength] Exited. Returning \(length)")
        return length
    }
}
