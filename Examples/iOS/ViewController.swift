//
//  ViewController.swift
//  iOS Example
//
//  Created by Zac Cohan on 10/1/21.
//

import UIKit
import SoulverTextKit

class ViewController: UIViewController {
    
    /// Grab a standard text view
    @IBOutlet weak var textView: UITextView!

    /// Create one of these things
    var paragraphCalculator: SoulverTextKit.ParagraphCalculator!

    /// Choose what character distinguishes a calculating paragraph
    let answerPosition = AnswerPosition.afterEquals
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupSoulverTextKit()
        
        // Looks better
        self.textView.textContainerInset = UIEdgeInsets(top: 20.0, left: 5.0, bottom: 0.0, right: 5.0)
    
    }
    
    func setupSoulverTextKit() {
        
        paragraphCalculator = ParagraphCalculator(answerPosition: answerPosition, textStorage: self.textView.textStorage, textContainer: self.textView.textContainer)
        
        // Setup the text view to send us relevant delegate messages
        self.textView.delegate = self
        self.textView.layoutManager.delegate = self
                               
        // Set somef default expressions
        self.textView.text = [
            "123 + 456",
            "10 USD in EUR",
            "today + 3 weeks"
        ].expressionStringFor(style: self.answerPosition)

        // let soulverTextKit know we changed the textView's text
        paragraphCalculator.textDidChange()

    }
    
}

extension ViewController : NSLayoutManagerDelegate, UITextViewDelegate {
    
    
    func textViewDidChange(_ textView: UITextView) {

        // Let us know when the text changes, so we can evaluate any changed paragraphs if necessary
        paragraphCalculator.textDidChange()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        // Check with us to see if the user should be able to edit parts of the paragraph. For example, we don't allow the user to edit results on Soulver lines themselves
        
        switch paragraphCalculator.shouldAllowReplacementFor(affectedCharRange: range, replacementString: text) {
        case .allow:
            return true
        case .deny:
            return false
        case .setIntertionPoint(range: let range):
            textView.selectedRange = range
            return false
        }
        
    }
    
    func layoutManager(_ layoutManager: NSLayoutManager, textContainer: NSTextContainer, didChangeGeometryFrom oldSize: CGSize) {

        // Let us know when the text view changes size, so we can change update the formatting if necessary
        paragraphCalculator.layoutDidChange()
    }
    
    
}



