//
//  KeyLightService.swift
//  KeyLightMenu
//

import Darwin
import Foundation
import Observation

// MARK: - Service

@Observable
@MainActor
final class KeyLightService: NSObject {
  var lights: [KeyLight] = []
  var selectedIndex: Int?
  var isDiscovering = false
  var isLoading = false
  var errorMessage: String?

  /// Short-timeout session used for polling — detects disconnections quickly.
  private let pollSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 3
    return URLSession(configuration: config)
  }()

  /// Short-timeout session used for user-triggered actions — fails fast when a device is unreachable.
  private let actionSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 5
    return URLSession(configuration: config)
  }()

  private static let cacheKey = "cachedLights"

  override init() {
    if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
       let cached = try? JSONDecoder().decode([CachedLight].self, from: data), !cached.isEmpty
    {
      lights = cached.map {
        KeyLight(discoveredName: $0.discoveredName, host: $0.host, port: $0.port,
                 state: $0.state, accessoryInfo: $0.accessoryInfo, settings: $0.settings,
                 isReachable: $0.isReachable)
      }
      selectedIndex = 0
    }
    super.init()
    // Start polling immediately so it runs for the app's lifetime,
    // independent of whether the popover is open or closed.
    if !lights.isEmpty {
      startPolling()
    }
  }

  private func saveCache() {
    let cached = lights.map {
      CachedLight(host: $0.host, port: $0.port, discoveredName: $0.discoveredName,
                  state: $0.state, accessoryInfo: $0.accessoryInfo, settings: $0.settings,
                  isReachable: $0.isReachable)
    }
    if let data = try? JSONEncoder().encode(cached) {
      UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }
  }

  private var browser: NetServiceBrowser?
  private var resolving: [NetService] = []
  private var pollTask: Task<Void, Never>?

  var selectedLight: KeyLight? {
    guard let i = selectedIndex, lights.indices.contains(i) else { return nil }
    return lights[i]
  }

  var isOn: Bool {
    selectedLight?.state?.isOn ?? false
  }

  func startPolling() {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { break }
        await self?.pollAllLights()
      }
    }
  }

  private func pollAllLights() async {
    guard !lights.isEmpty else { return }
    await withTaskGroup(of: Void.self) { group in
      for i in lights.indices {
        group.addTask { await self.pollLight(at: i) }
      }
    }
  }

  private func pollLight(at i: Int) async {
    guard lights.indices.contains(i), let url = lights[i].url("lights") else { return }
    do {
      let (data, response) = try await pollSession.data(from: url)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
      guard lights.indices.contains(i) else { return }
      if let state = try? JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
        lights[i].state = state
        lights[i].isReachable = true
        saveCache()
      }
    } catch {
      if lights.indices.contains(i) {
        lights[i].isReachable = false
        saveCache()
      }
      return
    }
    // Fetch accessory info and settings once if not yet cached
    if lights[i].accessoryInfo == nil, let url = lights[i].url("accessory-info") {
      if let (data, _) = try? await URLSession.shared.data(from: url),
         let info = try? JSONDecoder().decode(AccessoryInfo.self, from: data)
      {
        guard lights.indices.contains(i) else { return }
        lights[i].accessoryInfo = info
        saveCache()
      }
    }
    if lights[i].settings == nil, let url = lights[i].url("lights/settings") {
      if let (data, _) = try? await URLSession.shared.data(from: url),
         let settings = try? JSONDecoder().decode(LightSettings.self, from: data)
      {
        guard lights.indices.contains(i) else { return }
        lights[i].settings = settings
        saveCache()
      }
    }
  }

  private func stopPolling() {
    pollTask?.cancel()
    pollTask = nil
  }

  /// Returns the current selected index and a URL for the given API path.
  private func url(for index: Int, path: String) -> (Int, URL)? {
    guard lights.indices.contains(index), let url = lights[index].url(path) else { return nil }
    return (index, url)
  }

  private func putRequest(url: URL, body: some Encodable) throws -> URLRequest {
    var req = URLRequest(url: url)
    req.httpMethod = "PUT"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.httpBody = try JSONEncoder().encode(body)
    return req
  }

  // MARK: - Discovery

  /// Called on app open. Skips Bonjour scan if we already have cached lights.
  /// Polling is already running from init — just do a single immediate refresh.
  func startSession() {
    if lights.isEmpty {
      startDiscovery()
    } else {
      Task { await pollAllLights() }
    }
  }

  func startDiscovery() {
    stopPolling()
    stopDiscovery()
    // Don't clear lights/selectedIndex here — cached lights should remain
    // visible until Bonjour resolves and live data replaces them.
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

  func fetchStatus(at index: Int, showSpinner: Bool = true) async {
    guard let (i, url) = url(for: index, path: "lights") else { return }
    if showSpinner { isLoading = true }
    errorMessage = nil
    defer { if showSpinner { isLoading = false } }
    let session = showSpinner ? URLSession.shared : pollSession
    do {
      let (data, response) = try await session.data(from: url)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        errorMessage = "Unexpected response from device"
        return
      }
      guard lights.indices.contains(i) else { return }
      if let state = try JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
        lights[i].state = state
        lights[i].isReachable = true
        saveCache()
      }
    } catch {
      if lights.indices.contains(i) { lights[i].isReachable = false }
      if showSpinner { errorMessage = error.localizedDescription }
    }
  }

  private func apply(_ state: LightState, at index: Int) async {
    guard let (i, url) = url(for: index, path: "lights") else { return }
    do {
      let req = try putRequest(url: url, body: LightsResponse(numberOfLights: 1, lights: [state]))
      let (data, response) = try await actionSession.data(for: req)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        errorMessage = "Failed to update light"
        return
      }
      guard lights.indices.contains(i) else { return }
      if let newState = try JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
        lights[i].state = newState
      }
    } catch {
      if lights.indices.contains(i) { lights[i].isReachable = false }
      errorMessage = error.localizedDescription
    }
  }

  func toggle(at index: Int) async {
    guard lights.indices.contains(index), var s = lights[index].state else { return }
    s.isOn.toggle()
    await apply(s, at: index)
  }

  func setBrightness(_ v: Int, at index: Int) async {
    guard lights.indices.contains(index), var s = lights[index].state else { return }
    s.brightness = max(1, min(100, v))
    await apply(s, at: index)
  }

  func setTemperature(_ v: Int, at index: Int) async {
    guard lights.indices.contains(index), var s = lights[index].state else { return }
    s.temperature = max(143, min(344, v))
    await apply(s, at: index)
  }

  func applyPreset(brightness: Int, temperature: Int, at index: Int) async {
    guard lights.indices.contains(index), var s = lights[index].state else { return }
    s.brightness = max(1, min(100, brightness))
    s.temperature = max(143, min(344, temperature))
    await apply(s, at: index)
  }

  func fetchAccessoryInfo(at index: Int) async {
    guard let (i, url) = url(for: index, path: "accessory-info") else { return }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard lights.indices.contains(i) else { return }
      lights[i].accessoryInfo = try JSONDecoder().decode(AccessoryInfo.self, from: data)
      saveCache()
    } catch {}
  }

  func setDisplayName(_ name: String, at index: Int) async {
    guard let (i, url) = url(for: index, path: "accessory-info") else { return }
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

  func identify(at index: Int) async {
    guard let (_, url) = url(for: index, path: "identify") else { return }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    try? await URLSession.shared.data(for: req)
  }

  func fetchSettings(at index: Int) async {
    guard let (i, url) = url(for: index, path: "lights/settings") else { return }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard lights.indices.contains(i) else { return }
      lights[i].settings = try JSONDecoder().decode(LightSettings.self, from: data)
      saveCache()
    } catch {}
  }

  func setBatterySettings(_ battery: BatteryConfig, at index: Int) async {
    guard let (i, url) = url(for: index, path: "lights/settings"),
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
    _: NetServiceBrowser,
    didFind service: NetService,
    moreComing _: Bool
  ) {
    Task { @MainActor in
      self.resolving.append(service)
      service.delegate = self
      service.resolve(withTimeout: 5)
    }
  }

  nonisolated func netServiceBrowser(
    _: NetServiceBrowser,
    didNotSearch _: [String: NSNumber]
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

      // Fetch accessory-info from the resolved address to get the serial number,
      // so we can match against existing lights even if the IP has changed.
      let tempURL = URL(string: "http://\(ipAddress):\(port)/elgato/accessory-info")
      var resolvedSerial: String? = nil
      if let url = tempURL,
         let (data, _) = try? await URLSession.shared.data(from: url),
         let info = try? JSONDecoder().decode(AccessoryInfo.self, from: data)
      {
        resolvedSerial = info.serialNumber
      }

      // Match by serial number first, then fall back to host:port.
      let existing: Int? = {
        if let serial = resolvedSerial, !serial.isEmpty {
          return self.lights.firstIndex { $0.accessoryInfo?.serialNumber == serial }
        }
        return self.lights.firstIndex { $0.host == ipAddress && $0.port == port }
      }()

      if let existing {
        // Update host/port in case the IP changed (e.g. DHCP reassignment).
        self.lights[existing].host = ipAddress
        self.lights[existing].port = port
        if self.selectedIndex == nil { self.selectedIndex = existing }
        await self.fetchStatus(at: existing)
        await self.fetchAccessoryInfo(at: existing)
        await self.fetchSettings(at: existing)
        self.startPolling()
      } else {
        self.lights.append(KeyLight(discoveredName: name, host: ipAddress, port: port))
        let newIndex = self.lights.count - 1
        if self.selectedIndex == nil { self.selectedIndex = newIndex }
        await self.fetchStatus(at: newIndex)
        await self.fetchAccessoryInfo(at: newIndex)
        await self.fetchSettings(at: newIndex)
        self.startPolling()
      }
    }
  }

  nonisolated func netService(_ sender: NetService, didNotResolve _: [String: NSNumber]) {
    Task { @MainActor in
      self.resolving.removeAll { $0 === sender }
    }
  }
}
