//
//  StringByParagraphs.swift
//  SoulverTextKit
//
//  Created by Zac Cohan on 15/10/18.
//  Copyright © 2018 Zac Cohan. All rights reserved.
//

import Foundation

typealias ParagraphIndex = Int
typealias CharacterIndex = Int

/* A view on a string that lets you access paragraphs by index */
internal class StringByParagraphs: CustomDebugStringConvertible {

    internal enum ParagraphIndexGranularity {
        case wholeParagraph
        case contents //no newparagraph character
    }
    
    internal let contents: String
    
    fileprivate let cache: ParagraphCache
    
    internal init(contents: String) {
        
        self.contents = contents
        self.cache = ParagraphCache()
        
        self.loadMetrics()
    }
    
    
    internal var contentEnd: Int {
        return self.cache.paragraphs.last?.range.upperBound ?? 0
    }
    
    internal var paragraphCount: Int {
        return self.cache.paragraphs.count
    }
    
    internal func rangeOfParagraphContainingLocation(_ location: CharacterIndex, includeNewParagraph: Bool = false) -> NSRange {
        
        if location > self.contentEnd {
            assertionFailure("Bad paragraph range request")
            return .zero
        }
  
        if let foundParagraph = _binarySearchForParagraphContaining(location: location) {
            return includeNewParagraph ? foundParagraph.range : foundParagraph.contentsRange
        }

        assertionFailure("Could not find the paragraph at \(location)")
        return .zero
    }
    
        
    internal func contentsRangeOfParagraphContainingLocation(_ location: CharacterIndex) -> NSRange {
        return self.rangeOfParagraphContainingLocation(location, includeNewParagraph: false)
    }

    internal func contentsRangeOfParagraphAtIndex(_ paragraphIndex: ParagraphIndex) -> NSRange {
        return self.cache.getAtIndex(paragraphIndex).contentsRange
    }
    
    internal func rangeOfParagraphAtIndex(_ paragraphIndex: ParagraphIndex) -> NSRange {
        return self.cache.getAtIndex(paragraphIndex).range
    }
        
    internal func paragraphIndexesContainingRange(_ range: NSRange, ignoreFinalTouchedParagraph: Bool) -> Range<ParagraphIndex> {
        
        if (self.cache.paragraphs.isEmpty) {
            return 0..<0
        }
        let firstRange = rangeOfParagraphContainingLocation(range.location)
        
        // Handle the case where we've specified an entire paragraph range
        if firstRange == range {
            let paragraph = self.cache.getAtLocation(firstRange.location)
            
            //the case of |123\n| is technically both paragraph 0 and paragraph 1
            if paragraph.index != self.paragraphCount - 1 && !ignoreFinalTouchedParagraph {
                
                let nextParagraph = self.cache.getAtIndex(paragraph.index + 1)
                if NSIntersectionRange(range, paragraph.range).length == paragraph.range.length {
                    return paragraph.index ..< nextParagraph.index + 1
                }
            }
            
            return paragraph.index ..< paragraph.index + 1
        }
        
        let lastRange = range.length > 0
            ? rangeOfParagraphContainingLocation(range.location + range.length)
            : firstRange
        
        let firstParagraph = self.cache.getAtLocation(firstRange.location)
        var lastParagraph = self.cache.getAtLocation(lastRange.location)
        
        if ignoreFinalTouchedParagraph && firstParagraph.index != lastParagraph.index && lastParagraph.index > 0 {
            
            /* Handle the case where we've specified the entire paragraph above and it's including the last paragraph when it really shouldn't */
            /* ie: |123\n456\n|789 shouldn't touch paragraph 2 */
            
            let paragraphBeforeLast = self.cache.getAtIndex(lastParagraph.index - 1)
            
            if paragraphBeforeLast.range.upperBound == range.upperBound {
                lastParagraph = paragraphBeforeLast
            }
        }
        
        return firstParagraph.index..<lastParagraph.index + 1

    }
    
    internal func indexOfParagraphContainingLocation(_ location: CharacterIndex) -> Int {
        
        if (self.cache.paragraphs.isEmpty) {
            return 0
        }
        let range = rangeOfParagraphContainingLocation(location)
        let paragraph = self.cache.getAtLocation(range.location)
        return paragraph.index
    }
    
    internal subscript(index: Int, granularity: ParagraphIndexGranularity) -> String {
        get {
            let paragraph = self.cache.getAtIndex(index)
            let range = granularity == .contents ? paragraph.contentsRange : paragraph.range
            return (self.contents as NSString).substring(with: range)
        }
    }
    
    // MARK: -  Comparing with other Indexed Strings
    
    internal func indexesDifferingFrom(stringByParagraphs: StringByParagraphs) -> IndexSet {
     
        var differingIndexes = IndexSet()
        
        for paragraphIndex in 0 ..< self.paragraphCount {
            
            if paragraphIndex < stringByParagraphs.paragraphCount {
                if self[paragraphIndex, .contents] != stringByParagraphs[paragraphIndex, .contents] {
                    differingIndexes.insert(paragraphIndex)
                }
            }
            else {
                // this index doesn't even exist in the other string
                differingIndexes.insert(paragraphIndex)
            }
        }
        
        return differingIndexes
        
    }

    
    // MARK: -  Global to Local Range Conversion
    
