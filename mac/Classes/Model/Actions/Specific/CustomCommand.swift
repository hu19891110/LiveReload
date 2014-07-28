import Foundation
import LRCommons
import LRActionKit

@objc
class CustomCommandRule : Rule {

    var command: String? {
        didSet {
            if (command != oldValue) {
                didChange()
            }
        }
    }

    override var nonEmpty: Bool {
        return command != nil
    }

    var singleLineCommand: String? {
        return command?.stringByReplacingOccurrencesOfString("\n", withString: "; ")
    }

    override var label: String {
        if let command = singleLineCommand {
            return "Run \(command)"
        } else {
            return NSLocalizedString("Run custom command", comment: "")
        }
    }

    class func keyPathsForValuesAffectingLabel() -> NSSet {
        return NSSet(object: "command")
    }

    class func keyPathsForValuesAffectingNonEmpty() -> NSSet {
        return NSSet(object: "command")
    }

    class func keyPathsForValuesAffectingSingleLineCommand() -> NSSet {
        return NSSet(object: "command")
    }

    override func loadFromMemento() {
        super.loadFromMemento()
        command = EmptyToNilCast(memento["command"])
    }

    override func updateMemento() {
        super.updateMemento()
        memento["command"] = NV(command, "")
    }

    override func targetForModifiedFiles(files: [ProjectFile]) -> LRTarget? {
        if inputPathSpecMatchesFiles(files) {
            return LRProjectTarget(rule: self, modifiedFiles: files as [ProjectFile])
        } else {
            return nil
        }
    }

    override func invokeWithModifiedFiles(files: [ProjectFile], result: LROperationResult, completionHandler: dispatch_block_t) {
        let info = [
            "$(ruby)": "/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby",
            "$(node)": NSBundle.mainBundle().pathForResource("LiveReloadNodejs", ofType: nil)!,
            "$(project_dir)": project.rootURL.path
        ]
        let command = (self.command! as NSString).stringBySubstitutingValuesFromDictionary(info) as String
        let shell = "/bin/bash"

        let shArgs = ["-c", command]  // ["--login", "-i", "-c", command]

        let pwd = NSFileManager.defaultManager().currentDirectoryPath
        NSFileManager.defaultManager().changeCurrentDirectoryPath(project.rootURL.path)

        NSLog("Executing project rule command: %@", (([shell] + shArgs) as NSArray).quotedArgumentStringUsingBourneQuotingStyle());

        let shellUrl = NSURL.fileURLWithPath(shell)

        ATLaunchUnixTaskAndCaptureOutput(shellUrl, shArgs, .IgnoreSandbox | .MergeStdoutAndStderr, [ATCurrentDirectoryPathKey!: project.rootURL.path]) {
            (outputText: String!, stderrText: String?, error: NSError?) in
            NSFileManager.defaultManager().changeCurrentDirectoryPath(pwd)
            result.completedWithInvocationError(error, rawOutput: outputText, completionBlock: completionHandler)
        }
    }

}
