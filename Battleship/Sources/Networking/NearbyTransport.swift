import Foundation
import MultipeerConnectivity
import Observation
import UIKit

/// Peer-to-peer play over Wi-Fi / Bluetooth using MultipeerConnectivity.
/// Every device both advertises and browses; the peer with the lower token sends the invite
/// so two devices never invite each other simultaneously.
@MainActor
@Observable
final class NearbyTransport: NSObject, GameTransport {
    enum State: Equatable { case searching, connecting(String), connected(String), failed(String) }

    let kind: TransportKind = .nearby
    private(set) var state: State = .searching
    private(set) var discoveredPeers: [String] = []
    var onMessage: ((GameMessage) -> Void)?
    var onDisconnect: (() -> Void)?

    var opponentName: String { session.connectedPeers.first?.displayName ?? "Nearby player" }
    var isConnected: Bool { if case .connected = state { return true } else { return false } }

    private static let serviceType = "bship-ww2"
    private let token = UUID().uuidString
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    init(displayName: String) {
        peerID = MCPeerID(displayName: String(displayName.prefix(60)))
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["token": token], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        state = .searching
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func send(_ message: GameMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(try message.encoded(), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            onDisconnect?()
        }
    }

    func disconnect() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
}

extension NearbyTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connecting:
                self.state = .connecting(peerID.displayName)
            case .connected:
                self.state = .connected(peerID.displayName)
                self.advertiser.stopAdvertisingPeer()
                self.browser.stopBrowsingForPeers()
            case .notConnected:
                if self.isConnected {
                    self.onDisconnect?()
                } else {
                    self.state = .searching
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? GameMessage.decode(data) else { return }
        Task { @MainActor in self.onMessage?(message) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(self.session.connectedPeers.isEmpty, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in self.state = .failed(error.localizedDescription) }
    }
}

extension NearbyTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let theirToken = info?["token"] ?? ""
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID.displayName) { self.discoveredPeers.append(peerID.displayName) }
            guard self.session.connectedPeers.isEmpty, self.token < theirToken else { return }
            self.state = .connecting(peerID.displayName)
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.discoveredPeers.removeAll { $0 == peerID.displayName } }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in self.state = .failed(error.localizedDescription) }
    }
}
