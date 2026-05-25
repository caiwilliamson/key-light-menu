//
//  KeyLightService.swift
//  KeyLightMenu
//

import AppKit
import Darwin
import Foundation
import Observation

/// Wraps a non-Sendable value for safe transfer across concurrency boundaries
/// when the caller guarantees the access is serialised (e.g. moved to @MainActor).
private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Service

@Observable
@MainActor
final class KeyLightService: NSObject {
  var lights: [KeyLight] = []
  var selectedIndex: Int?
  var isDiscovering = false
  var isLoading = false

  let lightPrefs = LightPrefStore()
  private var lightsToRestore: Set<String> = []
  private var sleepWakeObservers: [Any] = []

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
    startSleepWakeMonitoring()
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
    lights.contains { $0.state?.isOn == true }
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
        lights[i].actionError = nil
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
    // Fetch battery info whenever light has a battery
    if lights[i].settings?.battery != nil || lights[i].batteryInfo != nil {
      await fetchBatteryInfo(at: i)
    }
  }

  private func stopPolling() {
    pollTask?.cancel()
    pollTask = nil
  }

  private func url(for index: Int, path: String) -> URL? {
    guard lights.indices.contains(index) else { return nil }
    return lights[index].url(path)
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

  /// Called on app open. Always starts the Bonjour browser so new and
  /// returning lights are discovered. Polls existing lights immediately too.
  func startSession() {
    startDiscovery()
    if !lights.isEmpty {
      Task { await pollAllLights() }
    }
  }

  func startDiscovery() {
    stopDiscovery()
    // Don't clear lights/selectedIndex here — cached lights should remain
    // visible until Bonjour resolves and live data replaces them.
    isDiscovering = true

    let b = NetServiceBrowser()
    b.delegate = self
    b.searchForServices(ofType: "_elg._tcp.", inDomain: "local.")
    browser = b

    // Clear the scanning indicator after 5 s, but keep the browser running
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(5))
      self?.isDiscovering = false
    }
  }

  func stopDiscovery() {
    browser?.stop()
    browser = nil
    resolving.forEach { $0.stop() }
    resolving = []
    isDiscovering = false
  }

  /// Silently restarts the Bonjour browser without showing the scanning indicator.
  /// Use this when the current browser may have missed a service coming back online.
  private func restartBrowser() {
    browser?.stop()
    resolving.forEach { $0.stop() }
    resolving = []
    let b = NetServiceBrowser()
    b.delegate = self
    b.searchForServices(ofType: "_elg._tcp.", inDomain: "local.")
    browser = b
  }

  // MARK: - API

  func fetchStatus(at index: Int) async {
    guard let url = url(for: index, path: "lights") else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
      guard lights.indices.contains(index) else { return }
      if let state = try JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
        lights[index].state = state
        lights[index].isReachable = true
        saveCache()
      }
    } catch {
      if lights.indices.contains(index) { lights[index].isReachable = false }
    }
  }

  private func apply(_ state: LightState, at index: Int) async {
    guard let url = url(for: index, path: "lights") else { return }
    do {
      let req = try putRequest(url: url, body: LightsResponse(numberOfLights: 1, lights: [state]))
      let (data, response) = try await actionSession.data(for: req)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        if lights.indices.contains(index) { lights[index].actionError = "Couldn't apply — try again" }
        return
      }
      guard lights.indices.contains(index) else { return }
      if let newState = try JSONDecoder().decode(LightsResponse.self, from: data).lights.first {
        lights[index].state = newState
        lights[index].actionError = nil
      }
    } catch {
      if lights.indices.contains(index) {
        lights[index].isReachable = false
        lights[index].actionError = nil
      }
    }
  }

  func toggle(at index: Int) async {
    guard lights.indices.contains(index), var s = lights[index].state else { return }
    s.isOn.toggle()
    await apply(s, at: index)
  }

  func setOn(_ on: Bool, at index: Int) async {
    guard lights.indices.contains(index), var s = lights[index].state else { return }
    s.isOn = on
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

  func remove(at index: Int, store: PresetStore) {
    guard lights.indices.contains(index) else { return }
    if let serial = lights[index].accessoryInfo?.serialNumber {
      store.deleteAll(for: serial)
    }
    lights.remove(at: index)
    if selectedIndex == index {
      selectedIndex = lights.isEmpty ? nil : max(0, index - 1)
    } else if let sel = selectedIndex, sel > index {
      selectedIndex = sel - 1
    }
    saveCache()
    restartBrowser()
  }

  func fetchAccessoryInfo(at index: Int) async {
    guard let url = url(for: index, path: "accessory-info") else { return }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard lights.indices.contains(index) else { return }
      lights[index].accessoryInfo = try JSONDecoder().decode(AccessoryInfo.self, from: data)
      saveCache()
    } catch {}
  }

  func setDisplayName(_ name: String, at index: Int) async throws {
    guard let url = url(for: index, path: "accessory-info") else { return }
    struct Payload: Encodable { let displayName: String }
    let req = try putRequest(url: url, body: Payload(displayName: name))
    let (data, response) = try await URLSession.shared.data(for: req)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    guard lights.indices.contains(index) else { return }
    if let updated = try? JSONDecoder().decode(AccessoryInfo.self, from: data) {
      lights[index].accessoryInfo = updated
    } else {
      lights[index].accessoryInfo?.displayName = name
    }
  }

  func identify(at index: Int) async {
    guard let url = url(for: index, path: "identify") else { return }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    _ = try? await URLSession.shared.data(for: req)
  }

  func fetchSettings(at index: Int) async {
    guard let url = url(for: index, path: "lights/settings") else { return }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard lights.indices.contains(index) else { return }
      lights[index].settings = try JSONDecoder().decode(LightSettings.self, from: data)
      saveCache()
    } catch {}
  }

  func setPowerOnSettings(behavior: Int, brightness: Int, temperature: Int, at index: Int) async throws {
    guard let url = url(for: index, path: "lights/settings"),
          var settings = lights[index].settings else { return }
    settings.powerOnBehavior = behavior
    settings.powerOnBrightness = max(1, min(100, brightness))
    settings.powerOnTemperature = max(143, min(344, temperature))
    let req = try putRequest(url: url, body: settings)
    let (data, response) = try await URLSession.shared.data(for: req)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    guard lights.indices.contains(index) else { return }
    lights[index].settings = (try? JSONDecoder().decode(LightSettings.self, from: data)) ?? settings
  }

  func fetchBatteryInfo(at index: Int) async {
    guard let url = url(for: index, path: "battery-info") else { return }
    guard let (data, response) = try? await pollSession.data(from: url),
          (response as? HTTPURLResponse)?.statusCode == 200,
          let info = try? JSONDecoder().decode(BatteryInfo.self, from: data)
    else { return }
    guard lights.indices.contains(index) else { return }
    lights[index].batteryInfo = info
  }

  func setBatterySettings(_ battery: BatteryConfig, at index: Int) async throws {
    guard let url = url(for: index, path: "lights/settings"),
          var settings = lights[index].settings else { return }
    settings.battery = battery
    let req = try putRequest(url: url, body: settings)
    let (data, response) = try await URLSession.shared.data(for: req)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    guard lights.indices.contains(index) else { return }
    lights[index].settings = (try? JSONDecoder().decode(LightSettings.self, from: data)) ?? settings
  }
}

