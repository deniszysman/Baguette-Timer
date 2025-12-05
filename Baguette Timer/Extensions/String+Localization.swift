//
//  String+Localization.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/4/25.
//

import Foundation

extension String {
    /// Localizes a string using the key
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Localizes a string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        let localizedString = NSLocalizedString(self, comment: "")
        return String(format: localizedString, arguments: arguments)
    }
}

