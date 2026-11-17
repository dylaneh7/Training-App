import SwiftUI
import CoreBluetooth
import Combine

/// Initial subscription-independent sensor capability. Standard BLE Heart
/// Rate (0x180D / 0x2A37) only; no unsupported claim of WHOOP sleep, HRV,
/// raw history, or recovery access. No background scanning or cloud upload.
@MainActor
final class IMUNBLEHeartRateReader: NSObject, ObservableObject,
                                   CBCentralManagerDelegate, CBPeripheralDelegate {
    struct Device: Identifiable {
        let id: UUID
        let name: String
        let signal: Int
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var status = "Scan for a broadcasting Bluetooth heart-rate sensor."
    @Published private(set) var bpm: Int?
    @Published private(set) var connectedName: String?
    @Published private(set) var scanning = false

    private static let heartService = CBUUID(string: "180D")
    private static let heartMeasurement = CBUUID(string: "2A37")
    private var central: CBCentralManager?
    private var discovered: [UUID: CBPeripheral] = [:]
    private var connected: CBPeripheral?
    private var wantsScan = false

    func scan() {
        wantsScan = true
        devices = []
        discovered = [:]
        if central == nil {
            status = "Requesting Bluetooth access…"
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            startScan()
        }
    }

    private func startScan() {
        guard wantsScan, let central else { return }
        switch central.state {
        case .poweredOn:
            if let connected { central.cancelPeripheralConnection(connected) }
            self.connected = nil
            connectedName = nil
            bpm = nil
            status = "Looking for standard Bluetooth heart-rate broadcasters…"
            scanning = true
            central.scanForPeripherals(
                withServices: [Self.heartService],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        case .unauthorized:
            scanning = false
            status = "Bluetooth permission is required to scan for a heart-rate sensor."
        case .poweredOff:
            scanning = false
            status = "Enable Bluetooth in iPhone Settings."
        case .unsupported:
            scanning = false
            status = "This device does not support Bluetooth Low Energy."
        default:
            scanning = false
            status = "Bluetooth is preparing. Scan again when ready."
        }
    }

    func stop() {
        wantsScan = false
        central?.stopScan()
        scanning = false
        if let connected { central?.cancelPeripheralConnection(connected) }
        connected = nil
        connectedName = nil
        bpm = nil
        status = "Sensor disconnected. No readings were saved."
    }

    func connect(to id: UUID) {
        guard let peripheral = discovered[id], let central,
              central.state == .poweredOn else { return }
        central.stopScan()
        scanning = false
        connected = peripheral
        peripheral.delegate = self
        connectedName = nil
        bpm = nil
        status = "Connecting to \(peripheral.name ?? "Bluetooth sensor")…"
        central.connect(peripheral, options: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn, wantsScan { startScan() }
        else if central.state != .poweredOn {
            scanning = false
            if central.state == .poweredOff { status = "Bluetooth is turned off." }
            if central.state == .unauthorized { status = "Allow Bluetooth access for iMun in Settings." }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        discovered[peripheral.identifier] = peripheral
        let name = peripheral.name ??
            advertisementData[CBAdvertisementDataLocalNameKey] as? String ??
            "Unnamed HR sensor"
        let next = Device(id: peripheral.identifier, name: name,
                          signal: RSSI.intValue)
        if let idx = devices.firstIndex(where: { $0.id == next.id }) {
            devices[idx] = next
        } else {
            devices.append(next)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        connectedName = peripheral.name ?? "Bluetooth heart-rate sensor"
        status = "Connected. Waiting for heart-rate measurements…"
        peripheral.discoverServices([Self.heartService])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectedName = nil
        status = "Unable to connect: \(error?.localizedDescription ?? "Connection failed")"
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        guard peripheral.identifier == connected?.identifier else { return }
        connected = nil
        connectedName = nil
        bpm = nil
        status = error.map { "Sensor disconnected: \($0.localizedDescription)" }
            ?? "Sensor disconnected."
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { status = "Service discovery failed: \(error.localizedDescription)"; return }
        for service in peripheral.services ?? [] where service.uuid == Self.heartService {
            peripheral.discoverCharacteristics([Self.heartMeasurement], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error { status = "Sensor characteristics unavailable: \(error.localizedDescription)"; return }
        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == Self.heartMeasurement
        }) else {
            status = "This sensor doesn't expose the standard heart-rate measurement."
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, characteristic.uuid == Self.heartMeasurement,
              let data = characteristic.value, let value = Self.decode(data),
              (25...250).contains(value) else { return }
        bpm = value
        status = "Live heart rate from \(connectedName ?? "Bluetooth sensor")."
    }

    private static func decode(_ data: Data) -> Int? {
        let bytes = Array(data)
        guard bytes.count >= 2 else { return nil }
        let sixteenBit = bytes[0] & 1 != 0
        if !sixteenBit { return Int(bytes[1]) }
        guard bytes.count >= 3 else { return nil }
        return Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
    }
}

/// Optional, user-initiated sensor feature in Health, kept distinct from
/// HealthKit's recorded Apple Watch and WHOOP history.
struct IMUNLiveHeartRateCard: View {
    @StateObject private var sensor = IMUNBLEHeartRateReader()

    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 12) {
                HCSectionTitle(title: "Live Bluetooth heart rate",
                               detail: "Experimental · On-device")
                Text("Connect a standard Bluetooth heart-rate broadcaster, such as a compatible chest strap or WHOOP with HR Broadcast enabled.")
                    .font(.caption)
                    .foregroundStyle(HCDesign.secondary)

                if let bpm = sensor.bpm {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(bpm)")
                            .font(HCDesign.metric(38))
                            .foregroundStyle(HCDesign.aqua)
                            .contentTransition(.numericText())
                        Text("BPM").font(HCDesign.label(11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                if let name = sensor.connectedName {
                    Label(name, systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(HCDesign.ink)
                }
                Text(sensor.status)
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)

                HStack(spacing: 10) {
                    Button(sensor.scanning ? "Scan again" : "Scan for sensor") {
                        sensor.scan()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HCDesign.aqua)

                    Button("Disconnect") { sensor.stop() }
                        .buttonStyle(.bordered)
                        .disabled(sensor.connectedName == nil && !sensor.scanning)
                }
                ForEach(sensor.devices) { candidate in
                    Button {
                        sensor.connect(to: candidate.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Bluetooth HR sensor")
                                    .font(.caption2)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer()
                            Image(systemName: "link")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Text("Live HR only for now; no sleep/HRV/Strain history is collected or uploaded. Availability after a WHOOP membership ends is not guaranteed.")
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)
            }
        }
        .onDisappear { sensor.stop() }
    }
}
