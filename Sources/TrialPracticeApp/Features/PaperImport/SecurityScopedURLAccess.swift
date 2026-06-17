import Foundation

func withSecurityScopedAccess<T>(to url: URL, perform: () -> T) -> T {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
    return perform()
}
