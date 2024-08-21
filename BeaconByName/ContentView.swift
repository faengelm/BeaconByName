
import SwiftUI
import CoreLocation
import AVFoundation

let synthesizer = AVSpeechSynthesizer()

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    
    @Published var proximity: CLProximity?
    
    // Variables for "near" detection logic
    private var nearDetected = false
    private var notDetectedCount = 0
    private let notDetectedThreshold = 5
    
    private var myBeacon = ""
    
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        
        // Request location authorization
        self.locationManager?.requestWhenInUseAuthorization()
        self.startScanning()
    }
    
    func startScanning() {
        let beacons = [
            ("426C7565-4368-6172-6D42-6561636F6E73", 3838, 4949), // Replace with your first beacon's UUID, major, and minor
            ("426C7565-4368-6172-6D42-6561636F6E73", 100, 1)  // Replace with your second beacon's UUID, major, and minor
        ]
        
        for (uuidString, major, minor) in beacons {
            if let uuid = UUID(uuidString: uuidString) {
                let beaconIdentityConstraint = CLBeaconIdentityConstraint(uuid: uuid, major: CLBeaconMajorValue(major), minor: CLBeaconMinorValue(minor))
                let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: beaconIdentityConstraint, identifier: "Beacon_\(uuidString)_\(major)_\(minor)")
                
                print("Starting monitoring and ranging for beacon region: \(beaconRegion)")
                self.locationManager?.startMonitoring(for: beaconRegion)
                self.locationManager?.startRangingBeacons(satisfying: beaconIdentityConstraint)
            } else {
                print("Failed to create UUID from provided string: \(uuidString).")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        print("Ranging beacons with constraint: \(beaconConstraint)")
        
        if let beacon = beacons.first {
            print("Detected beacon with proximity: \(beacon.proximity)")
            handleProximity(beacon.proximity, for: beaconConstraint)
        } else {
            print("No beacons found.")
            handleProximity(nil, for: beaconConstraint)
        }
    }
    
    private func handleProximity(_ detectedProximity: CLProximity?, for beaconConstraint: CLBeaconIdentityConstraint) {
        if detectedProximity == .near {
            // "Near" detected, reset the not detected count
            nearDetected = true
            notDetectedCount = 0
            updateProximity(.near)
            
            if !isSpeaking {
                speakMessage()
            }
            
        } else if nearDetected {   // If "near" was detected previously, count consecutive "not detected"
            notDetectedCount += 1
            
            if notDetectedCount >= notDetectedThreshold {
                // If not detected for 5 times in a row, reset "near" detection
                nearDetected = false
                updateProximity(detectedProximity)
            } else {
                // Maintain "near" state
                print("Maintaining 'near' state, not detected count: \(notDetectedCount)")
            }
        } else {
            // Normal proximity update
            updateProximity(detectedProximity)
        }
    }
    
    private func updateProximity(_ newProximity: CLProximity?) {
        if newProximity != proximity {
            print("Updating proximity to: \(String(describing: newProximity))")
            self.proximity = newProximity
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Started monitoring for region: \(region)")
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region)")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Failed to monitor region: \(String(describing: region)), error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func speakMessage() {
        let utterance = AVSpeechUtterance(string: "Jack, please turn around...This is not your room... I'll let you know when you reach your room")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4
        
        synthesizer.speak(utterance)
        isSpeaking = true
        
        // Schedule the next utterance after the delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            self.isSpeaking = false
        }
    }
}

struct ContentView: View {
    @ObservedObject var locationManager = LocationManager()

    var body: some View {
        VStack {
            if let proximity = locationManager.proximity {
                switch proximity {
                case .immediate:
                    Text("You are very close to the beacon.")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                case .near:
                    Text("Jack, please turn around...This is not your room... I'll let you know when you reach your room")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                case .far:
                    Text("OK, You are far from the beacon.")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                default:
                    Text("Beacon not detected.")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                }
            } else {
                Text("Searching for beacon...")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .onAppear {
            print("ContentView appeared.")
        }
    }
}
