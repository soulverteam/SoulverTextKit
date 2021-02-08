//
//  SoulverTextKit.swift
//  SoulverTextKit
//
//  Created by Zac Cohan on 31/1/21.
//


#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The Soulver number-crunching math engine that this package depends on
import SoulverCore

/// What makes a Soulver line a Soulver line in your text view?
public enum AnswerPosition {
    
    /// right align answers after a tab
    case afterTab
    
    /// left align answers to a pipe character | positioned a standard distance from the right of the text view
    case afterPipe
    
    /// insert answers directly after = following the expression
    case afterEquals
    
    /// this string must be present for this line to be processed as a Soulver line
    var divider: String {
        switch self {
        case .afterTab:
            return "\t"
        case .afterPipe:
            return "\t| "
        case .afterEquals:
            return " = "
        }
    }
    
    /// when this character is typed, the line automatically becomes a Soulver line
    var trigger: String {
        switch self {
        case .afterTab:
            return "\t"
        case .afterPipe:
            return "|"
        case .afterEquals:
            return "="
        }
    }
    
}

public enum TextReplacementDecision {
    case allow
    case deny
    case setIntertionPoint(range: NSRange)
}


/// Use this object to add Soulver-like calculation abilities to a standard NSTextView or UITextView
public class ParagraphCalculator {
    
    private var stringByParagraphs: StringByParagraphs
    private let calculator = Calculator(customization: .standard)

    let answerPosition: AnswerPosition
    let textStorage: NSTextStorage
    let textContainer: NSTextContainer

    public init(answerPosition: AnswerPosition, textStorage: NSTextStorage, textContainer: NSTextContainer) {
        
        self.answerPosition = answerPosition
        self.textStorage = textStorage
        self.textContainer = textContainer
        
        self.stringByParagraphs = StringByParagraphs(contents: textStorage.string)
                
    }
    
    // MARK: - Please call the following methods (when appropriate)
    
    public func textDidChange() {

        // Hold onto the previous state before the text changed
        let previousStringByParagraphs = self.stringByParagraphs
        
        // Update to the new state of the textStorage
        self.stringByParagraphs = StringByParagraphs(contents: textStorage.string)
        
        // Determine which lines have been edited
        let editedLines = self.stringByParagraphs.indexesDifferingFrom(stringByParagraphs: previousStringByParagraphs)
        
        // And which of those lines are actually Soulver lines
        let editedSoulverLines = self.indexesOfSoulverLines.intersection(editedLines)
                        
        // Re-evaluate those lines and reformat
        self.evaluateLinesAt(indexes: editedSoulverLines)
        
        // the tab stops need to be updated for certain answer position styles after editing
        self.reformatPargraphStyleAt(paragraphIndexes: editedSoulverLines)
        

    }
    
    public func layoutDidChange() {
        
        /// Updates the tab stop size to keep the results hugging the right side of the text container
        self.reformatPargraphStyleAt(paragraphIndexes: self.indexesOfSoulverLines)
        
    }
    
    public func shouldAllowReplacementFor(affectedCharRange: NSRange, replacementString: String?) -> TextReplacementDecision {
                
        if self.rangeIntersectsSoulverLine(range: affectedCharRange) {
                        
            if let replacementString = replacementString, replacementString == "\n" {
            
                // You're allowed to insert a new line from position 0 on a line
                if self.stringByParagraphs.rangeOfParagraphContainingLocation(affectedCharRange.lowerBound).location == affectedCharRange.location {
                    return .allow
                }
                
                // Manually insert a new line below, rather than breaking up the existing line
                if let newInsertionPoint = self.insertLine(belowLineContaining: affectedCharRange) {
                    return .setIntertionPoint(range: newInsertionPoint)
                }
                                
            }

            // No editing a result please
            else if self.rangeIsInsideResult(range: affectedCharRange) {
                return .deny
            }
            
        }
        else if replacementString == self.answerPosition.trigger {
            
            self.makeSoulverLineAt(lineIndex: self.stringByParagraphs.indexOfParagraphContainingLocation(affectedCharRange.location))
            
            return .setIntertionPoint(range: NSMakeRange(affectedCharRange.lowerBound, 0))

        }

        return .allow
        
    }
        
