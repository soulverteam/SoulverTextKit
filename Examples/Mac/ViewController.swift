//
//  ViewController.swift
//  SoulverTextKit
//
//  Created by Zac Cohan on 9/1/21.
//

import Cocoa
import SoulverTextKit

class ViewController: NSViewController {
    
    /// Grab a standard text view
    @IBOutlet var textView: NSTextView!

    /// Create one of these things
    var paragraphCalculator: SoulverTextKit.ParagraphCalculator!
    
    /// Choose what character distinguishes a calculating paragraph
    let style = AnswerPosition.afterTab
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.setupSoulverTextKit()
        
        // Looks better
        self.textView.textContainerInset = NSSize(width: 10.0, height: 15.0)
        
    }
    
    func setupSoulverTextKit() {
        
        paragraphCalculator = ParagraphCalculator(answerPosition: self.style, textStorage: self.textView.textStorage!, textContainer: self.textView.textContainer!)
        
        // Setup the text view to send us relevant delegate messages
        self.textView.delegate = self
        self.textView.layoutManager!.delegate = self
                               
        // Set some default expressions
        self.textView.string = [
            "123 + 456",
            "10 USD in EUR",
            "today + 3 weeks"
        ].expressionStringFor(style: self.style)

        // let soulverTextKit know we changed the textView's text
        paragraphCalculator.textDidChange()


    }
    
}

extension ViewController : NSLayoutManagerDelegate, NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        
        // Let us know when the text changes, so we can evaluate any changed paragraph if necessary
        paragraphCalculator.textDidChange()
    }
    
    func layoutManager(_ layoutManager: NSLayoutManager, textContainer: NSTextContainer, didChangeGeometryFrom oldSize: NSSize) {
        
        // Let us know when the text view changes size, so we can change update the formatting if necessary
        paragraphCalculator.layoutDidChange()
    }
    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {

        // Check with us to see if the user should be able to edit parts of the paragraph. For example, we don't allow the user to edit results on Soulver lines themselves
        
        switch paragraphCalculator.shouldAllowReplacementFor(affectedCharRange: affectedCharRange, replacementString: replacementString) {
        case .allow:
            return true
        case .deny:
            NSSound.beep()
            return false
        case .setIntertionPoint(range: let range):
            textView.setSelectedRange(range)
            return false
        }
        
    }
                
    
}


