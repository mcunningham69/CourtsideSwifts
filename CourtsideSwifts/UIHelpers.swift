import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

var isRunningOnMac: Bool {
    #if targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
}
