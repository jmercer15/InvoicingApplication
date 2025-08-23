import Combine
import SwiftUI

class EmailValidator: ObservableObject {
    @Published var email: String = "" {
        didSet {
            validate(email: email)
        }
    }
    
    @Published var isValid: Bool = false
    @Published var validationMessage: String? = nil

    init(initialEmail: String = "") {
        // Normalize and validate the initial email
        let trimmedEmail = initialEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = trimmedEmail // Assign to trigger didSet and validation
        if initialEmail != trimmedEmail {
            // If initialEmail had spaces, the above assignment already validated the trimmed version.
            // If initialEmail was empty and trimmedEmail is also empty, validation will set it as valid.
        } else {
             // If no trimming occurred, validate directly.
             // This is important if initialEmail is already clean or empty.
            validate(email: self.email)
        }
    }

    private func validate(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedEmail.isEmpty {
            self.isValid = true // Or false, depending on whether an empty email is allowed. Let's assume true for now.
            self.validationMessage = nil
            // If email (original, not trimmed) was not empty but trimmedEmail is, update the published email to trimmedEmail.
            if email != trimmedEmail {
                DispatchQueue.main.async { // Avoid modifying @Published var directly in validate called from didSet
                    self.email = trimmedEmail
                }
            }
            return
        }

        // More robust regex:
        // - Local part: a-zA-Z0-9!#$%&'*+/=?^_`{|}~.- (dots/hyphens not at start/end, not consecutive)
        // - Domain part: a-zA-Z0-9.- (hyphens not at start/end)
        // - TLD: .[a-zA-Z]{2,} (at least 2 letters)
        // This regex is complex, a simpler one is often used for client-side validation,
        // with more thorough validation server-side.
        // Using a commonly accepted "good enough" regex for client-side:
        // let emailPattern = "^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$" // Old problematic one
        // A slightly more comprehensive one that allows more special characters in the local part:
        let emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

        let predicate = NSPredicate(format:"SELF MATCHES %@", emailPattern)
        
        if predicate.evaluate(with: trimmedEmail) {
            self.isValid = true
            self.validationMessage = nil
        } else {
            self.isValid = false
            if !trimmedEmail.contains("@") {
                self.validationMessage = "Email address must include an '@' symbol."
            } else if trimmedEmail.split(separator: "@").count < 2 || trimmedEmail.split(separator: "@")[1].isEmpty {
                self.validationMessage = "Email address must include a domain after the '@' symbol."
            } else if !trimmedEmail.split(separator: "@")[1].contains(".") {
                self.validationMessage = "Email domain must include a '.' (e.g., example.com)."
            } else {
                self.validationMessage = "Please enter a valid email address."
            }
        }
        
        // If the original email had leading/trailing spaces and is now valid/invalid
        // update the published 'email' to the trimmed version to reflect what was validated.
        if email != trimmedEmail && self.email == email { // Ensure we only update if self.email hasn't been changed by another rapid input
             DispatchQueue.main.async {
                self.email = trimmedEmail
            }
        }
    }
}
