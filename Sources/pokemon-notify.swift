import Cocoa
import Foundation

// MARK: - Data Types

struct NotifyStats: Codable {
    var date: String
    var encounters: Int
    var caught: [String: Int]     // pokemon name -> catch count
    var seen: [String: Int]       // pokemon name -> seen count
    var team: [TeamMember]        // last 6 caught
    var shinyCaught: [String]     // shiny pokemon names caught
    var totalCaught: Int
    var totalSeen: Int
}

struct TeamMember: Codable {
    var id: Int
    var name: String
    var isShiny: Bool
}

// MARK: - Stats

func statsPath() -> String {
    NSString(string: "~/.claude/notify-stats.json").expandingTildeInPath
}

func loadStats() -> NotifyStats {
    let today = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }()
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: statsPath())),
          let stats = try? JSONDecoder().decode(NotifyStats.self, from: data) else {
        return NotifyStats(date: today, encounters: 0, caught: [:], seen: [:], team: [], shinyCaught: [], totalCaught: 0, totalSeen: 0)
    }
    if stats.date != today {
        // Keep team and pokedex across days, reset daily encounters
        var fresh = stats
        fresh.date = today
        fresh.encounters = 0
        return fresh
    }
    return stats
}

func saveStats(_ stats: NotifyStats) {
    if let data = try? JSONEncoder().encode(stats) {
        try? data.write(to: URL(fileURLWithPath: statsPath()))
    }
}

// MARK: - Pokemon Data

func loadPokemonNames() -> [String: String] {
    let path = Bundle.main.bundlePath + "/Contents/Resources/pokemon_names.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let names = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
    return names
}

func loadPokemonTypes() -> [String: [String]] {
    let path = Bundle.main.bundlePath + "/Contents/Resources/pokemon_types.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let types = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
    return types
}

// MARK: - Type Colors

func colorForType(_ type: String) -> NSColor {
    switch type {
    case "fire":     return NSColor(red: 0.94, green: 0.50, blue: 0.19, alpha: 1)
    case "water":    return NSColor(red: 0.41, green: 0.56, blue: 0.94, alpha: 1)
    case "grass":    return NSColor(red: 0.47, green: 0.78, blue: 0.31, alpha: 1)
    case "electric": return NSColor(red: 0.97, green: 0.82, blue: 0.19, alpha: 1)
    case "ice":      return NSColor(red: 0.60, green: 0.85, blue: 0.85, alpha: 1)
    case "fighting": return NSColor(red: 0.75, green: 0.19, blue: 0.16, alpha: 1)
    case "poison":   return NSColor(red: 0.63, green: 0.25, blue: 0.63, alpha: 1)
    case "ground":   return NSColor(red: 0.88, green: 0.75, blue: 0.41, alpha: 1)
    case "flying":   return NSColor(red: 0.66, green: 0.56, blue: 0.94, alpha: 1)
    case "psychic":  return NSColor(red: 0.97, green: 0.35, blue: 0.53, alpha: 1)
    case "bug":      return NSColor(red: 0.66, green: 0.72, blue: 0.13, alpha: 1)
    case "rock":     return NSColor(red: 0.72, green: 0.63, blue: 0.22, alpha: 1)
    case "ghost":    return NSColor(red: 0.44, green: 0.35, blue: 0.60, alpha: 1)
    case "dragon":   return NSColor(red: 0.44, green: 0.22, blue: 0.97, alpha: 1)
    case "dark":     return NSColor(red: 0.44, green: 0.35, blue: 0.28, alpha: 1)
    case "steel":    return NSColor(red: 0.72, green: 0.72, blue: 0.82, alpha: 1)
    case "fairy":    return NSColor(red: 0.93, green: 0.60, blue: 0.67, alpha: 1)
    case "normal":   return NSColor(red: 0.66, green: 0.66, blue: 0.47, alpha: 1)
    default:         return NSColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1)
    }
}

// MARK: - Time-based Spawns

