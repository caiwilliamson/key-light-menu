//
//  KeyLightService.swift
//  KeyLightMenu
//

import Foundation
import Observation
import Darwin

// MARK: - Service

@Observable
@MainActor
final class KeyLightService: NSObject {

    var lights: [KeyLight] = []
    var selectedIndex: Int? = nil
    var isDiscovering = false
    var isLoading = false
    var errorMessage: String? = nil

    private var browser: NetServiceBrowser?
    private var resolving: [NetService] = []
    private var pollTask: Task<Void, Never>?

    var selectedLight: KeyLight? {
        guard let i = selectedIndex, lights.indices.contains(i) else { return nil }
        return lights[i]
    }

    var isOn: Bool { selectedLight?.state?.isOn ?? false }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await self?.fetchStatus(showSpinner: false)
                await self?.fetchAccessoryInfo()
                await self?.fetchSettings()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // Returns the current selected index and a URL for the given API path.
    private func indexed(_ path: String) -> (Int, URL)? {
        guard let i = selectedIndex, lights.indices.contains(i),
              let url = lights[i].url(path) else { return nil }
        return (i, url)
    }

    private func putRequest<T: Encodable>(url: URL, body: T) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    // MARK: - Discovery

    func startDiscovery() {
        stopPolling()
        stopDiscovery()
        lights = []
        selectedIndex = nil
        isDiscovering = true
        errorMessage = nil

        let b = NetServiceBrowser()
        b.delegate = self
        b.searchForServices(ofType: "_elg._tcp.", inDomain: "local.")
        browser = b

        // Auto-stop after 5 seconds
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.stopDiscovery()
        }
    }

    func stopDiscovery() {
        browser?.stop()
        browser = nil
        resolving.forEach { $0.stop() }
        resolving = []
        isDiscovering = false
    }

    // MARK: - API

    func fetchStatus(showSpinner: Bool = true) async {
        guard let (i, url) = indexed("lights") else { return }
        if showSpinner { isLoading = true }
        errorMessage = nil
        defer { if showSpinner { isLoading = false } }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                errorMessage = "Unexpected response from device"
                return
            }
            guard lights.indices.contains(i) else { return }
            if let state = try JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
                lights[i].state = state
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ state: LightState) async {
        guard let (i, url) = indexed("lights") else { return }
        do {
            let req = try putRequest(url: url, body: LightsResponse(numberOfLights: 1, lights: [state]))
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                errorMessage = "Failed to update light"
                return
            }
            guard lights.indices.contains(i) else { return }
            if let newState = try JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
                lights[i].state = newState
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle() async {
        guard var s = selectedLight?.state else { return }
        s.isOn.toggle()
        await apply(s)
    }

    func setBrightness(_ v: Int) async {
        guard var s = selectedLight?.state else { return }
        s.brightness = max(1, min(100, v))
        await apply(s)
    }

    func setTemperature(_ v: Int) async {
        guard var s = selectedLight?.state else { return }
        s.temperature = max(143, min(344, v))
        await apply(s)
    }

    func fetchAccessoryInfo() async {
        guard let (i, url) = indexed("accessory-info") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard lights.indices.contains(i) else { return }
            lights[i].accessoryInfo = try JSONDecoder().decode(AccessoryInfo.self, from: data)
        } catch {}
    }

    func setDisplayName(_ name: String) async {
        guard let (i, url) = indexed("accessory-info") else { return }
        struct Payload: Encodable { let displayName: String }
        do {
            let req = try putRequest(url: url, body: Payload(displayName: name))
            let (data, _) = try await URLSession.shared.data(for: req)
            guard lights.indices.contains(i) else { return }
            if let updated = try? JSONDecoder().decode(AccessoryInfo.self, from: data) {
                lights[i].accessoryInfo = updated
            } else {
                lights[i].accessoryInfo?.displayName = name
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func identify() async {
        guard let (_, url) = indexed("identify") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        try? await URLSession.shared.data(for: req)
    }

    func fetchSettings() async {
        guard let (i, url) = indexed("lights/settings") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard lights.indices.contains(i) else { return }
            lights[i].settings = try JSONDecoder().decode(LightSettings.self, from: data)
        } catch {}
    }

    func setBatterySettings(_ battery: BatteryConfig) async {
        guard let (i, url) = indexed("lights/settings"),
              var settings = lights[i].settings else { return }
        settings.battery = battery
        do {
            let req = try putRequest(url: url, body: settings)
            let (data, _) = try await URLSession.shared.data(for: req)
            guard lights.indices.contains(i) else { return }
            lights[i].settings = (try? JSONDecoder().decode(LightSettings.self, from: data)) ?? settings
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - NetServiceBrowserDelegate

extension KeyLightService: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        Task { @MainActor in
            self.resolving.append(service)
            service.delegate = self
            service.resolve(withTimeout: 5)
        }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        Task { @MainActor in
            self.errorMessage = "Bonjour search failed"
            self.stopDiscovery()
        }
    }
}

// MARK: - NetServiceDelegate

extension KeyLightService: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses, !addresses.isEmpty else { return }
        // Extract the IPv4 address from the socket address data
        guard let ipAddress = addresses.compactMap({ data -> String? in
            data.withUnsafeBytes { ptr in
                guard let sa = ptr.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return nil }
                if sa.pointee.sa_family == AF_INET {
                    var addr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr_in.self).pointee
                    var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buf)
                }
                return nil
            }
        }).first else { return }

        let port = sender.port > 0 ? sender.port : 9123
        let name = sender.name

        Task { @MainActor in
            defer { sender.stop(); self.resolving.removeAll { $0 === sender } }
            guard !self.lights.contains(where: { $0.host == ipAddress }) else { return }
            self.lights.append(KeyLight(discoveredName: name, host: ipAddress, port: port))
            if self.selectedIndex == nil {
                self.selectedIndex = self.lights.count - 1
                await self.fetchStatus()
                await self.fetchAccessoryInfo()
                await self.fetchSettings()
                self.startPolling()
            }
            self.stopDiscovery()
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Task { @MainActor in
            self.resolving.removeAll { $0 === sender }
        }
    }
}