// MARK: - Sleep / Wake / Lock Monitoring

extension KeyLightService {
  private func startSleepWakeMonitoring() {
    let ws = NSWorkspace.shared.notificationCenter
    let dc = DistributedNotificationCenter.default()

    sleepWakeObservers.append(
      ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor [weak self] in self?.handleSleepOrLock() }
      }
    )
    sleepWakeObservers.append(
      ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor [weak self] in self?.handleWakeOrUnlock() }
      }
    )
    sleepWakeObservers.append(
      dc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor [weak self] in self?.handleSleepOrLock() }
      }
    )
    sleepWakeObservers.append(
      dc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor [weak self] in self?.handleWakeOrUnlock() }
      }
    )
  }

  private func handleSleepOrLock() {
    // Guard prevents double-recording when both lock and sleep events fire together.
    guard lightsToRestore.isEmpty else { return }
    for (i, light) in lights.enumerated() {
      guard let serial = light.accessoryInfo?.serialNumber,
            lightPrefs.isEnabled(for: serial),
            light.state?.isOn == true else { continue }
      lightsToRestore.insert(serial)
      Task { await self.setOn(false, at: i) }
    }
  }

  private func handleWakeOrUnlock() {
    let toRestore = lightsToRestore
    lightsToRestore = []
    for (i, light) in lights.enumerated() {
      guard let serial = light.accessoryInfo?.serialNumber,
            toRestore.contains(serial),
            lightPrefs.isRestoreEnabled(for: serial) else { continue }
      Task { await self.setOn(true, at: i) }
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
    let box = Unchecked(value: service)
    Task { @MainActor in
      self.resolving.append(box.value)
      box.value.delegate = self
      box.value.resolve(withTimeout: 5)
    }
  }

  nonisolated func netServiceBrowser(
    _: NetServiceBrowser,
    didNotSearch _: [String: NSNumber]
  ) {
    Task { @MainActor in
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
      // Fetch accessory-info to get the serial number for matching existing lights.
      // Keep the full response so we can cache it and avoid a second network call.
      var resolvedInfo: AccessoryInfo? = nil
      if let url = tempURL,
         let (data, _) = try? await URLSession.shared.data(from: url),
         let info = try? JSONDecoder().decode(AccessoryInfo.self, from: data)
      {
        resolvedInfo = info
      }

      // Match by serial number first, then fall back to host:port.
      // Always try host:port as a fallback even when we have a serial — a concurrent
      // task may have already appended the same light before its accessoryInfo was set.
      let existing: Int? = {
        if let serial = resolvedInfo?.serialNumber, !serial.isEmpty,
           let idx = self.lights.firstIndex(where: { $0.accessoryInfo?.serialNumber == serial })
        {
          return idx
        }
        return self.lights.firstIndex { $0.host == ipAddress && $0.port == port }
      }()

      if let existing {
        // Update host/port in case the IP changed (e.g. DHCP reassignment).
        self.lights[existing].host = ipAddress
        self.lights[existing].port = port
        if let info = resolvedInfo { self.lights[existing].accessoryInfo = info }
        if self.selectedIndex == nil { self.selectedIndex = existing }
        await self.fetchStatus(at: existing)
        if resolvedInfo == nil { await self.fetchAccessoryInfo(at: existing) }
        await self.fetchSettings(at: existing)
        self.startPolling()
      } else {
        self.lights.append(KeyLight(discoveredName: name, host: ipAddress, port: port))
        let newIndex = self.lights.count - 1
        if let info = resolvedInfo { self.lights[newIndex].accessoryInfo = info }
        if self.selectedIndex == nil { self.selectedIndex = newIndex }
        await self.fetchStatus(at: newIndex)
        if resolvedInfo == nil { await self.fetchAccessoryInfo(at: newIndex) }
        await self.fetchSettings(at: newIndex)
        self.startPolling()
      }
    }
  }

  nonisolated func netService(_ sender: NetService, didNotResolve _: [String: NSNumber]) {
    let id = ObjectIdentifier(sender)
    Task { @MainActor in
      self.resolving.removeAll { ObjectIdentifier($0) == id }
    }
  }
}
