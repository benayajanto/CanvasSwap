import SwiftUI
import PencilKit
internal import Combine

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var isToolPickerVisible: Bool
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        let toolPicker = PKToolPicker()
        
        init(_ parent: CanvasView) {
            self.parent = parent
            super.init()
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        
        canvas.bouncesZoom = true
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        
        canvas.backgroundColor = UIColor(patternImage: createDotPattern())
        canvas.isOpaque = true

        context.coordinator.toolPicker.addObserver(canvas)
        context.coordinator.toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
        canvas.becomeFirstResponder()
        
        return canvas
    }
    
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let toolPicker = context.coordinator.toolPicker
        let isCurrentlyVisible = toolPicker.isVisible
        
        if isCurrentlyVisible != isToolPickerVisible {
            toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
            if isToolPickerVisible {
                canvas.becomeFirstResponder()
            } else {
                canvas.resignFirstResponder()
            }
        }
        
        canvas.drawingGestureRecognizer.isEnabled = isToolPickerVisible
        
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }
    
    private func createDotPattern() -> UIImage {
        let size = CGSize(width: 30, height: 30)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        
        UIColor(white: 0.95, alpha: 1.0).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let dotPath = UIBezierPath(ovalIn: CGRect(x: 14, y: 14, width: 2, height: 2))
        UIColor.lightGray.withAlphaComponent(0.8).setFill()
        dotPath.fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

struct GameView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @Environment(\.dismiss) var dismiss
    
    @State private var drawing = PKDrawing()
    @State private var isToolPickerVisible = true
    
    @State private var timeRemaining: Double = 35.00
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @State private var targetTime: Date = Date().addingTimeInterval(35.00)
    
    @State private var dragOffset: CGFloat = 0
    @State private var isPromptHidden = false
    @State private var currentPrompt: String = ""
    
    @State private var round = 1
    @State private var originalOwnerUUID = UUID()
    @State private var showSwapOverlay = false
    @State private var unlockedTiles: Set<Int> = []
    @State private var gameOver = false
    
    @State private var bufferedPayload: GamePayload?
    @State private var isWaitingForSwap = false
    
    @State private var isPulsing = false
    @State private var lastTickSecond = -1
    
    let totalRounds = 5
    let roundDuration: Double = 35.00
    
    let promptOptions = [
        "Draw a fat dog",
        "Draw a half-empty coffee mug",
        "Draw an open laptop",
        "Draw a tangled charging cable",
        "Draw a pair of wired earphones",
        "Draw an overstuffed wallet",
        "Draw a classic wristwatch",
        "Draw a minimalist white sneaker",
        "Draw a spinning fidget toy",
        "Draw a crispy strip of bacon",
        "Draw a potted desk cactus",
        "Draw a padel racket",
        "Draw a slightly deflated soccer ball",
        "Draw a classic computer mouse",
        "Draw a sticky note with a folded corner",
        "Draw a clear water bottle",
        "Draw a pair of reading glasses",
        "Draw a lanyard with an ID badge",
        "Draw a single paperclip",
        "Draw a retro low-top sneaker",
        "Draw a simple house key",
        "Draw a heavy travel suitcase",
        "Draw an open umbrella",
        "Draw a basic tote bag",
        "Draw a sunny-side up egg",
        "Draw a bowl of hot noodles",
        "Draw a steaming pork bun",
        "Draw a half-eaten apple",
        "Draw a generic soda can",
        "Draw a vinyl record",
        "Draw a referee whistle",
        "Draw a stack of three books",
        "Draw a classic gaming controller",
        "Draw a simple jigsaw puzzle piece"
    ]
    
    var timeString: String {
        let finalTime = max(0, timeRemaining)
        let seconds = Int(finalTime)
        let hundredths = Int((finalTime - Double(seconds)) * 100)
        return String(format: "%02d:%02d", seconds, hundredths)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemGray5).ignoresSafeArea()
            
            CanvasView(drawing: $drawing, isToolPickerVisible: $isToolPickerVisible)
                .ignoresSafeArea()
                .disabled(showSwapOverlay || gameOver)
                
            GeometryReader { geo in
                let width = geo.size.width / 2
                let height = geo.size.height / 2
                
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        FogTile(isUnlocked: unlockedTiles.contains(0), width: width, height: height)
                        FogTile(isUnlocked: unlockedTiles.contains(1), width: width, height: height)
                    }
                    HStack(spacing: 0) {
                        FogTile(isUnlocked: unlockedTiles.contains(2), width: width, height: height)
                        FogTile(isUnlocked: unlockedTiles.contains(3), width: width, height: height)
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text(currentPrompt)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .opacity(isPromptHidden ? 0.0 : 1.0)
                
                Capsule()
                    .fill(Color.gray.opacity(isPromptHidden ? 0.0 : 0.4))
                    .frame(width: 40, height: 5)
                    .padding(.bottom, 8)
            }
            .background(Color.white.background(.ultraThinMaterial).opacity(isPromptHidden ? 0.0 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(isPromptHidden ? 0.0 : 0.15), radius: 10, x: 0, y: 5)
            .scaleEffect(isPromptHidden ? 0.4 : 1.0, anchor: .top)
            .offset(y: isPromptHidden ? 10 : 80)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isPromptHidden {
                            dragOffset = min(0, value.translation.height)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if !isPromptHidden && value.translation.height < -20 {
                                isPromptHidden = true
                            }
                            dragOffset = 0
                        }
                    }
            )
            .zIndex(1)
            
            HStack(alignment: .top) {
                Button(action: {
                    multipeerManager.disconnect()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 50, height: 50)
                        .background(Color.white.background(.thickMaterial))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                
                Spacer()
                
                VStack(spacing: 6) {
                    Text(timeString)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(timeRemaining <= 10.0 ? .red : .black)
                        .frame(width: 120, height: 50)
                        .background(Color.white.background(.thickMaterial))
                        .clipShape(Capsule())
                        .shadow(color: timeRemaining <= 10.0 && isPulsing ? .red.opacity(0.8) : .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .scaleEffect(isPulsing ? 1.15 : 1.0)
                        .onReceive(timer) { _ in
                            guard !showSwapOverlay && !gameOver else { return }
                            let remaining = targetTime.timeIntervalSince(Date())
                            if remaining >= 0 {
                                timeRemaining = remaining
                                
                                if remaining <= 10.0 {
                                    if !isPulsing {
                                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                            isPulsing = true
                                        }
                                    }
                                    
                                    let currentSecond = Int(remaining)
                                    if lastTickSecond != currentSecond {
                                        lastTickSecond = currentSecond
                                        
                                        AudioManager.shared.playTickSound()
                                        
                                        if currentSecond <= 5 {
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        } else {
                                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                        }
                                    }
                                }
                                
                            } else {
                                timeRemaining = 0
                                withAnimation(.default) {
                                    isPulsing = false
                                }
                                AudioManager.shared.playRoundEndSound()
                                executeRoundEnd()
                            }
                        }
                    
                    if isPromptHidden {
                        Image(systemName: "chevron.compact.down")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black.opacity(0.4))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .offset(y: isPromptHidden ? max(0, dragOffset) : 0)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isPromptHidden {
                                dragOffset = max(0, value.translation.height)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                if isPromptHidden && value.translation.height > 20 {
                                    isPromptHidden = false
                                }
                                dragOffset = 0
                            }
                        }
                )
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isToolPickerVisible.toggle()
                    }
                }) {
                    Image(systemName: isToolPickerVisible ? "checkmark" : "pencil")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(isToolPickerVisible ? Color.green : Color.blue)
                        .clipShape(Circle())
                        .shadow(color: (isToolPickerVisible ? Color.green : Color.blue).opacity(0.4), radius: 5, x: 0, y: 2)
                }
                .disabled(showSwapOverlay || gameOver)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .zIndex(2)
            
            // Swap Overlay
            if showSwapOverlay {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    Text(isWaitingForSwap ? "WAITING..." : (round == totalRounds ? "FINAL\nROUND" : "SWAP!"))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .italic()
                        .shadow(color: .pink, radius: 15)
                        .scaleEffect(1.2)
                        .transition(.opacity.combined(with: .scale))
                }
                .zIndex(3)
            }
            
            if gameOver {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("MASTERPIECE\nCOMPLETE")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Button("Leave Match") {
                            multipeerManager.disconnect()
                            dismiss()
                        }
                        .font(.system(size: 20, weight: .bold))
                        .padding()
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .zIndex(4)
                .transition(.opacity)
            }
        }
        .onAppear {
            currentPrompt = promptOptions.randomElement() ?? "Draw a cute pet"
            targetTime = Date().addingTimeInterval(roundDuration)
            originalOwnerUUID = UUID()
            unlockNewTile()
        }
        .onChange(of: multipeerManager.receivedPayload) { _, newPayload in
            if let payload = newPayload {
                handleIncomingCanvas(payload)
            }
        }
    }
    
    private func executeRoundEnd() {
        isToolPickerVisible = false
        
        let payload = GamePayload(
            originalOwnerUUID: originalOwnerUUID,
            currentPrompt: currentPrompt,
            drawingData: drawing.dataRepresentation(),
            round: round,
            unlockedTiles: unlockedTiles
        )
        
        multipeerManager.sendPayload(payload)
        
        if let peerPayload = bufferedPayload {
            applyPayload(peerPayload)
            bufferedPayload = nil
        } else {
            isWaitingForSwap = true
            withAnimation {
                showSwapOverlay = true
            }
        }
    }
    
    private func handleIncomingCanvas(_ payload: GamePayload) {
        if isWaitingForSwap {
            applyPayload(payload)
            isWaitingForSwap = false
        } else {
            bufferedPayload = payload
        }
    }
    
    private func applyPayload(_ payload: GamePayload) {
        if let newDrawing = try? PKDrawing(data: payload.drawingData) {
            drawing = newDrawing
        }
        currentPrompt = payload.currentPrompt
        originalOwnerUUID = payload.originalOwnerUUID
        unlockedTiles = payload.unlockedTiles
        
        round += 1
        
        if round <= totalRounds {
            unlockNewTile()
            triggerSwapAnimation()
        } else {
            gameOver = true
            withAnimation {
                showSwapOverlay = false
            }
        }
    }
    
    private func triggerSwapAnimation() {
        withAnimation {
            showSwapOverlay = true
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSwapOverlay = false
                if !gameOver {
                    isPulsing = false
                }
            }
            if !gameOver {
                timeRemaining = roundDuration
                targetTime = Date().addingTimeInterval(roundDuration)
                isToolPickerVisible = true // user can draw immediately when timer starts
                isPromptHidden = true // hide the drawer temporarily to view the incoming canvas
                lastTickSecond = -1
            }
        }
    }
    
    private func unlockNewTile() {
        if round >= 4 {
            unlockedTiles = [0, 1, 2, 3]
        } else {
            let available = Set(0...3).subtracting(unlockedTiles)
            if let randomTile = available.randomElement() {
                unlockedTiles.insert(randomTile)
            }
        }
    }
}

struct FogTile: View {
    let isUnlocked: Bool
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(isUnlocked ? Color.clear : Color.white.opacity(0.1))
            .background(isUnlocked ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
            .frame(width: width, height: height)
            .allowsHitTesting(!isUnlocked) 
    }
}

struct ContentView: View {
    var body: some View {
        LobbyView()
    }
}

#Preview {
    ContentView()
}
