//
//  PlayerStatusService.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

import Foundation

import Foundation

class PlayerStatusService {
    private let baseURL = URL(string: "https://swiftsplayerapi2025.azurewebsites.net/api/playerstatus")!

    func fetchPlayerStatuses(completion: @escaping (Result<[PlayerStatusDTO], Error>) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let players = try decoder.decode([PlayerStatusDTO].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(players))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    enum NetworkError: Error {
        case invalidResponse
        case noData
    }
}
