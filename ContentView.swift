import SwiftUI
import CoreLocation
import UIKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var photoManager = PhotoManager()
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    @State private var deviceInfo: String = ""
    @State private var isLoadingPhotos = false

    @State private var photoLimitText = "20"
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var sortAscending = false

    @State private var installedApps: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("🔍 Agent d'Investigation iOS")
                    .font(.title)
                    .padding()

                if let location = locationManager.location {
                    Text("📍 Latitude : \(location.coordinate.latitude)")
                    Text("📍 Longitude : \(location.coordinate.longitude)")
                } else {
                    Text("⏳ Récupération de la position...")
                }

                Text("🔋 Batterie : \(Int(batteryLevel * 100))%")
                Text("📱 Appareil : \(deviceInfo)")

                VStack(alignment: .leading) {
                    Text("Nombre max de photos à récupérer")
                    TextField("Nombre", text: $photoLimitText)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(width: 120)
                }

                VStack(alignment: .leading) {
                    Text("Date de début")
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                VStack(alignment: .leading) {
                    Text("Date de fin")
                    DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                VStack(alignment: .leading) {
                    Text("Ordre de tri par date")
                    Picker("", selection: $sortAscending) {
                        Text("Décroissant").tag(false)
                        Text("Croissant").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }

                Button(isLoadingPhotos ? "Chargement..." : "📸 Récupérer photos") {
                    guard !isLoadingPhotos else { return }
                    isLoadingPhotos = true
                    let limit = Int(photoLimitText) ?? 20
                    photoManager.fetchPhotosMetadata(limit: limit, startDate: startDate, endDate: endDate, ascending: sortAscending) {
                        isLoadingPhotos = false
                    }
                }
                .disabled(isLoadingPhotos)
                .padding()
                .background(isLoadingPhotos ? Color.gray : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)

                Text("Photos récupérées : \(photoManager.photosMetadata.count)")
                    .foregroundColor(photoManager.photosMetadata.isEmpty ? .gray : .primary)

                Divider().padding(.vertical)

                VStack(alignment: .leading, spacing: 5) {
                    Text("📱 Apps détectées installées :")
                        .font(.headline)
                    if installedApps.isEmpty {
                        Text("Aucune app détectée.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(installedApps, id: \.self) { app in
                            Text("• \(app)")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                Spacer()

                Button(action: {
                    saveDataToJSON()
                }) {
                    Text("📁 Enregistrer les données (.json)")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    exportFile()
                }) {
                    Text("📤 Exporter les données")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    sendJSONToServer()
                }) {
                    Text("📡 Envoyer au serveur")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryLevel = UIDevice.current.batteryLevel
            deviceInfo = getDeviceInfo()
            installedApps = checkInstalledApps()
        }
    }

    func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.name) — \(device.model), \(device.systemName) \(device.systemVersion)"
    }

    func checkInstalledApps() -> [String] {
        let schemes = [
            ("WhatsApp", "whatsapp://"),
            ("Facebook", "fb://"),
            ("Instagram", "instagram://")
        ]

        var installed: [String] = []
        for (name, scheme) in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                installed.append(name)
            }
        }
        return installed
    }

    func saveDataToJSON() {
        let date = Date()
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)

        let lat = locationManager.location?.coordinate.latitude ?? 0.0
        let lon = locationManager.location?.coordinate.longitude ?? 0.0
        let battery = Int(batteryLevel * 100)

        var photosArray: [[String: Any]] = []

        for meta in photoManager.photosMetadata {
            var photoDict: [String: Any] = [:]
            photoDict["date"] = meta.creationDate?.description ?? "Inconnue"
            photoDict["fileSizeKB"] = Double(meta.fileSize) / 1024.0
            if let loc = meta.location {
                photoDict["location"] = ["latitude": loc.latitude, "longitude": loc.longitude]
            }
            photosArray.append(photoDict)
        }

        let jsonDict: [String: Any] = [
            "timestamp": dateString,
            "device": deviceInfo,
            "battery": "\(battery)%",
            "location": [
                "latitude": lat,
                "longitude": lon
            ],
            "installedApps": installedApps,
            "photosCount": photoManager.photosMetadata.count,
            "photos": photosArray
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted])
            let fileName = "investigation_log.json"
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = dir.appendingPathComponent(fileName)
                try jsonData.write(to: fileURL)
                print("✅ Fichier JSON sauvegardé : \(fileURL)")
            }
        } catch {
            print("❌ Erreur lors de la sauvegarde JSON : \(error.localizedDescription)")
        }
    }

    func exportFile() {
        let fileName = "investigation_log.json"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)

            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true, completion: nil)
            }
        }
    }

    func sendJSONToServer() {
        let fileName = "investigation_log.json"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)

            do {
                let jsonData = try Data(contentsOf: fileURL)

                guard let url = URL(string: "http://192.168.1.7:5001/upload") else {
                    print("❌ URL invalide")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData

                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("❌ Erreur d’envoi : \(error.localizedDescription)")
                        return
                    }
                    if let response = response as? HTTPURLResponse {
                        print("✅ Réponse du serveur : \(response.statusCode)")
                    }
                }
                task.resume()

            } catch {
                print("❌ Erreur de lecture du JSON : \(error.localizedDescription)")
            }
        }
    }
}

