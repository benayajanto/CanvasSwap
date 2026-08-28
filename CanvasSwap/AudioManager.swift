import AVFoundation
import UIKit

class AudioManager {
    static let shared = AudioManager()
    
    private var backgroundPlayer: AVAudioPlayer?
    private var tickPlayer: AVAudioPlayer?
    private var splatPlayer: AVAudioPlayer?
    
    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playBackgroundMusic() {
        guard let url = Bundle.main.url(forResource: "chill_loop", withExtension: "wav") else { return }
        do {
            backgroundPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.numberOfLoops = -1 // Infinite loop
            backgroundPlayer?.volume = 0.4
            backgroundPlayer?.play()
        } catch {
            print("Could not load background track.")
        }
    }
    
    func stopBackgroundMusic() {
        backgroundPlayer?.stop()
    }
    
    func playTickSound() {
        if let url = Bundle.main.url(forResource: "tick", withExtension: "wav") {
            do {
                tickPlayer = try AVAudioPlayer(contentsOf: url)
                tickPlayer?.play()
            } catch {
                print("Could not load tick sound.")
            }
        } else {
            AudioServicesPlaySystemSound(1104)
        }
    }
    
    func playRoundEndSound() {
        if let url = Bundle.main.url(forResource: "splat", withExtension: "wav") {
            do {
                splatPlayer = try AVAudioPlayer(contentsOf: url)
                splatPlayer?.play()
            } catch {
                print("Could not load splat sound.")
            }
        } else {
            AudioServicesPlaySystemSound(1322) 
        }
    }
}