    // MARK: - Evaluation
        
    private func evaluateLinesAt(indexes: IndexSet) {
                       
        guard indexes.isNotEmpty else {
            return
        }
        
        for lineIndex in indexes.reversed() {
                        
            guard let expression = self.expressionOn(lineIndex: lineIndex), let resultRange = self.resultRangeOn(lineIndex: lineIndex) else {
                continue
            }
            
            let newResult = calculator.calculate(expression).stringValue
            
            if let oldResult = self.resultOn(lineIndex: lineIndex), oldResult == newResult {
                // these results are identical, skip updating the text storage
                continue
            }
            
            textStorage.replaceCharacters(in: resultRange, with: newResult)

        }
        
        // Update our indexed string with the new ranges
        self.stringByParagraphs = StringByParagraphs(contents: textStorage.string)
                
    }

    // MARK: - Formatting
    
    private var paragraphStyle: NSParagraphStyle {
        
        let paragraphStyle = NSMutableParagraphStyle()
        
        paragraphStyle.paragraphSpacing = 6.0
        
        switch self.answerPosition {
        case .afterTab:
            paragraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: self.textContainer.rightEdgeTabPoint, options: [:]),
            ]

        case .afterPipe:
            paragraphStyle.tabStops = [
                NSTextTab(textAlignment: .left, location: self.textContainer.standardAnwswerColumnSizeTabPoint, options: [:]),
            ]
        case .afterEquals:
            break
        }

        return paragraphStyle
        
    }
    
    private func reformatPargraphStyleAt(paragraphIndexes: IndexSet) {
                     
        guard paragraphIndexes.isNotEmpty else {
            return
        }
        
        let paragraphStyle = self.paragraphStyle
                
        for lineIndex in paragraphIndexes.reversed() {
            
            let lineRange = self.stringByParagraphs.rangeOfParagraphAtIndex(lineIndex)
            
            self.textStorage.addAttributes([.paragraphStyle : paragraphStyle], range: lineRange)
            
        }
                        
    }
    

    
    // MARK: -  Which lines in the text view are Soulver lines?
    
    private func isSoulverLineOn(lineIndex: LineIndex) -> Bool {
        
        let line = self.stringByParagraphs[lineIndex, .contents]
        return line.components(separatedBy: self.answerPosition.divider).count == 2
      
    }
    
    private var indexesOfSoulverLines: IndexSet {
        
        var indexSet = IndexSet()
        
        for lineIndex in (0 ..< stringByParagraphs.paragraphCount) {
                      
            if self.isSoulverLineOn(lineIndex: lineIndex) {
                indexSet.insert(lineIndex)
            }
            
        }

        return indexSet
        
    }
        
    
    // MARK: - Inserting lines & making Soulver lines
    
    private func makeSoulverLineAt(lineIndex: LineIndex) {
        
        let rangeOfParagraph = self.stringByParagraphs.contentsRangeOfParagraphAtIndex(lineIndex)

        let attributes = self.textStorage.attributes(at: rangeOfParagraph.lowerBound, effectiveRange: nil)
        
        self.textStorage.insert(NSAttributedString(string: self.answerPosition.divider, attributes: attributes), at: rangeOfParagraph.upperBound)

        self.textDidChange()
        
    }
    
    /// Manually insert a new line below the line containing the given range
    /// - Returns: the new insertion point for the text view
    private func insertLine(belowLineContaining range: NSRange) -> NSRange? {
        
        if let lineIndex = IndexSet(self.stringByParagraphs.paragraphIndexesContainingRange(range, ignoreFinalTouchedParagraph: true)).last {
            
            let rangeOfParagraph = self.stringByParagraphs.contentsRangeOfParagraphAtIndex(lineIndex)
            
            let attributes = self.textStorage.attributes(at: rangeOfParagraph.lowerBound, effectiveRange: nil)
            
            self.textStorage.insert(NSAttributedString(string: "\n", attributes: attributes), at: rangeOfParagraph.upperBound)
            
            self.textDidChange()

            return self.stringByParagraphs.contentsRangeOfParagraphAtIndex(lineIndex + 1)
        }
        
        return nil
        
    }
    
    // MARK: -  Utility (getting expressions, results and their ranges)
        
    private func rangeIntersectsSoulverLine(range: NSRange) -> Bool {
        
        // Which lines are included in this range?
        let affectedLines = IndexSet(self.stringByParagraphs.paragraphIndexesContainingRange(range, ignoreFinalTouchedParagraph: true))
        
        if self.indexesOfSoulverLines.intersection(affectedLines).count > 0 {
            return true
        }
        
        return false
        
    }
    
    private func rangeIntersectsExpression(range: NSRange) -> Bool {
        
        // Which lines are included in this range?
        let affectedLines = self.stringByParagraphs.paragraphIndexesContainingRange(range, ignoreFinalTouchedParagraph: true)
        
        // If it's just one line, and the line is a Soulver line with a result
        if affectedLines.count == 1, let editingLineIndex = affectedLines.first, let expressionRange = self.expressionRangeOn(lineIndex: editingLineIndex) {
            
            // Check the result is not in the edited range
            let intersection = NSIntersectionRange(expressionRange, range)
            
            if intersection.location > 0 {
                return true
            }
            
        }

        return false
    }

    private func rangeIsInsideResult(range: NSRange) -> Bool {
        
        // Which lines are included in this range?
        let affectedLines = self.stringByParagraphs.paragraphIndexesContainingRange(range, ignoreFinalTouchedParagraph: true)
        
        // If it's just one line, and the line is a Soulver line with a result
        if affectedLines.count == 1, let editingLineIndex = affectedLines.first, let resultRange = self.resultRangeOn(lineIndex: editingLineIndex) {

            if range.location >= resultRange.location {
                
                // Check the result is not in the edited range
                let intersection = NSIntersectionRange(resultRange, range)
                            
                if intersection.location > 0 {
                    return true
                }
                
            }
        }

        return false
        
    }
    
    private func expressionOn(lineIndex: LineIndex) -> String? {
                
        let line = self.stringByParagraphs[lineIndex, .contents]
        return line.components(separatedBy: answerPosition.divider)[safe: 0]
                
    }
    
    private func resultOn(lineIndex: LineIndex) -> String? {
                
        let line = self.stringByParagraphs[lineIndex, .contents]
        return line.components(separatedBy: answerPosition.divider)[safe: 1]
                
    }


    private func expressionRangeOn(lineIndex: LineIndex) -> NSRange? {
        
        guard self.isSoulverLineOn(lineIndex: lineIndex) else {
            return nil
        }
        
        let line = self.stringByParagraphs[lineIndex, .contents]
                
        if let localExpressionRange = line.components(separatedBy: self.answerPosition.divider)[safe: 0]?.completeStringRange {
            
            let globalResultRange = self.stringByParagraphs.globalRangeFor(localRange: localExpressionRange, on: lineIndex)

            return globalResultRange
        }
        
        return nil

    }

    
    private func resultRangeOn(lineIndex: LineIndex) -> NSRange? {
        
        let line = self.stringByParagraphs[lineIndex, .contents]
                
        if let resultRange = line.components(separatedBy: self.answerPosition.divider)[safe: 1] {
            
            let localResultRange = NSMakeRange(line.count - resultRange.count, resultRange.count)
            let globalResultRange = self.stringByParagraphs.globalRangeFor(localRange: localResultRange, on: lineIndex)

            return globalResultRange
        }
        
        return nil
        
    }
    
}


private extension NSTextContainer {
    
    var rightEdgeTabPoint: CGFloat {
        return self.size.width - self.lineFragmentPadding * 2
    }

    var standardAnwswerColumnSizeTabPoint: CGFloat {
        return self.size.width - 200.0
    }
}


public extension Array where Element == String {
    
    func expressionStringFor(style: AnswerPosition) -> String {
        
        var placeholderString = ""
        
        for expression in self {
            
            if placeholderString.isNotEmpty {
                placeholderString.append("\n")
            }
        
            placeholderString.append(expression + style.divider)
        }
        
        return placeholderString
        
    }
    
}
