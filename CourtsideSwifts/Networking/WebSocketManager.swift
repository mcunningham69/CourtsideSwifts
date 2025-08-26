//
//  WebSocketManager.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 19/7/2025.
//

import Foundation
import CoreData

final class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketManager()
    private var task: URLSessionWebSocketTask?
    private let url = URL(string: "wss://swifts-player-sync.azurewebsites.net/ws")!
    public var isConnected = false
    
    func connect() {
        print("ℹ️ connect() called")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receive()
    }
    
    func disconnect() {
        isConnected = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        
    }
    
    private func receive() {
        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("📨 WebSocket raw JSON string:\n\(text)")
                    self?.handleMessage(text)
                case .data(let data):
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📨 WebSocket raw JSON data:\n\(jsonString)")
                    } else {
                        print("❌ Received binary WebSocket data that couldn’t be converted to String.")
                    }
                @unknown default:
                    print("❓ Unknown WebSocket message format")
                }

            case .failure(let error):
                print("🛑 WebSocket receive failed: \(error.localizedDescription)")
                self?.disconnect()
                self?.reconnect()

            }

            self?.receive() // Keep listening
        }
    }
    
    private func handleMessage(_ text: String) {
        // Decode the incoming WebSocket JSON payload
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            print("❌ Failed to decode WebSocket message.")
            return
        }
        
        switch eventType {
        case "player_update":
            // Decode as PlayerStatusDTO
            guard let dto = decodeWebSocketMessage(text) else {
                print("❌ Failed to decode player update message.")
                return
            }
            print("📨 Player update received for uuid \(dto.uuid)")
            NotificationCenter.default.post(name: .webSocketDidReceivePlayerUpdate, object: dto)
            
        case "session_settings.updated":
            // Handle session settings updates
            guard let payload = json["payload"] as? [String: Any],
                  let sessionID = payload["sessionID"] as? String,
                  let userGradeFilter = payload["userGradeFilter"] as? Bool else {
                print("⚠️ Invalid session settings payload.")
                return
            }
            print("⚡ Session \(sessionID) updated → userGradeFilter = \(userGradeFilter)")

            // Notify observers (e.g., your PlayingSessionViewModel)
            NotificationCenter.default.post(
                name: .webSocketDidReceiveSessionSettingsUpdate,
                object: nil,
                userInfo: ["sessionID": sessionID, "userGradeFilter": userGradeFilter]
            )

        default:
            print("ℹ️ Ignored unhandled WebSocket event: \(eventType)")
        }
    }
    
    


    private func decodeWebSocketMessage(_ text: String) -> PlayerStatusDTO? {
        guard let data = text.data(using: .utf8) else { return nil }

        do {
            return try JSONDecoder().decode(PlayerStatusDTO.self, from: data)
        } catch {
            print("❌ JSON decode error:", error)
            return nil
        }
    }


    @MainActor
    private func fetchAndNotifyPlayer(for uuid: UUID) async {
        do {
            if var player = try await PlayerApiService.shared.getPlayerStatus(byID: uuid) {
                // Patch orderOfPlay if needed
                if player.attendingSession && player.orderOfPlay <= 1 {
                    player.orderOfPlay = nextAvailableOrderOfPlay()
                    print("🔧 Assigned orderOfPlay \(player.orderOfPlay) to playerID \(uuid)")
                }

                NotificationCenter.default.post(name: .webSocketDidReceivePlayerUpdate, object: player)
            } else {
                print("⚠️ uuid \(uuid) not found in API")
            }
        } catch {
            print("❌ Failed to fetch full player from API:", error)
        }
    }

    private func nextAvailableOrderOfPlay() -> Int32 {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "attendingSession == true")
        request.sortDescriptors = [NSSortDescriptor(key: "orderOfPlay", ascending: false)]
        request.fetchLimit = 1

        let maxOrder = (try? context.fetch(request).first?.orderOfPlay) ?? 0
        return maxOrder + 1
    }
    
    @MainActor
    private func notifyPlayerUpdate(uuid: UUID) async {
        do {
            if let fullDTO = try await PlayerApiService.shared.getPlayerStatus(byID: uuid) {
                NotificationCenter.default.post(name: .webSocketDidReceivePlayerUpdate, object: fullDTO)
            }
        } catch {
            print("❌ Failed to fetch full player from API:", error)
        }
    }

    
    // MARK: URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("✅ WS connected")
    }
    
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        print("🔌 WS closed:", closeCode)
        isConnected = false
    }
    

    
    public func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.connect()
           
        }
    }
}

extension Notification.Name {
    static let webSocketDidReceivePlayerUpdate =
        Notification.Name("webSocketDidReceivePlayerUpdate")
    static let webSocketDidReceiveSessionSettingsUpdate =
        Notification.Name("webSocketDidReceiveSessionSettingsUpdate")
}