func getTimeBiasedPokemon(types: [String: [String]]) -> Int {
    let hour = Calendar.current.component(.hour, from: Date())

    // Night: 20-06, Dawn: 06-08, Day: 08-18, Dusk: 18-20
    var preferredTypes: [String]
    if hour >= 20 || hour < 6 {
        preferredTypes = ["ghost", "dark", "psychic", "poison"]
    } else if hour >= 6 && hour < 8 {
        preferredTypes = ["fairy", "normal", "flying"]
    } else if hour >= 18 && hour < 20 {
        preferredTypes = ["fairy", "ghost", "dark", "fire"]
    } else {
        preferredTypes = ["normal", "grass", "bug", "flying", "water", "fire", "electric"]
    }

    // 60% chance to pick a time-appropriate type, 40% fully random
    if Int.random(in: 0..<100) < 60 {
        // Find Pokemon matching preferred types
        let matching = types.filter { _, pTypes in
            pTypes.contains(where: { preferredTypes.contains($0) })
        }
        if let pick = matching.keys.randomElement(), let id = Int(pick) {
            return id
        }
    }

    return Int.random(in: 1...649)
}

// MARK: - Shiny Check

func isShiny() -> Bool {
    return Int.random(in: 1...4096) == 1
}

// MARK: - Window

class PokemonNotificationWindow: NSWindow {
    let onCatch: () -> Void

    init(title: String, message: String, spritePath: String, pokemonName: String,
         pokemonId: Int, pokemonType: String, isShiny: Bool, stats: NotifyStats, onCatch: @escaping () -> Void) {

        self.onCatch = onCatch
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowWidth: CGFloat = 460
        let windowHeight: CGFloat = 145
        let padding: CGFloat = 16
        let windowFrame = NSRect(
            x: screenFrame.maxX - windowWidth - padding,
            y: screenFrame.maxY - windowHeight - padding,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        // NOT ignoring mouse events — clickable for catch mechanic
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.disableCursorRects()
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = PokemonDialogView(
            title: title, message: message, spritePath: spritePath,
            pokemonName: pokemonName, pokemonId: pokemonId, pokemonType: pokemonType,
            isShiny: isShiny, stats: stats, onCatch: onCatch
        )
        self.contentView = contentView
    }
}

// MARK: - View

class PokemonDialogView: NSView {
    let title: String
    let message: String
    let spritePath: String
    let pokemonName: String
    let pokemonId: Int
    let pokemonType: String
    let shiny: Bool
    let stats: NotifyStats
    let onCatch: () -> Void
    var cursorVisible = true
    var cursorTimer: Timer?
    var typedChars = 0
    var typeTimer: Timer?
    var fullMessage: String
    var spriteImageView: NSImageView?
    var isCaught = false
    var animator: NotificationAnimator?
    var pokeballCursor: NSCursor?
    var pokeballView: NSImageView?

