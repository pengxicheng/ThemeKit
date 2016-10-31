//
//  NSWindow+ThemeKit.swift
//  ThemeKit
//
//  Created by Nuno Grilo on 08/09/16.
//  Copyright © 2016 Paw Inc. All rights reserved.
//

import Foundation

/**
 `NSWindow` extensions.
 Jazzy will fail to generate documentation for this extension.
 Check https://github.com/realm/jazzy/pull/508 and https://github.com/realm/jazzy/issues/502
 */
public extension NSWindow {
    
    // MARK:- Public
    
    /// Any window specific theme.
    ///
    /// This is, usually, `nil`, which means the current global theme will be used.
    /// Please note that when using window specific themes, only the associated
    /// `NSAppearance` will be automatically set. All theme aware assets (`ThemeColor`,
    /// `ThemeGradient` and `ThemeImage`) should call methods that returns a
    /// resolved color instead (which means they don't change with the theme change,
    /// you need to observe theme changes manually, and set colors afterwards):
    ///
    /// - `ThemeColor.color(for view:, selector:)`
    /// - `ThemeGradient.gradient(for view:, selector:)`
    /// - `ThemeImage.image(for view:, selector:)`
    ///
    /// Additionaly, please note that system overriden colors (`NSColor.*`) will
    /// always use the global theme.
    public var windowTheme: Theme? {
        get {
            return objc_getAssociatedObject(self, &themeAssociationKey) as? Theme
        }
        set(newValue) {
            objc_setAssociatedObject(self, &themeAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            theme()
        }
    }
    
    /// Returns the current effective theme (read-only).
    public var windowEffectiveTheme: Theme {
        return windowTheme ?? ThemeKit.shared.effectiveTheme
    }
    
    /// Returns the current effective appearance (read-only).
    public var windowEffectiveThemeAppearance: NSAppearance {
        return windowEffectiveTheme.isLightTheme ? ThemeKit.shared.lightAppearance : ThemeKit.shared.darkAppearance
    }
    
    /// Theme window if needed.
    public func theme() {
        // Change window tab bar appearance
        themeTabBar()
        
        // Change window appearance
        themeWindow()
    }
    
    /// Theme window if compliant to ThemeKit.windowThemePolicy (and if needed).
    public func themeIfCompliantWithWindowThemePolicy() {
        if isCompliantWithWindowThemePolicy() {
            theme()
        }
    }
    
    /// Theme all windows compliant to ThemeKit.windowThemePolicy (and if needed).
    public static func themeAllWindows() {
        for window in windowsCompliantWithWindowThemePolicy() {
            window.theme()
        }
    }
    
    
    // MARK:- Private
    // MARK:- Window theme policy compliance
    
    /// Check if window is compliant with ThemeKit.windowThemePolicy.
    internal func isCompliantWithWindowThemePolicy() -> Bool {
        switch ThemeKit.shared.windowThemePolicy {
            
        case .themeAllWindows:
            return !self.isExcludedFromTheming
            
        case .themeSomeWindows(let windowClasses):
            for windowClass in windowClasses {
                if self.classForCoder === windowClass.self {
                    return true
                }
            }
            return false
            
        case .doNotThemeSomeWindows(let windowClasses):
            for windowClass in windowClasses {
                if self.classForCoder === windowClass.self {
                    return false
                }
            }
            return true
            
        case .doNotThemeWindows:
            return false
        }
    }
    
    /// List of all existing windows compliant to ThemeKit.windowThemePolicy.
    internal static func windowsCompliantWithWindowThemePolicy() -> [NSWindow] {
        var windows = [NSWindow]()
        
        switch ThemeKit.shared.windowThemePolicy {
            
        case .themeAllWindows:
            windows = NSApplication.shared().windows
            
        case .themeSomeWindows:
            windows = NSApplication.shared().windows.filter({ (window) -> Bool in
                return window.isCompliantWithWindowThemePolicy()
            })
            
        case .doNotThemeSomeWindows:
            windows = NSApplication.shared().windows.filter({ (window) -> Bool in
                return window.isCompliantWithWindowThemePolicy()
            })
            
        case .doNotThemeWindows:
            break
        }
        
        return windows
    }
    
    /// Returns if current window is excluded from theming
    internal var isExcludedFromTheming: Bool {
        return self is NSPanel
    }
    
    
    // MARK:- Window screenshots
    
    /// Take window screenshot.
    internal func takeScreenshot() -> NSImage {
        let cgImage = CGWindowListCreateImage(CGRect.null, .optionIncludingWindow, CGWindowID(windowNumber), .boundsIgnoreFraming)
        let image = NSImage(cgImage: cgImage!, size: frame.size)
        image.cacheMode = NSImageCacheMode.never
        image.size = frame.size
        return image
    }
    
    /// Create a window with a screenshot of current window.
    internal func makeScreenshotWindow() -> NSWindow {
        // Take window screenshot
        let screenshot = takeScreenshot()
        
        // Create "image-window"
        let window = NSWindow(contentRect: frame, styleMask: NSWindowStyleMask.borderless, backing: NSBackingStoreType.buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = NSWindowCollectionBehavior.stationary
        window.titlebarAppearsTransparent = true
        
        // Add image view
        let imageView = NSImageView(frame: NSMakeRect(0, 0, screenshot.size.width, screenshot.size.height))
        imageView.image = screenshot
        window.contentView?.addSubview(imageView)
        
        return window
    }
    
    
    // MARK:- Tab bar view
    
    /// Returns the tab bar view.
    private var tabBar: NSView? {
        // If we found before, return it
        if windowTabBar != nil {
            return windowTabBar
        }
        
        var tabBar: NSView?
        
        // Search on titlebar accessory views if supported (will fail if tab bar is hidden)
        let themeFrame = self.contentView?.superview
        if themeFrame?.responds(to: #selector(getter: titlebarAccessoryViewControllers)) ?? false {
            for controller: NSTitlebarAccessoryViewController in self.titlebarAccessoryViewControllers {
                let possibleTabBar = controller.view.deepSubview(withClassName: "NSTabBar")
                if possibleTabBar != nil {
                    tabBar = possibleTabBar
                    break
                }
            }
        }
        
        // Search down the title bar view
        if tabBar == nil {
            let titlebarContainerView = themeFrame?.deepSubview(withClassName: "NSTitlebarContainerView")
            let titlebarView = titlebarContainerView?.deepSubview(withClassName: "NSTitlebarView")
            tabBar = titlebarView?.deepSubview(withClassName: "NSTabBar")
        }
        
        // Remember it
        if tabBar != nil {
            windowTabBar = tabBar
        }
        
        return tabBar
    }
    
    /// Holds a reference to tabbar as associated object
    private var windowTabBar: NSView? {
        get {
            return objc_getAssociatedObject(self, &tabbarAssociationKey) as? NSView
        }
        set(newValue) {
            objc_setAssociatedObject(self, &tabbarAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Check if tab bar is visbile.
    private var isTabBarVisible: Bool {
        return tabBar?.superview != nil;
    }
    
    /// Update window appearance (if needed).
    private func themeWindow() {
        if appearance != windowEffectiveThemeAppearance {
            // Change window appearance
            appearance = windowEffectiveThemeAppearance
            
            // Invalidate shadow as sometimes it is incorrecty drawn or missing
            invalidateShadow()
            
            if #available(macOS 10.12, *) {
                // We're all good here: windows are properly refreshed!
            }
            else {
                // Need a trick to force update of all CALayers down the view hierarchy
                self.titlebarAppearsTransparent = !self.titlebarAppearsTransparent
                DispatchQueue.main.async {
                    self.titlebarAppearsTransparent = !self.titlebarAppearsTransparent
                }
            }
        }
    }
    
    /// Update tab bar appearance (if needed).
    private func themeTabBar() {
        if isTabBarVisible {
            if let _tabBar = tabBar, _tabBar.appearance != windowEffectiveThemeAppearance {
                // Change tabbar appearance...
                _tabBar.appearance = windowEffectiveThemeAppearance
                // ... and tabbar subviews appearance as well
                for tabBarSubview: NSView in (tabBar?.subviews)! {
                    tabBarSubview.needsDisplay = true
                }
                // Also, make sure tabbar is on top (this also properly refreshes it)
                let tabbarSuperview = _tabBar.superview
                tabbarSuperview?.addSubview(_tabBar)
            }
        }
    }
    
    
    // MARK:- Title bar view
    
    /// Returns the title bar view.
    private var titlebarView: NSView? {
        let themeFrame = self.contentView?.superview
        let titlebarContainerView = themeFrame?.deepSubview(withClassName: "NSTitlebarContainerView")
        return titlebarContainerView?.deepSubview(withClassName: "NSTitlebarView")
    }
}

private var themeAssociationKey: UInt8 = 0
private var tabbarAssociationKey: UInt8 = 1