    internal func globalRangeFor(localRange: NSRange, on paragraphIndex: ParagraphIndex) -> NSRange {
        
        let paragraphRange = self.rangeOfParagraphAtIndex(paragraphIndex)
        let globalLocation = paragraphRange.location + localRange.location
        return NSMakeRange(globalLocation, localRange.length)
        
    }
    
    internal func localRangeFor(globalRange: NSRange, on paragraphIndex: ParagraphIndex) -> NSRange? {
        
        let paragraphRange = self.rangeOfParagraphContainingLocation(globalRange.location)
        
        let startIndex = globalRange.location - paragraphRange.location
        var length = globalRange.length
        
        if length + startIndex > paragraphRange.upperBound {
            length = paragraphRange.upperBound - startIndex
        }
        
        return NSMakeRange(startIndex, length)
        
    }
    
    
    
    // MARK: -  Loading Cache & Searching
    
    private func _binarySearchForParagraphContaining(location: CharacterIndex) -> ParagraphCache.Paragraph? {
                
        var lowerBound = 0
        var upperBound = self.paragraphCount
        
        while lowerBound < upperBound {
            let midIndex = lowerBound + (upperBound - lowerBound) / 2
            let midIndexParagraph = self.cache.paragraphs[midIndex]
            
            if midIndexParagraph.range.contains(location) || (midIndexParagraph.range.length == 0 && midIndexParagraph.range.lowerBound == location) {
                return midIndexParagraph
            } else if midIndexParagraph.range.location < location {
                lowerBound = midIndex + 1
            } else {
                upperBound = midIndex
            }
        }
        
        
        // At the end of the contents (i.e equal to contentEnd is fine, it's the last paragraph)
        if let lastParagraph = self.cache.paragraphs.last, lastParagraph.range.upperBound == location {
            return lastParagraph
        }
        
        return nil

    }
    
    private func loadMetrics() {
        
        let string = self.contents as NSString
        
        var location: Int = 0
        var lastContentsEnd: Int?
        var index: Int = 0
        let max = string.length
        while (location < max) {
            var paragraphStart: Int = 0
            var paragraphEnd: Int = 0
            var contentsEnd: Int = 0
            string.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: &contentsEnd,
                                for: NSMakeRange(location, 0))
            let r = NSMakeRange(paragraphStart, paragraphEnd - paragraphStart)
            let contents = string.substring(with: r)

            let paragraph = ParagraphCache.Paragraph(index: index, range: r,
                                                 contentsRange: NSMakeRange(paragraphStart, contentsEnd - paragraphStart), contents: contents)
            
            
            cache.addParagraph(paragraph)
            index += 1
            location = NSMaxRange(r)
            lastContentsEnd = contentsEnd
        }
        if (lastContentsEnd == nil || lastContentsEnd != location) {
            // Last paragraph ended with an end of paragraph character, add another empty paragraph to represent this
            let r = NSMakeRange(location, 0)
            let paragraph = ParagraphCache.Paragraph(index: index, range: r, contentsRange: r, contents: "")
            cache.addParagraph(paragraph)
        }
        
    }
    
    internal var debugDescription: String {
        
        var description = "\(type(of: self)) (\(Unmanaged.passUnretained(self).toOpaque())))\n"
        description += "'\(self.contents)'"
                
        return description
        
    }

}


fileprivate class ParagraphCache {
    
    class Paragraph {
        var index: Int
        
        /** Range of the entire paragraph, including end of paragraph character */
        var range: NSRange
        
        /** Range of paragraph contents, not including end of paragraph character */
        var contentsRange: NSRange
        
        var contents: String //includes new line character on the end \n
        
        init(index: Int, range: NSRange, contentsRange: NSRange, contents: String) {
            self.index = index
            self.range = range
            self.contentsRange = contentsRange
            self.contents = contents
        }
        
                
    }
    
    /** Paragraphs keyed by range location */
    var paragraphsByLocation: [Int: Paragraph] = Dictionary()
    /** Paragraphs by index */
    var paragraphs: [Paragraph] = Array()
    
    func getAtIndex(_ index: Int) -> Paragraph {
        
        if index < self.paragraphs.count {
            return paragraphs[index]
        }
        
        print ("Error: requesting paragraph range metrics for out of bounds paragraph index (\(index), paragraph count is \(self.paragraphs.count))")
        
        return Paragraph(index: 0, range: NSMakeRange(0, 0), contentsRange: NSMakeRange(0, 0), contents: "")
        
        
    }
    
    func getAtLocation(_ location: Int) -> Paragraph {
        return paragraphsByLocation[location]!
    }
    
    func count() -> Int {
        return paragraphs.count
    }
    
    func isEmpty() -> Bool {
        return paragraphs.isEmpty
    }
    
    func invalidate() {
        paragraphsByLocation.removeAll(keepingCapacity: true)
        paragraphs.removeAll(keepingCapacity: true)
    }
    
    func addParagraph(_ paragraph: Paragraph) {
        paragraphs.append(paragraph)
        paragraphsByLocation[paragraph.range.location] = paragraph
    }
    

    
}