    let bgColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.97)
    let textColor = NSColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1.0)
    let statColor = NSColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1.0)
    let typeColor: NSColor

    init(title: String, message: String, spritePath: String, pokemonName: String,
         pokemonId: Int, pokemonType: String, isShiny: Bool, stats: NotifyStats, onCatch: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.spritePath = spritePath
        self.pokemonName = pokemonName
        self.pokemonId = pokemonId
        self.pokemonType = pokemonType
        self.shiny = isShiny
        self.stats = stats
        self.onCatch = onCatch
        self.typeColor = colorForType(pokemonType)

        if isShiny {
            self.fullMessage = "★ A shiny \(pokemonName.uppercased()) appeared! ★"
        } else {
            self.fullMessage = "Wild \(pokemonName.uppercased()) appeared!"
        }
        super.init(frame: .zero)
        self.wantsLayer = true

        // Load pokeball cursor
        let cursorPath = Bundle.main.bundlePath + "/Contents/Resources/pokeball_cursor.png"
        if let cursorImage = NSImage(contentsOfFile: cursorPath) {
            pokeballCursor = NSCursor(image: cursorImage, hotSpot: NSPoint(x: 16, y: 16))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Enable mouse tracking for cursor changes
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        updatePokeballPosition(event: event)
    }

    override func mouseEntered(with event: NSEvent) {
        showPokeball(event: event)
    }

    override func mouseExited(with event: NSEvent) {
        pokeballView?.isHidden = true
    }

    func showPokeball(event: NSEvent) {
        if pokeballView == nil {
            let cursorPath = Bundle.main.bundlePath + "/Contents/Resources/pokeball_cursor.png"
            if let img = NSImage(contentsOfFile: cursorPath) {
                let iv = NSImageView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
                iv.image = img
                iv.imageScaling = .scaleProportionallyUpOrDown
                addSubview(iv)
                pokeballView = iv
            }
        }
        pokeballView?.isHidden = false
        updatePokeballPosition(event: event)
    }

    func updatePokeballPosition(event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        pokeballView?.frame.origin = NSPoint(x: loc.x + 8, y: loc.y - 28)
    }

    override func mouseDown(with event: NSEvent) {
        guard !isCaught else { return }
        isCaught = true
        onCatch()

        // Update message to "Gotcha!"
        let catchMsg = shiny
            ? "★ Gotcha! \(pokemonName.capitalized) was caught! ★"
            : "Gotcha! \(pokemonName.capitalized) was caught!"
        fullMessage = catchMsg
        typedChars = catchMsg.count
        typeTimer?.invalidate()
        cursorTimer?.invalidate()
        cursorVisible = false
        needsDisplay = true

        // Flash the window
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            self.window?.animator().alphaValue = 0.3
        }) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.1
                self.window?.animator().alphaValue = 1.0
            }) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.1
                    self.window?.animator().alphaValue = 0.3
                }) {
                    NSAnimationContext.runAnimationGroup({ ctx in
                        ctx.duration = 0.1
                        self.window?.animator().alphaValue = 1.0
                    }) {
                        // Dismiss after 1.5s so they can see "Gotcha!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.animator?.dismiss()
                        }
                    }
                }
            }
        }
    }

    override func layout() {
        super.layout()
        if spriteImageView == nil { setupSprite() }
    }

    func setupSprite() {
        let bounds = self.bounds
        let p: CGFloat = 3
        let bgRect = bounds.insetBy(dx: p * 5.5, dy: p * 5.5)
        let spriteSize: CGFloat = 64

        if let gifData = try? Data(contentsOf: URL(fileURLWithPath: spritePath)),
           let image = NSImage(data: gifData) {
            let imageView = NSImageView(frame: NSRect(
                x: bgRect.minX + 10,
                y: bgRect.midY - spriteSize / 2 + 16,
                width: spriteSize,
                height: spriteSize
            ))
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.animates = true
            imageView.canDrawSubviewsIntoLayer = true
            self.addSubview(imageView)
            self.spriteImageView = imageView
        }

        // Load team sprites
        let teamY = bgRect.minY + 4
        let teamSpriteSize: CGFloat = 24
        let teamStartX = bgRect.minX + 84
        for (i, member) in stats.team.prefix(6).enumerated() {
            let subdir = member.isShiny ? "shiny" : ""
            let teamSpritePath = subdir.isEmpty
                ? Bundle.main.bundlePath + "/Contents/Resources/sprites/\(member.id).gif"
                : Bundle.main.bundlePath + "/Contents/Resources/sprites/shiny/\(member.id).gif"

            if let data = try? Data(contentsOf: URL(fileURLWithPath: teamSpritePath)),
               let img = NSImage(data: data) {
                let iv = NSImageView(frame: NSRect(
                    x: teamStartX + CGFloat(i) * (teamSpriteSize + 4),
                    y: teamY,
                    width: teamSpriteSize,
                    height: teamSpriteSize
                ))
                iv.image = img
                iv.imageScaling = .scaleProportionallyUpOrDown
                iv.animates = true
                iv.canDrawSubviewsIntoLayer = true
                self.addSubview(iv)
            }
        }

        self.typeTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.typedChars < self.fullMessage.count {
                self.typedChars += 1
                self.needsDisplay = true
            } else {
                timer.invalidate()
                self.cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.cursorVisible.toggle()
                    self?.needsDisplay = true
                }
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = self.bounds
        let p: CGFloat = 3

        // Type-colored triple border
        let outerRect = bounds.insetBy(dx: p, dy: p)
        typeColor.shadow(withLevel: 0.3)?.setFill()
        NSBezierPath(roundedRect: outerRect, xRadius: p * 3, yRadius: p * 3).fill()

        let midRect = outerRect.insetBy(dx: p, dy: p)
        typeColor.setFill()
        NSBezierPath(roundedRect: midRect, xRadius: p * 2, yRadius: p * 2).fill()

        let innerBorderRect = midRect.insetBy(dx: p, dy: p)
        typeColor.blended(withFraction: 0.5, of: .white)?.setFill()
        NSBezierPath(roundedRect: innerBorderRect, xRadius: p * 2, yRadius: p * 2).fill()

        let bgRect = innerBorderRect.insetBy(dx: p * 1.5, dy: p * 1.5)
        bgColor.setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: p, yRadius: p).fill()

        // Shiny sparkle effect
        if shiny {
            let sparkleColor = NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.6)
            sparkleColor.setFill()
            for _ in 0..<8 {
                let sx = bgRect.minX + CGFloat.random(in: 10...74)
                let sy = bgRect.midY + CGFloat.random(in: -20...30)
                let ss: CGFloat = CGFloat.random(in: 2...5)
                NSRect(x: sx, y: sy, width: ss, height: ss).fill()
            }
        }

        let textX = bgRect.minX + 84

        // Row 1: "Wild X appeared!" with typewriter
        let visibleText = String(fullMessage.prefix(typedChars))
        let font = NSFont(name: "Menlo-Bold", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        let msgColor = shiny ? NSColor(red: 0.85, green: 0.65, blue: 0.0, alpha: 1.0) : textColor
        let textAttrs: [NSAttributedString.Key: Any] = [ .font: font, .foregroundColor: msgColor ]
        (visibleText as NSString).draw(at: NSPoint(x: textX, y: bgRect.maxY - 26), withAttributes: textAttrs)

        // Row 2: Action message + click hint
        let actionFont = NSFont(name: "Menlo", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let actionAttrs: [NSAttributedString.Key: Any] = [ .font: actionFont, .foregroundColor: textColor ]
        ("\(title): \(message)" as NSString).draw(at: NSPoint(x: textX, y: bgRect.maxY - 44), withAttributes: actionAttrs)

        // Row 3: Stats + type
        let statsFont = NSFont(name: "Menlo", size: 9) ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let uniqueSeen = stats.seen.count
        let uniqueCaught = stats.caught.count
        let progress = CGFloat(uniqueCaught) / 649.0
        let idStr = String(format: "#%03d", pokemonId)
        let pct = String(format: "%.1f", progress * 100)
        let hintColor = typeColor.blended(withFraction: 0.2, of: .black) ?? typeColor
        let hintAttrs: [NSAttributedString.Key: Any] = [ .font: statsFont, .foregroundColor: hintColor ]
        ("\(idStr) \(pokemonType.uppercased())" as NSString).draw(at: NSPoint(x: textX, y: bgRect.maxY - 58), withAttributes: hintAttrs)

        // Separator
        statColor.withAlphaComponent(0.3).setFill()
        NSRect(x: textX, y: bgRect.minY + 30, width: bgRect.maxX - textX - 16, height: 1).fill()

        // Pokedex progress bar
        let barX = textX
        let barY = bgRect.minY + 34
        let barW: CGFloat = bgRect.maxX - textX - 16
        let barH: CGFloat = 6

        NSColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barW, height: barH), xRadius: 3, yRadius: 3).fill()

        let seenProgress = CGFloat(uniqueSeen) / 649.0
        typeColor.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barW * seenProgress, height: barH), xRadius: 3, yRadius: 3).fill()

        typeColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barW * progress, height: barH), xRadius: 3, yRadius: 3).fill()

        // Stats below bar
        let statsText = "Caught: \(uniqueCaught)  Seen: \(uniqueSeen)  (\(pct)%)"
        let statsAttrs: [NSAttributedString.Key: Any] = [ .font: statsFont, .foregroundColor: statColor ]
        (statsText as NSString).draw(at: NSPoint(x: textX, y: bgRect.minY + 42), withAttributes: statsAttrs)

        // Team label + sprites at bottom
        if !stats.team.isEmpty {
            let teamFont = NSFont(name: "Menlo", size: 8) ?? NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)
            let teamAttrs: [NSAttributedString.Key: Any] = [ .font: teamFont, .foregroundColor: statColor.withAlphaComponent(0.6) ]
            ("TEAM:" as NSString).draw(at: NSPoint(x: bgRect.minX + 84 - 38, y: bgRect.minY + 6), withAttributes: teamAttrs)
        }

        // Blinking triangle
        if typedChars >= fullMessage.count && cursorVisible {
            let triX = bgRect.maxX - 20
            let triY = bgRect.maxY - 56
            let triSize: CGFloat = p * 2
            let triangle = NSBezierPath()
            triangle.move(to: NSPoint(x: triX, y: triY + triSize * 2))
            triangle.line(to: NSPoint(x: triX + triSize, y: triY))
            triangle.line(to: NSPoint(x: triX - triSize, y: triY))
            triangle.close()
            typeColor.shadow(withLevel: 0.3)?.setFill()
            triangle.fill()
        }
    }
}

