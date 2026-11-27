import AppKit

final class PopoverCardView: NSView {
    var theme: AppTheme = .midnight {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        let gradient = NSGradient(starting: theme.cardTop, ending: theme.cardBottom)
        gradient?.draw(in: path, angle: -90)
        theme.cardBorder.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class PopoverViewController: NSViewController {
    var onToggleUnit: (() -> Void)?
    var onSelectTheme: ((AppTheme) -> Void)?
    var onResetSession: (() -> Void)?
    var onQuit: (() -> Void)?

    private let cardView = PopoverCardView()
    private let dotView = NSView()
    private let interfaceLabel = NSTextField(labelWithString: "No Active Interface")
    private let unitButton = NSButton(title: "B/s", target: nil, action: nil)
    private let dividerView = NSView()

    private let downTitleLabel = NSTextField(labelWithString: "DOWNLOAD")
    private let downSpeedLabel = NSTextField(labelWithString: "0.0 KB/s")
    private let downSubLabel = NSTextField(labelWithString: "Peak 0.0 KB/s · 0.0 KB")

    private let upTitleLabel = NSTextField(labelWithString: "UPLOAD")
    private let upSpeedLabel = NSTextField(labelWithString: "0.0 KB/s")
    private let upSubLabel = NSTextField(labelWithString: "Peak 0.0 KB/s · 0.0 KB")

    private let sparklineView = SparklineView()
    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)

    private var currentTheme: AppTheme = .midnight

    override func loadView() {
        cardView.frame = NSRect(x: 0, y: 0, width: 300, height: 204)
        self.view = cardView
        setupUI()
        applyTheme(.midnight)
    }

    private func setupUI() {
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 3.5

        interfaceLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        interfaceLabel.lineBreakMode = .byTruncatingTail

        unitButton.bezelStyle = .inline
        unitButton.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        unitButton.target = self
        unitButton.action = #selector(handleUnitTap)

        dividerView.wantsLayer = true

        downTitleLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .bold)
        upTitleLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .bold)

        downSpeedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 15.5, weight: .semibold)
        upSpeedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 15.5, weight: .semibold)

        downSubLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .regular)
        downSubLabel.lineBreakMode = .byTruncatingTail
        upSubLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .regular)
        upSubLabel.lineBreakMode = .byTruncatingTail

        themePopup.controlSize = .small
        themePopup.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        for t in AppTheme.allCases {
            themePopup.addItem(withTitle: t.rawValue)
        }
        themePopup.target = self
        themePopup.action = #selector(handleThemeChange)

        resetButton.bezelStyle = .inline
        resetButton.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        resetButton.target = self
        resetButton.action = #selector(handleResetTap)

        quitButton.bezelStyle = .inline
        quitButton.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        quitButton.target = self
        quitButton.action = #selector(handleQuitTap)

        let views: [NSView] = [
            dotView, interfaceLabel, unitButton, dividerView,
            downTitleLabel, downSpeedLabel, downSubLabel,
            upTitleLabel, upSpeedLabel, upSubLabel,
            sparklineView, themePopup, resetButton, quitButton
        ]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let pad: CGFloat = 14
        NSLayoutConstraint.activate([
            dotView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            dotView.centerYAnchor.constraint(equalTo: interfaceLabel.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 7),
            dotView.heightAnchor.constraint(equalToConstant: 7),

            interfaceLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 7),
            interfaceLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            interfaceLabel.trailingAnchor.constraint(lessThanOrEqualTo: unitButton.leadingAnchor, constant: -8),

            unitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            unitButton.centerYAnchor.constraint(equalTo: interfaceLabel.centerYAnchor),

            dividerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            dividerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            dividerView.topAnchor.constraint(equalTo: interfaceLabel.bottomAnchor, constant: 9),
            dividerView.heightAnchor.constraint(equalToConstant: 1),

            downTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            downTitleLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 10),

            upTitleLabel.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 6),
            upTitleLabel.topAnchor.constraint(equalTo: downTitleLabel.topAnchor),

            downSpeedLabel.leadingAnchor.constraint(equalTo: downTitleLabel.leadingAnchor),
            downSpeedLabel.topAnchor.constraint(equalTo: downTitleLabel.bottomAnchor, constant: 2),

            upSpeedLabel.leadingAnchor.constraint(equalTo: upTitleLabel.leadingAnchor),
            upSpeedLabel.topAnchor.constraint(equalTo: upTitleLabel.bottomAnchor, constant: 2),

            downSubLabel.leadingAnchor.constraint(equalTo: downTitleLabel.leadingAnchor),
            downSubLabel.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -4),
            downSubLabel.topAnchor.constraint(equalTo: downSpeedLabel.bottomAnchor, constant: 2),

            upSubLabel.leadingAnchor.constraint(equalTo: upTitleLabel.leadingAnchor),
            upSubLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            upSubLabel.topAnchor.constraint(equalTo: upSpeedLabel.bottomAnchor, constant: 2),

            sparklineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            sparklineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            sparklineView.topAnchor.constraint(equalTo: downSubLabel.bottomAnchor, constant: 10),
            sparklineView.heightAnchor.constraint(equalToConstant: 56),

            themePopup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            themePopup.topAnchor.constraint(equalTo: sparklineView.bottomAnchor, constant: 10),
            themePopup.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            quitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            quitButton.centerYAnchor.constraint(equalTo: themePopup.centerYAnchor),

            resetButton.trailingAnchor.constraint(equalTo: quitButton.leadingAnchor, constant: -6),
            resetButton.centerYAnchor.constraint(equalTo: themePopup.centerYAnchor)
        ])
    }

    func update(
        theme: AppTheme,
        useBits: Bool,
        interfaceName: String,
        downBps: Double,
        upBps: Double,
        peakDownBps: Double,
        peakUpBps: Double,
        sessionDown: UInt64,
        sessionUp: UInt64,
        downHistory: [Double],
        upHistory: [Double]
    ) {
        if currentTheme != theme {
            applyTheme(theme)
        }
        themePopup.selectItem(withTitle: theme.rawValue)
        unitButton.title = useBits ? "bps" : "B/s"
        interfaceLabel.stringValue = interfaceName

        downSpeedLabel.stringValue = NetworkMonitor.formatSpeed(downBps, useBits: useBits)
        upSpeedLabel.stringValue = NetworkMonitor.formatSpeed(upBps, useBits: useBits)

        downSubLabel.stringValue = "Peak \(NetworkMonitor.formatSpeed(peakDownBps, useBits: useBits)) · \(NetworkMonitor.formatBytes(sessionDown))"
        upSubLabel.stringValue = "Peak \(NetworkMonitor.formatSpeed(peakUpBps, useBits: useBits)) · \(NetworkMonitor.formatBytes(sessionUp))"

        sparklineView.update(downloadHistory: downHistory, uploadHistory: upHistory, theme: theme)
    }

    private func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        cardView.theme = theme
        view.appearance = NSAppearance(named: theme.isLight ? .aqua : .darkAqua)

        dotView.layer?.backgroundColor = theme.liveDot.cgColor
        interfaceLabel.textColor = theme.primaryText
        dividerView.layer?.backgroundColor = theme.divider.cgColor

        downTitleLabel.textColor = theme.downloadAccent
        upTitleLabel.textColor = theme.uploadAccent
        downSpeedLabel.textColor = theme.primaryText
        upSpeedLabel.textColor = theme.primaryText
        downSubLabel.textColor = theme.mutedText
        upSubLabel.textColor = theme.mutedText
    }

    @objc private func handleUnitTap() { onToggleUnit?() }
    @objc private func handleResetTap() { onResetSession?() }
    @objc private func handleQuitTap() { onQuit?() }

    @objc private func handleThemeChange() {
        guard let title = themePopup.selectedItem?.title,
              let selected = AppTheme(rawValue: title) else { return }
        onSelectTheme?(selected)
    }
}
