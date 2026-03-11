import Foundation
import Speech
import AVFoundation

// Unbuffered stdout
setbuf(stdout, nil)

guard SFSpeechRecognizer.authorizationStatus() == .authorized ||
      SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
    print("ERROR:Speech recognition not authorized")
    exit(1)
}

SFSpeechRecognizer.requestAuthorization { status in
    guard status == .authorized else {
        print("ERROR:Speech recognition denied")
        exit(1)
    }
}

let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
guard recognizer.isAvailable else {
    print("ERROR:Speech recognizer not available")
    exit(1)
}

let audioEngine = AVAudioEngine()
let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = true
request.requiresOnDeviceRecognition = true

let node = audioEngine.inputNode
let format = node.outputFormat(forBus: 0)

node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
    request.append(buffer)
}

audioEngine.prepare()
do {
    try audioEngine.start()
    print("READY")
} catch {
    print("ERROR:Failed to start audio engine: \(error.localizedDescription)")
    exit(1)
}

var lastText = ""

recognizer.recognitionTask(with: request) { result, error in
    if let result = result {
        let text = result.bestTranscription.formattedString
        if text != lastText {
            lastText = text
            let prefix = result.isFinal ? "FINAL" : "PARTIAL"
            print("\(prefix):\(text)")
        }
    }
    if let error = error {
        // Task finished errors are normal on kill
        let nsError = error as NSError
        if nsError.code != 216 { // kAFAssistantErrorDomain code for cancelled
            print("ERROR:\(error.localizedDescription)")
        }
    }
}

// Handle SIGTERM/SIGINT gracefully
signal(SIGTERM) { _ in
    exit(0)
}
signal(SIGINT) { _ in
    exit(0)
}

RunLoop.current.run()
