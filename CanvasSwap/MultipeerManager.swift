import Foundation
import MultipeerConnectivity
import os
internal import Combine

class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "canvas-swap"
    
    @Published var peers: [MCPeerID] = []
    @Published var selectedPeer: MCPeerID?
    @Published var isConnecting = false
    @Published var errorMessage: String? = nil
    @Published var isConnected = false
    
    @Published var incomingInvite: (peerID: MCPeerID, context: Data?, invitationHandler: (Bool, MCSession?) -> Void)?
    @Published var showInviteAlert = false
    
    @Published var receivedPayload: GamePayload?
    
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CanvasSwap", category: "MultipeerManager")
    
    private var currentDisplayName: String = ""
    
    override init() {
        super.init()
        let randomNum = Int.random(in: 100...999)
        currentDisplayName = "Player \(randomNum)"
        setup(displayName: currentDisplayName)
    }
    
    private func generateRandomName() -> String {
        let randomNum = Int.random(in: 100...999)
        return "I am Player \(randomNum)"
    }
    
    func setup(displayName: String) {
        currentDisplayName = displayName
        myPeerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
    }
    
    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        peers.removeAll()
    }
    
    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
    }
    
    func updateDisplayName(_ newName: String) {
        guard newName != currentDisplayName && !newName.isEmpty else { return }
        stop()
        setup(displayName: newName)
        start()
    }
    
    func refresh() {
        stop()
        start()
    }
    
    func inviteSelectedPeer() {
        guard let peer = selectedPeer else { return }
        
        isConnecting = true
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    // Case A (Receiver): Accept or Decline
    func handleInvitation(accept: Bool) {
        guard let invite = incomingInvite else { return }
        invite.invitationHandler(accept, accept ? session : nil)
        incomingInvite = nil
        showInviteAlert = false
        
        if accept {
            isConnecting = true
        }
    }
    
    func disconnect() {
        session.disconnect()
        isConnected = false
        isConnecting = false
        selectedPeer = nil
        errorMessage = nil
    }
    
    func triggerError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.errorMessage == message {
                    self.errorMessage = nil
                }
            }
        }
    }
    
    func sendPayload(_ payload: GamePayload) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        do {
            let encoded = try JSONEncoder().encode(payload)
            try session.send(encoded, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            self.log.error("Failed to send payload: \(error.localizedDescription)")
        }
    }
}

struct GamePayload: Codable, Equatable {
    let originalOwnerUUID: UUID
    let currentPrompt: String
    let drawingData: Data
    let round: Int
    let unlockedTiles: Set<Int>
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            // Iif already connecting to someone else or connected, automatically decline
            if self.isConnecting || self.isConnected {
                
                // if we are currently trying to connect, and the incoming invite is from the EXACT person we are trying to connect to...
                if self.selectedPeer == peerID {
                    // auto-accept to bypass popup and resolve the race condition
                    invitationHandler(true, self.session)
                    return
                }
                
                self.log.info("Declining invite from \(peerID.displayName) because we are busy.")
                invitationHandler(false, nil)
                return
            }
            
            self.incomingInvite = (peerID, context, invitationHandler)
            self.showInviteAlert = true
        }
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.peers.contains(peerID) {
                self.peers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.peers.removeAll(where: { $0 == peerID })
            if self.selectedPeer == peerID {
                self.selectedPeer = nil
            }
        }
    }
}

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.isConnecting = false
                self.showInviteAlert = false
                self.log.info("Connected to \(peerID.displayName)")
            case .connecting:
                self.log.info("Connecting to \(peerID.displayName)")
            case .notConnected:
                let wasConnected = self.isConnected
                self.isConnected = false
                self.isConnecting = false
                
                if wasConnected {
                    self.triggerError("\(peerID.displayName) has left the game")
                } else if self.selectedPeer == peerID {
                    // Case D: Failure
                    self.triggerError("Matchmaking Failed")
                }
                
                if self.selectedPeer == peerID {
                    self.selectedPeer = nil
                }
                
                self.log.info("Disconnected from \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            do {
                let payload = try JSONDecoder().decode(GamePayload.self, from: data)
                self.receivedPayload = payload
            } catch {
                self.log.error("Could not parse incoming data as GamePayload: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}
