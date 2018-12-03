//
//  StatusViewController.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 10/10/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import UIKit

class StatusViewController: UIViewController {

    enum MessageType {
        case trackingStateEscalation
        case planeEstimation
        case contentPlacement
        case focusSquare
        
        static var all: [MessageType] = [
            .trackingStateEscalation,
            .planeEstimation,
            .contentPlacement,
            .focusSquare
        ]
    }
    
    @IBOutlet weak var messagePanel: UIVisualEffectView!
    @IBOutlet weak var messageLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagePanel.isHidden = true
    }
    
    
    @IBAction func addOntoPlane(_ sender: UIButton) {
        guard let parent = self.parent as? ViewController else { return }
        parent.placeObjectNode()
        messagePanel.alpha = 0
        parent.currentBuffer = nil
    }
    
    
    @IBAction func dismissMessage(_ sender: UIButton) {
        messagePanel.alpha = 0
    }
    
    
    /// Seconds before the timer message should fade out. Adjust if the app needs longer transient messages.
    private let displayDuration: TimeInterval = 4
    
    // Timer for hiding messages.
    private var messageHideTimer: Timer?
    
    private var timers: [MessageType: Timer] = [:]
    
    // MARK: - Message Handling
    
    func showMessage(_ text: String, autoHide: Bool = true) {
        // Cancel any previous hide timer.
        messageHideTimer?.invalidate()
        
        messageLabel.text = text
        
        // Make sure status is showing.
        setMessageHidden(false, animated: true)
        
        if autoHide {
            messageHideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false, block: { [weak self] _ in
                self?.setMessageHidden(true, animated: true)
            })
        }
    }
    
    func keepShowingMessage(_ text: String) {
        messageLabel.text = text
        setMessageHidden(false, animated: true)
    }
    
    // MARK: - Panel Visibility
    
    private func setMessageHidden(_ hide: Bool, animated: Bool) {
        // The panel starts out hidden, so show it before animating opacity.
        messagePanel.isHidden = false
        
        guard animated else {
            messagePanel.alpha = hide ? 0 : 1
            return
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
            self.messagePanel.alpha = hide ? 0 : 1
        }, completion: nil)
    }
    
}