// MARK: - Animator

class NotificationAnimator {
    let window: PokemonNotificationWindow
    var dismissed = false

    init(window: PokemonNotificationWindow) {
        self.window = window
    }

    func show() {
        var frame = window.frame
        let finalX = frame.origin.x
        frame.origin.x = (NSScreen.main?.frame.maxX ?? 1440) + 10
        window.setFrame(frame, display: false)
        window.alphaValue = 1.0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(
                NSRect(x: finalX, y: frame.origin.y, width: frame.width, height: frame.height),
                display: true
            )
        })

        // Longer display time — 8 seconds to give time to click
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.dismiss()
        }
    }

    func dismiss() {
        guard !dismissed else { return }
        dismissed = true
        let frame = window.frame
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.window.animator().setFrame(
                NSRect(x: (NSScreen.main?.frame.maxX ?? 1440) + 10, y: frame.origin.y, width: frame.width, height: frame.height),
                display: true
            )
        }) {
            NSApp.terminate(nil)
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let args = CommandLine.arguments
let title = args.count > 1 ? args[1] : "CLAUDE"
let message = args.count > 2 ? args[2] : "wants your attention!"

let names = loadPokemonNames()
let types = loadPokemonTypes()

// Time-based spawn
let pokemonId = getTimeBiasedPokemon(types: types)
let pokemonName = names[String(pokemonId)] ?? "Pokemon #\(pokemonId)"
let pokemonTypes = types[String(pokemonId)] ?? ["normal"]
let primaryType = pokemonTypes.first ?? "normal"
let shiny = isShiny()

// Sprite path
let bundlePath = Bundle.main.bundlePath
let spritePath: String
if shiny {
    let shinyPath = "\(bundlePath)/Contents/Resources/sprites/shiny/\(pokemonId).gif"
    if FileManager.default.fileExists(atPath: shinyPath) {
        spritePath = shinyPath
    } else {
        spritePath = "\(bundlePath)/Contents/Resources/sprites/\(pokemonId).gif"
    }
} else {
    spritePath = "\(bundlePath)/Contents/Resources/sprites/\(pokemonId).gif"
}

// Update stats — mark as seen
var stats = loadStats()
stats.encounters += 1
stats.seen[pokemonName] = (stats.seen[pokemonName] ?? 0) + 1
stats.totalSeen += 1

// Save initial seen state
saveStats(stats)

// Catch callback
let catchPokemon = {
    var s = loadStats()
    s.caught[pokemonName] = (s.caught[pokemonName] ?? 0) + 1
    s.totalCaught += 1

    if shiny && !s.shinyCaught.contains(pokemonName) {
        s.shinyCaught.append(pokemonName)
    }

    // Update team (last 6 caught)
    let member = TeamMember(id: pokemonId, name: pokemonName, isShiny: shiny)
    s.team.insert(member, at: 0)
    if s.team.count > 6 { s.team = Array(s.team.prefix(6)) }

    saveStats(s)

    // Open iTerm2
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

let window = PokemonNotificationWindow(
    title: title, message: message, spritePath: spritePath,
    pokemonName: pokemonName, pokemonId: pokemonId, pokemonType: primaryType,
    isShiny: shiny, stats: stats, onCatch: catchPokemon
)
let animator = NotificationAnimator(window: window)
(window.contentView as? PokemonDialogView)?.animator = animator

DispatchQueue.main.async {
    animator.show()
}

app.run()
