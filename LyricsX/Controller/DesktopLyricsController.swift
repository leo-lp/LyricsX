//
//  DesktopLyricsController.swift
//  LyricsX
//
//  Created by 邓翔 on 2017/2/4.
//
//  Copyright (C) 2017  Xander Deng
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Cocoa
import SnapKit
import OpenCC
import EasyPreference

class DesktopLyricsWindowController: NSWindowController {
    
    override func windowDidLoad() {
        if let mainScreen = NSScreen.main() {
            window?.setFrame(mainScreen.visibleFrame, display: true)
        }
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.ignoresMouseEvents = true
        window?.level = Int(CGWindowLevelForKey(.floatingWindow))
        if Preference[.DisableLyricsWhenSreenShot] {
            window?.sharingType = .none
        }
        
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(updateWindowFrame), name: .NSWorkspaceActiveSpaceDidChange, object: nil)
    }
    
    func updateWindowFrame() {
        guard let mainScreen = NSScreen.main() else {
            return
        }
        let frame = isFullScreen() == true ? mainScreen.frame : mainScreen.visibleFrame
        window?.setFrame(frame, display: true, animate: true)
    }
    
    func isFullScreen() -> Bool? {
        guard let windowInfoList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in windowInfoList {
            if info[kCGWindowOwnerName as String] as? String == "Window Server",
                info[kCGWindowName as String] as? String == "Menubar" {
                return false
            }
        }
        return true
    }
}

class DesktopLyricsViewController: NSViewController {
    
    @IBOutlet weak var lyricsView: KaraokeLyricsView!
    @IBOutlet weak var lyricsHeightConstraint: NSLayoutConstraint!
    
    private var chineseConverter: ChineseConverter?
    
    var currentLyricsPosition: TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch Preference[.ChineseConversionIndex] {
        case 1:
            chineseConverter = ChineseConverter(option: [.simplify])
        case 2:
            chineseConverter = ChineseConverter(option: [.traditionalize])
        default:
            chineseConverter = nil
        }
        
        let dfs = UserDefaults.standard
        let transOpt = [NSValueTransformerNameBindingOption: NSValueTransformerName.keyedUnarchiveFromDataTransformerName]
        lyricsView.bind("fontName", to: dfs, withKeyPath: EasyPreference.Keys.DesktopLyricsFontName.rawValue, options: nil)
        lyricsView.bind("fontSize", to: dfs, withKeyPath: EasyPreference.Keys.DesktopLyricsFontSize.rawValue, options: nil)
        lyricsView.bind("textColor", to: dfs, withKeyPath: EasyPreference.Keys.DesktopLyricsColor.rawValue, options: transOpt)
        lyricsView.bind("shadowColor", to: dfs, withKeyPath: EasyPreference.Keys.DesktopLyricsShadowColor.rawValue, options: transOpt)
        lyricsView.bind("fillColor", to: dfs, withKeyPath: EasyPreference.Keys.DesktopLyricsBackgroundColor.rawValue, options: transOpt)
        
        lyricsHeightConstraint.constant = CGFloat(Preference[.DesktopLyricsHeighFromDock])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.displayLrc("")
            self.addObserver()
        }
    }
    
    private func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handlePositionChange), name: .PositionChange, object: nil)
        
        Preference.addObserver(key: .DesktopLyricsHeighFromDock) { change in
            self.lyricsHeightConstraint.constant = CGFloat(change.newValue)
        }
        
        Preference.addObserver(key: .DesktopLyricsShadowColor) { change in
            self.lyricsView.shadowColor = change.newValue
        }
        
        Preference.addObserver(key: .ChineseConversionIndex) { change in
            switch change.newValue {
            case 1:
                self.chineseConverter = ChineseConverter(option: [.simplify])
            case 2:
                self.chineseConverter = ChineseConverter(option: [.traditionalize])
            default:
                self.chineseConverter = nil
            }
        }
    }
    
    func handlePositionChange(_ n: Notification) {
        let lrc = n.userInfo?["lrc"] as? LyricsLine
        let next = n.userInfo?["next"] as? LyricsLine
        
        guard currentLyricsPosition != lrc?.position else {
            return
        }
        
        currentLyricsPosition = lrc?.position ?? 0
        
        let firstLine = lrc?.sentence
        let secondLine: String?
        if Preference[.PreferBilingualLyrics] {
            secondLine = lrc?.translation ?? next?.sentence
        } else {
            secondLine = next?.sentence
        }
        
        displayLrc(firstLine, secondLine: secondLine)
    }
    
    func displayLrc(_ firstLine: String?, secondLine: String? = nil) {
        guard Preference[.DesktopLyricsEnabled] else {
            return
        }
        
        var firstLine = firstLine ?? ""
        var secondLine = secondLine ?? ""
        if let converter = chineseConverter {
            firstLine = converter.convert(firstLine)
            secondLine = converter.convert(secondLine)
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.1, 0.2, 1)
            self.lyricsView.firstLine = firstLine
            self.lyricsView.secondLine = secondLine
            self.lyricsView.onAnimation = true
            self.view.needsUpdateConstraints = true
            self.view.needsLayout = true
            self.view.layoutSubtreeIfNeeded()
        }, completionHandler: {
            self.lyricsView.onAnimation = false
            self.view.needsUpdateConstraints = true
            self.view.needsLayout = true
            self.view.layoutSubtreeIfNeeded()
        })
    }
    
}
