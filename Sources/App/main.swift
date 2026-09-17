import AppKit

@main
enum JetmojiMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("--self-test") {
            do {
                try SelfTests.run()
                print("jetmoji self-test ok")
                exit(0)
            } catch {
                fputs("jetmoji self-test failed: \(error)\n", stderr)
                exit(1)
            }
        }
        if args.first == "--cli" || args.first == "help" || args.first == "--help" || args.first == "-h" {
            CLI.run(arguments: args.first == "--cli" ? Array(args.dropFirst()) : args)
            return
        }
        if let first = args.first, CLI.commands.contains(first) {
            CLI.run(arguments: args)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
