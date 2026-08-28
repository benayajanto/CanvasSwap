import SwiftUI
import MultipeerConnectivity
import UIKit

struct InkWaterBackground: View {
    @State private var startAnimation = false
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.02, blue: 0.1).ignoresSafeArea()
            
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                Circle()
                    .fill(Color.cyan)
                    .frame(width: width * 1.2, height: width * 1.2)
                    .blur(radius: width * 0.3)
                    .offset(x: startAnimation ? -width * 0.2 : width * 0.4,
                            y: startAnimation ? -height * 0.1 : height * 0.3)
                    .scaleEffect(startAnimation ? 1.2 : 0.8)
                    .opacity(startAnimation ? 0.8 : 0.4)
                
                Circle()
                    .fill(Color.pink)
                    .frame(width: width * 1.1, height: width * 1.1)
                    .blur(radius: width * 0.35)
                    .offset(x: startAnimation ? width * 0.3 : -width * 0.2,
                            y: startAnimation ? height * 0.5 : height * 0.1)
                    .scaleEffect(startAnimation ? 0.9 : 1.4)
                    .opacity(startAnimation ? 0.5 : 0.9)
                
                Circle()
                    .fill(Color.purple)
                    .frame(width: width * 1.4, height: width * 1.4)
                    .blur(radius: width * 0.4)
                    .offset(x: startAnimation ? width * 0.1 : -width * 0.3,
                            y: startAnimation ? height * 0.8 : -height * 0.1)
                    .scaleEffect(startAnimation ? 1.3 : 1.0)
                    .opacity(startAnimation ? 0.7 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                startAnimation.toggle()
            }
        }
    }
}

struct LobbyView: View {
    @StateObject private var multipeerManager = MultipeerManager()
    @AppStorage("displayName") private var displayName: String = ""
    
    var body: some View {
        ZStack {
            InkWaterBackground()
            
            VStack(spacing: 30) {
                
                VStack(spacing: 4) {
                    Text("Hello,")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(1))
                        .padding(.top, 15)
                    
                    TextField("Your Name", text: $displayName)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tint(.cyan)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                        .overlay(
                            HStack {
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                        .overlay(
                            Rectangle()
                                .fill(LinearGradient(colors: [.clear, .white.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 2),
                            alignment: .bottom
                        )
                        .padding(.horizontal, 40)
                        .onChange(of: displayName) { _, newValue in
                            if newValue.count > 12 {
                                displayName = String(newValue.prefix(12))
                            }
                            multipeerManager.updateDisplayName(displayName)
                        }
                }
                .padding(.top, 50)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Online Players")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            if multipeerManager.peers.isEmpty {
                                Text("Searching for nearby players...")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 30)
                            } else {
                                ForEach(multipeerManager.peers, id: \.self) { peer in
                                    let isSelected = multipeerManager.selectedPeer == peer
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            multipeerManager.selectedPeer = peer
                                        }
                                    } label: {
                                        Text(peer.displayName)
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(isSelected ? Color.pink.opacity(0.5) : Color.white.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(isSelected ? Color.pink : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                                            )
                                            .shadow(color: isSelected ? Color.pink.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .background(Color.white.opacity(0.15).background(.ultraThinMaterial))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
                }
                .padding(.horizontal, 24)
                
                HStack(spacing: 16) {
                    Button(action: {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        withAnimation {
                            multipeerManager.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.white.opacity(0.15).background(.ultraThinMaterial))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        multipeerManager.inviteSelectedPeer()
                    }) {
                        Text(multipeerManager.isConnecting ? "Connecting..." : "Join Canvas")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                Group {
                                    if multipeerManager.selectedPeer != nil && !multipeerManager.isConnecting {
                                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    } else {
                                        Color.white.opacity(0.2)
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                            .shadow(color: multipeerManager.selectedPeer != nil && !multipeerManager.isConnecting ? Color.cyan.opacity(0.5) : .clear, radius: 12, x: 0, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .disabled(multipeerManager.selectedPeer == nil || multipeerManager.isConnecting)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            
            if let errorMessage = multipeerManager.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15).background(.ultraThinMaterial))
                        .background(Color.pink.opacity(0.6))
                        .clipShape(Capsule())
                        .shadow(color: .pink.opacity(0.4), radius: 10)
                        .transition(.scale.combined(with: .opacity).combined(with: .move(edge: .bottom)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: multipeerManager.errorMessage)
                        .padding(.bottom, 130)
                        .padding(.bottom, 130)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if displayName.isEmpty {
                let randomNum = Int.random(in: 100...999)
                displayName = "Player \(randomNum)"
            }
            multipeerManager.updateDisplayName(displayName)
            
            AudioManager.shared.playBackgroundMusic()
        }
        .onDisappear {
            AudioManager.shared.stopBackgroundMusic()
        }
        .alert("Incoming Invite", isPresented: $multipeerManager.showInviteAlert) {
            Button("Accept") {
                multipeerManager.handleInvitation(accept: true)
            }
            Button("Decline", role: .cancel) {
                multipeerManager.handleInvitation(accept: false)
            }
        } message: {
            if let invite = multipeerManager.incomingInvite {
                Text("\(invite.peerID.displayName) wants to draw with you!")
            }
        }
        .fullScreenCover(isPresented: $multipeerManager.isConnected) {
            GameView(multipeerManager: multipeerManager)
        }
    }
}

#Preview {
    LobbyView()
}
