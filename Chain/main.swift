//
//  main.swift
//  Chain
//
//  Created by Andrew Carter on 10/19/16.
//

import Foundation

extension Array {
    
    /// Returns a random element from Array using arc4random_uniform
    func randomElement() -> Iterator.Element {
        let index = Int(arc4random_uniform(UInt32(count)))
        return self[index]
    }
    
}

class Chain {
    
    /// Represents word or sentence end that comes after a given source work.
    private enum Link {
        case end
        case word([String])
    }
    
    // MARK: - Properties
    
    /// Words representing the start of a sentence
    private let startingWords: [String]
    
    /// Links to a given source word
    private let links: [String: [Link]]
    
    // MARK: - Init
    
    init(_ string: String, wordLength: Int = 1) {
        // Generate sentences from source
        let sentences = Chain.makeSentences(from: string)
        
        // Information be stored in chain properties
        var startingWords = [String]()
        var links = [String: [Link]]()
        
        sentences.forEach { sentence in
            // Generate words for this sentence
            let words = Chain.makeWords(from: sentence)
            let count = words.count
            
            // For each word
            words.enumerated().forEach { index, word in
                // If we already have links for this word grab it, otherwise create new array
                var wordLinks = links[word] ?? []
                
                // If this is the first word in the sentence, track it as a valid starting word
                // for a sentence
                if index == 0 {
                    startingWords.append(word)
                }
                
                // If there is no next word in the sentence, mark the next word as an end
                if index + 1 == count {
                    wordLinks.append(.end)
                } else {
                    // Otherwise we can add the next word
                    let start = index + 1
                    let end = start + (wordLength - 1) < words.count ? start + (wordLength - 1) : start
                    let result = Array(words[start ... end])
                    wordLinks.append(.word(result))
                }
                
                // Store the updated links for this word
                links[word] = wordLinks
            }
        }
        
        // Store generated information, now we have our chain datasource
        self.links = links
        self.startingWords = startingWords
    }
    
    /// Create a Chain from the text of the given file paths
    convenience init(_ filePaths: [String], wordLength: Int = 1) {
        let filesString = filePaths.map { path -> String in
            do {
                let string = try String(contentsOfFile: path)
                return string
            } catch {
                fatalError("Error loading file: \(error)")
            }
            }
            .reduce("") { "\($0)\n\($1)" }
        
        self.init(filesString, wordLength: wordLength)
    }
    
    // MARK: - Static Methods
    
    /// Returns sanitized sentences in the given string
    private static func makeSentences(from string: String) -> [String] {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: ".?!\n")
        
        let sentences = string.components(separatedBy: characterSet)
        return sentences
    }
    
    /// Returns sanitized words from the given string
    private static func makeWords(from sentence: String) -> [String] {
        return sentence.components(separatedBy: " ").flatMap({ (word) -> String? in
            let cleanWord = word.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .lowercased()
            
            return cleanWord.characters.isEmpty ? nil : cleanWord
        })
    }
    
    // MARK: - Instance Methods
    
    /// Generates new sentence from chain data source
    func makeSentences(count: Int = 1, requiredWords: [String] = [], parallel: Bool = false) -> [String] {
        var sentences = [String]()
        let group = DispatchGroup()
        let writeQueue = DispatchQueue(label: "write")
        
        let threads = parallel ? ProcessInfo.processInfo.activeProcessorCount : 1
        for _ in 0 ..< threads {
            group.enter()
            
            DispatchQueue.global().async {
                while (sentences.count < count) {
                    let sentence = self.makeSentence()
                    
                    if requiredWords.isEmpty {
                        writeQueue.async { sentences.append(sentence) }
                    } else {
                        let sentenceWords = Set(sentence.lowercased().components(separatedBy: " "))
                        let words = Set(requiredWords.map { $0.lowercased() })
                        
                        if words.intersection(sentenceWords).count == requiredWords.count {
                            writeQueue.async { sentences.append(sentence) }
                        }
                    }
                }
                
                group.leave()
            }
        }
        
        group.wait()
        return Array(sentences.suffix(count))
    }
    
    /// Recursive function for building a new sentence
    private func makeSentence(from sentence: String? = nil, previousWord: String? = nil) -> String {
        
        // If we don't already have a sentence and previous word
        guard let sentence = sentence,
            let previousWord = previousWord else {
                
                // Grab a word to start the sentence with
                let startingWord = startingWords.randomElement()
                
                // Continue building the sentence
                return makeSentence(from: startingWord.capitalized, previousWord: startingWord)
        }
        
        // If the previous word has a link
        if let link = links[previousWord] {
            
            // Grab a word from this word's links
            let word = link.randomElement()
            
            switch word {
            // If the link is an end, our sentence is done
            case .end:
                return "\(sentence)."
                
            // If the link is a word, add it to our sentence and continue building
            case .word(let strings):
                return makeSentence(from: "\(sentence) \(strings.joined(separator: " "))", previousWord: strings.last)
            }
        }
        
        // We had no links, return our complete sentence
        return "\(sentence)."
    }
}

// Command line option containers
var paths = [String]()
var collectingPaths = false
var collectingCount = false
var collectingRequiredWords = false
var collectingWordLength = false
var sentenceCount = 1
var requiredWords = [String]()
var parallel = false
var wordLength = 1

// Parse parameters from command line
CommandLine.arguments.forEach { argument in
    
    switch argument {
        
    case "-p":
        collectingPaths = false
        collectingCount = false
        collectingRequiredWords = false
        collectingWordLength = false
        parallel = true
        
    case "-f":
        collectingPaths = true
        collectingCount = false
        collectingRequiredWords = false
        collectingWordLength = false
        
    case "-s":
        collectingPaths = false
        collectingCount = true
        collectingRequiredWords = false
        collectingWordLength = false
        
    case "-r":
        collectingPaths = false
        collectingCount = false
        collectingRequiredWords = true
        collectingWordLength = false
        
        
    case "-w":
        collectingPaths = false
        collectingCount = false
        collectingRequiredWords = false
        collectingWordLength = true
        
    default:
        if collectingPaths {
            paths.append(argument)
        } else if collectingCount {
            sentenceCount = Int(argument) ?? 1
        } else if collectingRequiredWords {
            requiredWords.append(argument)
        } else if collectingWordLength {
            wordLength = Int(argument) ?? 1
        }
    }
    
}

if paths.isEmpty {
    print("Required parameter missing: -f <path/to/file.txt>")
    exit(1)
}

print("Building chain...")
let chain = Chain(paths, wordLength: wordLength)

print("Generating \(sentenceCount) sentence(s)...")
let startDate = Date()
let sentences = chain.makeSentences(count: sentenceCount, requiredWords: requiredWords, parallel: parallel)
let endDate = Date()
print("Finished in \(endDate.timeIntervalSince(startDate)) seconds.")

print("Results:")
print(sentences.joined(separator: "\n\n"))
exit(0)

