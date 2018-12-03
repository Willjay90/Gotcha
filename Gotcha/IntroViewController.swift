//
//  IntroViewController.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 12/2/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import UIKit
import AVKit

class IntroViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupAVPlayer()
    }
    
    private func setupAVPlayer() {
        guard let videoURL = Bundle.main.url(forResource: "googleMapAR", withExtension: "mov") else { return }
        let player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)

        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)

        player.play()

        // repeat avplayer
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
    }
    
    @IBAction func signInAsHost(_ sender: UIButton) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "arviewcontroller") as! ViewController
        vc.isHost = true
        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func signInAsUser(_ sender: UIButton) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "arviewcontroller") as! ViewController
        vc.isHost = false
        present(vc, animated: true, completion: nil)
    }
    
}
