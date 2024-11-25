import Foundation

class SentryLogOutput : NSObject, SentryLogOutputProtocol {
    @objc func log (_ message: String) {
        print(message)
    }
}
