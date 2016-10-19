/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import SnapKit
import Storage
import ReadingList
import Shared
import IGListKit

struct TabTrayControllerUX {
    static let CornerRadius = CGFloat(4.0)
    static let BackgroundColor = UIConstants.AppBackgroundColor
    static let CellBackgroundColor = UIColor(red:0.95, green:0.95, blue:0.95, alpha:1)
    static let TextBoxHeight = CGFloat(32.0)
    static let FaviconSize = CGFloat(18.0)
    static let Margin = CGFloat(15)
    static let ToolbarBarTintColor = UIConstants.AppBackgroundColor
    static let ToolbarButtonOffset = CGFloat(10.0)
    static let CloseButtonSize = CGFloat(18.0)
    static let CloseButtonMargin = CGFloat(6.0)
    static let CloseButtonEdgeInset = CGFloat(10)

    static let NumberOfColumnsThin = 1
    static let NumberOfColumnsWide = 3
    static let CompactNumberOfColumnsThin = 2

    static let MenuFixedWidth: CGFloat = 320
    
    static let RearrangeWobblePeriod: NSTimeInterval = 0.1
    static let RearrangeTransitionDuration: NSTimeInterval = 0.2
    static let RearrangeWobbleAngle: CGFloat = 0.02
    static let RearrangeDragScale: CGFloat = 1.1
    static let RearrangeDragAlpha: CGFloat = 0.9

    // Moved from UIConstants temporarily until animation code is merged
    static var StatusBarHeight: CGFloat {
        if UIScreen.mainScreen().traitCollection.verticalSizeClass == .Compact {
            return 0
        }
        return 20
    }
}

struct LightTabCellUX {
    static let TabTitleTextColor = UIColor.blackColor()
}

struct DarkTabCellUX {
    static let TabTitleTextColor = UIColor.whiteColor()
}

protocol TabCellDelegate: class {
    func tabCellDidClose(cell: TabCell)
}

class TabCell: UICollectionViewCell {
    enum Style {
        case Light
        case Dark
    }

    static let Identifier = "TabCellIdentifier"

    var style: Style = .Light {
        didSet {
            applyStyle(style)
        }
    }

    let backgroundHolder = UIView()
    let background = UIImageViewAligned()
    let titleText: UILabel
    let innerStroke: InnerStrokedView
    let favicon: UIImageView = UIImageView()
    let closeButton: UIButton

    var title: UIVisualEffectView!
    var animator: SwipeAnimator!

    var isBeingArranged: Bool = false {
        didSet {
            if isBeingArranged {
                self.contentView.transform = CGAffineTransformMakeRotation(TabTrayControllerUX.RearrangeWobbleAngle)
                UIView.animateWithDuration(TabTrayControllerUX.RearrangeWobblePeriod, delay: 0, options: [.AllowUserInteraction, .Repeat, .Autoreverse], animations: {
                    self.contentView.transform = CGAffineTransformMakeRotation(-TabTrayControllerUX.RearrangeWobbleAngle)
                }, completion: nil)
            } else {
                if oldValue {
                    UIView.animateWithDuration(TabTrayControllerUX.RearrangeTransitionDuration, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
                        self.contentView.transform = CGAffineTransformIdentity
                    }, completion: nil)
                }
            }
        }
    }

    weak var delegate: TabCellDelegate?

    // Changes depending on whether we're full-screen or not.
    var margin = CGFloat(0)

    override init(frame: CGRect) {
        self.backgroundHolder.backgroundColor = UIColor.whiteColor()
        self.backgroundHolder.layer.cornerRadius = TabTrayControllerUX.CornerRadius
        self.backgroundHolder.clipsToBounds = true
        self.backgroundHolder.backgroundColor = TabTrayControllerUX.CellBackgroundColor

        self.background.contentMode = UIViewContentMode.ScaleAspectFill
        self.background.clipsToBounds = true
        self.background.userInteractionEnabled = false
        self.background.alignLeft = true
        self.background.alignTop = true

        self.favicon.backgroundColor = UIColor.clearColor()
        self.favicon.layer.cornerRadius = 2.0
        self.favicon.layer.masksToBounds = true

        self.titleText = UILabel()
        self.titleText.textAlignment = NSTextAlignment.Left
        self.titleText.userInteractionEnabled = false
        self.titleText.numberOfLines = 1
        self.titleText.font = DynamicFontHelper.defaultHelper.DefaultSmallFontBold

        self.closeButton = UIButton()
        self.closeButton.setImage(UIImage(named: "stop"), forState: UIControlState.Normal)
        self.closeButton.tintColor = UIColor.lightGrayColor()
        self.closeButton.imageEdgeInsets = UIEdgeInsetsMake(TabTrayControllerUX.CloseButtonEdgeInset, TabTrayControllerUX.CloseButtonEdgeInset, TabTrayControllerUX.CloseButtonEdgeInset, TabTrayControllerUX.CloseButtonEdgeInset)

        self.innerStroke = InnerStrokedView(frame: self.backgroundHolder.frame)
        self.innerStroke.layer.backgroundColor = UIColor.clearColor().CGColor

        super.init(frame: frame)
        
        self.animator = SwipeAnimator(animatingView: self.backgroundHolder, container: self)
        self.closeButton.addTarget(self, action: #selector(TabCell.SELclose), forControlEvents: UIControlEvents.TouchUpInside)

        contentView.addSubview(backgroundHolder)
        backgroundHolder.addSubview(self.background)
        backgroundHolder.addSubview(innerStroke)

        // Default style is light
        applyStyle(style)

        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: NSLocalizedString("Close", comment: "Accessibility label for action denoting closing a tab in tab list (tray)"), target: self.animator, selector: #selector(SwipeAnimator.SELcloseWithoutGesture))
        ]
    }

    private func applyStyle(style: Style) {
        self.title?.removeFromSuperview()

        let title: UIVisualEffectView
        switch style {
        case .Light:
            title = UIVisualEffectView(effect: UIBlurEffect(style: .ExtraLight))
            self.titleText.textColor = LightTabCellUX.TabTitleTextColor
        case .Dark:
            title = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
            self.titleText.textColor = DarkTabCellUX.TabTitleTextColor
        }

        titleText.backgroundColor = UIColor.clearColor()

        title.addSubview(self.closeButton)
        title.addSubview(self.titleText)
        title.addSubview(self.favicon)

        backgroundHolder.addSubview(title)
        self.title = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = frame.width
        let h = frame.height
        backgroundHolder.frame = CGRect(x: margin,
            y: margin,
            width: w,
            height: h)
        background.frame = CGRect(origin: CGPointMake(0, 0), size: backgroundHolder.frame.size)

        title.frame = CGRect(x: 0,
            y: 0,
            width: backgroundHolder.frame.width,
            height: TabTrayControllerUX.TextBoxHeight)

        favicon.frame = CGRect(x: 6,
            y: (TabTrayControllerUX.TextBoxHeight - TabTrayControllerUX.FaviconSize)/2,
            width: TabTrayControllerUX.FaviconSize,
            height: TabTrayControllerUX.FaviconSize)

        let titleTextLeft = favicon.frame.origin.x + favicon.frame.width + 6
        titleText.frame = CGRect(x: titleTextLeft,
            y: 0,
            width: title.frame.width - titleTextLeft - margin  - TabTrayControllerUX.CloseButtonSize - TabTrayControllerUX.CloseButtonMargin * 2,
            height: title.frame.height)

        innerStroke.frame = background.frame

        closeButton.snp_makeConstraints { make in
            make.size.equalTo(title.snp_height)
            make.trailing.centerY.equalTo(title)
        }

        let top = (TabTrayControllerUX.TextBoxHeight - titleText.bounds.height) / 2.0
        titleText.frame.origin = CGPoint(x: titleText.frame.origin.x, y: max(0, top))
    }


    override func prepareForReuse() {
        // Reset any close animations.
        backgroundHolder.transform = CGAffineTransformIdentity
        backgroundHolder.alpha = 1
        self.titleText.font = DynamicFontHelper.defaultHelper.DefaultSmallFontBold
    }

    override func accessibilityScroll(direction: UIAccessibilityScrollDirection) -> Bool {
        var right: Bool
        switch direction {
        case .Left:
            right = false
        case .Right:
            right = true
        default:
            return false
        }
        animator.close(right: right)
        return true
    }

    @objc
    func SELclose() {
        self.animator.SELcloseWithoutGesture()
    }
}

struct PrivateModeStrings {
    static let toggleAccessibilityLabel = NSLocalizedString("Private Mode", tableName: "PrivateBrowsing", comment: "Accessibility label for toggling on/off private mode")
    static let toggleAccessibilityHint = NSLocalizedString("Turns private mode on or off", tableName: "PrivateBrowsing", comment: "Accessiblity hint for toggling on/off private mode")
    static let toggleAccessibilityValueOn = NSLocalizedString("On", tableName: "PrivateBrowsing", comment: "Toggled ON accessibility value")
    static let toggleAccessibilityValueOff = NSLocalizedString("Off", tableName: "PrivateBrowsing", comment: "Toggled OFF accessibility value")
}

protocol TabTrayDelegate: class {
    func tabTrayDidDismiss(tabTray: TabTrayController)
    func tabTrayDidAddBookmark(tab: Tab)
    func tabTrayDidAddToReadingList(tab: Tab) -> ReadingListClientRecord?
    func tabTrayRequestsPresentationOf(viewController viewController: UIViewController)
}

struct TabTrayState {
    var isPrivate: Bool = false
}


class TabSectionController: IGListSectionController, IGListSectionType {

    var manager: TabManager!
    var profile:  Profile!
    var traitCollection: UITraitCollection!
    var objects: [Tab] = []
    weak var tabSelectionDelegate: TabSelectionDelegate?
    weak var cellDelegate: TabTrayController?

    private var numberOfColumns: Int {
        let compactLayout = profile.prefs.boolForKey("CompactTabLayout") ?? true
        // iPhone 4-6+ portrait
        if traitCollection.horizontalSizeClass == .Compact && traitCollection.verticalSizeClass == .Regular {
            return compactLayout ? TabTrayControllerUX.CompactNumberOfColumnsThin : TabTrayControllerUX.NumberOfColumnsThin
        } else {
            return TabTrayControllerUX.NumberOfColumnsWide
        }
    }

    override init() {
        super.init()
        self.minimumInteritemSpacing = TabTrayControllerUX.Margin
        self.minimumLineSpacing = TabTrayControllerUX.Margin
        self.inset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.ToolbarHeight, right: 0)
    }

    func numberOfItems() -> Int {
        return objects.count
    }

    func sizeForItemAtIndex(index: Int) -> CGSize {
        let width = collectionContext?.containerSize.width ?? 0

        let cellWidth = floor((width - TabTrayControllerUX.Margin * CGFloat(numberOfColumns + 1)) / CGFloat(numberOfColumns))
        return CGSize(width: cellWidth, height: self.cellHeightForCurrentDevice())
    }

    func didUpdateToObject(object: AnyObject) {
        self.objects = (object as? [Tab])!
    }

    func cellForItemAtIndex(index: Int) -> UICollectionViewCell {
        let tabCell = collectionContext!.dequeueReusableCellOfClass(TabCell.self, forSectionController: self, atIndex: index) as! TabCell
        let tab = objects[index]

        tabCell.delegate = cellDelegate!
        tabCell.animator.delegate = cellDelegate!
        tabCell.style = tab.isPrivate ? .Dark : .Light
        tabCell.titleText.text = tab.displayTitle

        if !tab.displayTitle.isEmpty {
            tabCell.accessibilityLabel = tab.displayTitle
        } else {
            tabCell.accessibilityLabel = AboutUtils.getAboutComponent(tab.url)
        }

        tabCell.isAccessibilityElement = true
        tabCell.accessibilityHint = NSLocalizedString("Swipe right or left with three fingers to close the tab.", comment: "Accessibility hint for tab tray's displayed tab.")

        if let favIcon = tab.displayFavicon {
            tabCell.favicon.sd_setImageWithURL(NSURL(string: favIcon.url)!)
        } else {
            var defaultFavicon = UIImage(named: "defaultFavicon")
            if tab.isPrivate {
                defaultFavicon = defaultFavicon?.imageWithRenderingMode(.AlwaysTemplate)
                tabCell.favicon.image = defaultFavicon
                tabCell.favicon.tintColor = UIColor.whiteColor()
            } else {
                tabCell.favicon.image = defaultFavicon
            }
        }

        tabCell.background.image = tab.screenshot
        return tabCell
    }


    func didSelectItemAtIndex(index: Int) {
        tabSelectionDelegate?.didSelectTabAtIndex(index)
    }

    private func cellHeightForCurrentDevice() -> CGFloat {
        let compactLayout = profile.prefs.boolForKey("CompactTabLayout") ?? true
        let shortHeight = (compactLayout ? TabTrayControllerUX.TextBoxHeight * 6 : TabTrayControllerUX.TextBoxHeight * 5)

        if self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClass.Compact {
            return shortHeight
        } else if self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.Compact {
            return shortHeight
        } else {
            return TabTrayControllerUX.TextBoxHeight * 8
        }
    }

}

class TabTrayController: UIViewController, IGListAdapterDataSource {
    let tabManager: TabManager
    let profile: Profile
    weak var delegate: TabTrayDelegate?
    weak var appStateDelegate: AppStateDelegate?

    var draggedCell: TabCell?
    var dragOffset: CGPoint = CGPointZero
    lazy var toolbar: TrayToolbar = {
        let toolbar = TrayToolbar()
        toolbar.addTabButton.addTarget(self, action: #selector(TabTrayController.SELdidClickAddTab), forControlEvents: .TouchUpInside)
        toolbar.menuButton.addTarget(self, action: #selector(TabTrayController.didTapMenu), forControlEvents: .TouchUpInside)
        toolbar.maskButton.addTarget(self, action: #selector(TabTrayController.SELdidTogglePrivateMode), forControlEvents: .TouchUpInside)
        return toolbar
    }()

    lazy var adapter: IGListAdapter = {
        return IGListAdapter(updater: IGListAdapterUpdater(), viewController: self, workingRangeSize: 0)
    }()

    var collectionView: IGListCollectionView!

    var tabTrayState: TabTrayState {
        return TabTrayState(isPrivate: self.privateMode)
    }

    var leftToolbarButtons: [UIButton] {
        return [toolbar.addTabButton]
    }

    var rightToolbarButtons: [UIButton]? {
        return [toolbar.maskButton]
    }

    private(set) internal var privateMode: Bool = false {
        didSet {
            if oldValue != privateMode {
                updateAppState()
            }
            toolbar.styleToolbar(isPrivate: privateMode)
        }
    }

    private var tabsToDisplay: [Tab] {
        return self.privateMode ? tabManager.privateTabs : tabManager.normalTabs
    }

    private lazy var emptyPrivateTabsView: EmptyPrivateTabsView = {
        let emptyView = EmptyPrivateTabsView()
        emptyView.learnMoreButton.addTarget(self, action: #selector(TabTrayController.SELdidTapLearnMore), forControlEvents: UIControlEvents.TouchUpInside)
        return emptyView
    }()

    init(tabManager: TabManager, profile: Profile) {
        self.tabManager = tabManager
        self.profile = profile
        super.init(nibName: nil, bundle: nil)

        tabManager.addDelegate(self)
    }

    convenience init(tabManager: TabManager, profile: Profile, tabTrayDelegate: TabTrayDelegate) {
        self.init(tabManager: tabManager, profile: profile)
        self.delegate = tabTrayDelegate
        if let tab = tabManager.selectedTab where tab.isPrivate {
            privateMode = true
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NotificationDynamicFontChanged, object: nil)
        self.tabManager.removeDelegate(self)
    }

    func SELDynamicFontChanged(notification: NSNotification) {
        guard notification.name == NotificationDynamicFontChanged else { return }
    }


    // MARK: IG List releated


    func objectsForListAdapter(listAdapter: IGListAdapter) -> [IGListDiffable] {
        return [self.tabsToDisplay] as [IGListDiffable]
    }

    func emptyViewForListAdapter(listAdapter: IGListAdapter) -> UIView? {
        if privateMode {
            return EmptyPrivateTabsView()
        } else {
            return nil
        }
    }

    func listAdapter(listAdapter: IGListAdapter, sectionControllerForObject object: AnyObject) -> IGListSectionController {
        let sectionController = TabSectionController()
        sectionController.manager = self.tabManager
        sectionController.profile = self.profile
        sectionController.tabSelectionDelegate = self
        sectionController.cellDelegate = self
        sectionController.traitCollection = self.traitCollection
        return sectionController
    }

// MARK: View Controller Callbacks
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityLabel = NSLocalizedString("Tabs Tray", comment: "Accessibility label for the Tabs Tray view.")

        collectionView = IGListCollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.backgroundColor = TabTrayControllerUX.BackgroundColor

        view.addSubview(collectionView)
        adapter.collectionView = collectionView
        adapter.dataSource = self

        if AppConstants.MOZ_REORDER_TAB_TRAY {
            collectionView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongPressTab)))
        }

        view.addSubview(toolbar)

        makeConstraints()

        view.insertSubview(emptyPrivateTabsView, aboveSubview: collectionView)
        emptyPrivateTabsView.snp_makeConstraints { make in
            make.top.left.right.equalTo(self.collectionView)
            make.bottom.equalTo(self.toolbar.snp_top)
        }

        // register for previewing delegate to enable peek and pop if force touch feature available
        if traitCollection.forceTouchCapability == .Available {
            registerForPreviewingWithDelegate(self, sourceView: view)
        }

        emptyPrivateTabsView.hidden = !privateTabsAreEmpty()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TabTrayController.SELappWillResignActiveNotification), name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TabTrayController.SELappDidBecomeActiveNotification), name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TabTrayController.SELDynamicFontChanged(_:)), name: NotificationDynamicFontChanged, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TabTrayController.SELdidClickSettingsItem), name: NotificationStatusNotificationTapped, object: nil)
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NotificationStatusNotificationTapped, object: nil)
    }

    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    private func cancelExistingGestures() {
        if let visibleCells = self.collectionView.visibleCells() as? [TabCell] {
            for cell in visibleCells {
                cell.animator.cancelExistingGestures()
            }
        }
    }

    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)

        if AppConstants.MOZ_REORDER_TAB_TRAY {
            self.cancelExistingGestures()
        }

        coordinator.animateAlongsideTransition({ _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

    private func makeConstraints() {
        collectionView.snp_makeConstraints { make in
            make.left.bottom.right.equalTo(view)
            make.top.equalTo(snp_topLayoutGuideBottom)
        }

        toolbar.snp_makeConstraints { make in
            make.left.right.bottom.equalTo(view)
            make.height.equalTo(UIConstants.ToolbarHeight)
        }
    }

// MARK: Selectors
    func SELdidClickDone() {
        presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
    }

    func SELdidClickSettingsItem() {
        assert(NSThread.isMainThread(), "Opening settings requires being invoked on the main thread")

        let settingsTableViewController = AppSettingsTableViewController()
        settingsTableViewController.profile = profile
        settingsTableViewController.tabManager = tabManager
        settingsTableViewController.settingsDelegate = self

        let controller = SettingsNavigationController(rootViewController: settingsTableViewController)
        controller.popoverDelegate = self
		controller.modalPresentationStyle = UIModalPresentationStyle.FormSheet
        presentViewController(controller, animated: true, completion: nil)
    }

    func SELdidClickAddTab() {
        openNewTab()
    }

    func SELdidTapLearnMore() {
        let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        if let langID = NSLocale.preferredLanguages().first {
            let learnMoreRequest = NSURLRequest(URL: "https://support.mozilla.org/1/mobile/\(appVersion)/iOS/\(langID)/private-browsing-ios".asURL!)
            openNewTab(learnMoreRequest)
        }
    }

    @objc
    private func didTapMenu() {
        let state = mainStore.updateState(.TabTray(tabTrayState: self.tabTrayState))
        let mvc = MenuViewController(withAppState: state, presentationStyle: .Modal)
        mvc.delegate = self
        mvc.actionDelegate = self
        mvc.menuTransitionDelegate = MenuPresentationAnimator()
        mvc.modalPresentationStyle = .OverCurrentContext
        mvc.fixedWidth = TabTrayControllerUX.MenuFixedWidth
        if AppConstants.MOZ_REORDER_TAB_TRAY {
            self.cancelExistingGestures()
        }
        self.presentViewController(mvc, animated: true, completion: nil)
    }



    func didLongPressTab(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
            case .Began:
                let pressPosition = gesture.locationInView(self.collectionView)
                guard let indexPath = self.collectionView.indexPathForItemAtPoint(pressPosition) else {
                    break
                }
                self.collectionView.beginInteractiveMovementForItemAtIndexPath(indexPath)
                self.view.userInteractionEnabled = false
//                self.tabDataSource.isRearrangingTabs = true
//                for item in 0..<self.tabDataSource.collectionView(self.collectionView, numberOfItemsInSection: 0) {
//                    guard let cell = self.collectionView.cellForItemAtIndexPath(NSIndexPath(forItem: item, inSection: 0)) as? TabCell else {
//                        continue
//                    }
//                    if item == indexPath.item {
//                        let cellPosition = cell.contentView.convertPoint(cell.bounds.center, toView: self.collectionView)
//                        self.draggedCell = cell
//                        self.dragOffset = CGPoint(x: pressPosition.x - cellPosition.x, y: pressPosition.y - cellPosition.y)
//                        UIView.animateWithDuration(TabTrayControllerUX.RearrangeTransitionDuration, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
//                            cell.contentView.transform = CGAffineTransformMakeScale(TabTrayControllerUX.RearrangeDragScale, TabTrayControllerUX.RearrangeDragScale)
//                            cell.contentView.alpha = TabTrayControllerUX.RearrangeDragAlpha
//                        }, completion: nil)
//                        continue
//                    }
//                    cell.isBeingArranged = true
//                }
                break
            case .Changed:
                if let view = gesture.view, draggedCell = self.draggedCell {
                    var dragPosition = gesture.locationInView(view)
                    let offsetPosition = CGPoint(x: dragPosition.x + draggedCell.frame.center.x * (1 - TabTrayControllerUX.RearrangeDragScale), y: dragPosition.y + draggedCell.frame.center.y * (1 - TabTrayControllerUX.RearrangeDragScale))
                    dragPosition = CGPoint(x: offsetPosition.x - self.dragOffset.x, y: offsetPosition.y - self.dragOffset.y)
                    collectionView.updateInteractiveMovementTargetPosition(dragPosition)
                }
            case .Ended, .Cancelled:
//                for item in 0..<self.tabDataSource.collectionView(self.collectionView, numberOfItemsInSection: 0) {
//                    guard let cell = self.collectionView.cellForItemAtIndexPath(NSIndexPath(forItem: item, inSection: 0)) as? TabCell else {
//                        continue
//                    }
//                    if !cell.isBeingArranged {
//                        UIView.animateWithDuration(TabTrayControllerUX.RearrangeTransitionDuration, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
//                            cell.contentView.transform = CGAffineTransformIdentity
//                            cell.contentView.alpha = 1
//                        }, completion: nil)
//                        continue
//                    }
//                    cell.isBeingArranged = false
//                }
//                self.tabDataSource.isRearrangingTabs = false
                self.view.userInteractionEnabled = true
                gesture.state == .Ended ? self.collectionView.endInteractiveMovement() : self.collectionView.cancelInteractiveMovement()
            default:
                break
        }
    }

    func SELdidTogglePrivateMode() {
        let scaleDownTransform = CGAffineTransformMakeScale(0.9, 0.9)

        let fromView: UIView
//        if !privateTabsAreEmpty(), let snapshot = collectionView.snapshotViewAfterScreenUpdates(false) {
//            snapshot.frame = collectionView.frame
//            view.insertSubview(snapshot, aboveSubview: collectionView)
//            fromView = snapshot
//        } else {
//            fromView = emptyPrivateTabsView
//        }

        privateMode = !privateMode
        // If we are exiting private mode and we have the close private tabs option selected, make sure
        // we clear out all of the private tabs
        let exitingPrivateMode = !privateMode && profile.prefs.boolForKey("settings.closePrivateTabs") ?? false
        if exitingPrivateMode {
            tabManager.removeAllPrivateTabsAndNotify(false)
        }

        toolbar.maskButton.setSelected(privateMode, animated: true)
        adapter.performUpdatesAnimated(true, completion: nil)
//        let toView: UIView
//        if !privateTabsAreEmpty(), let newSnapshot = collectionView.snapshotViewAfterScreenUpdates(!exitingPrivateMode) {
////            emptyPrivateTabsView.hidden = true
//            //when exiting private mode don't screenshot the collectionview (causes the UI to hang)
//            newSnapshot.frame = collectionView.frame
//            view.insertSubview(newSnapshot, aboveSubview: fromView)
//            collectionView.alpha = 0
//            toView = newSnapshot
//        } else {
////            emptyPrivateTabsView.hidden = false
//            toView = emptyPrivateTabsView
//        }
//        toView.alpha = 0
//        toView.transform = scaleDownTransform

//        UIView.animateWithDuration(0.2, delay: 0, options: [], animations: { () -> Void in
//            fromView.transform = scaleDownTransform
//            fromView.alpha = 0
//            toView.transform = CGAffineTransformIdentity
//            toView.alpha = 1
//        }) { finished in
//            if fromView != self.emptyPrivateTabsView {
//                fromView.removeFromSuperview()
//            }
//            if toView != self.emptyPrivateTabsView {
//                toView.removeFromSuperview()
//            }
//            self.collectionView.alpha = 1
//        }
    }

    private func privateTabsAreEmpty() -> Bool {
        return privateMode && tabManager.privateTabs.count == 0
    }

    func changePrivacyMode(isPrivate: Bool) {
        if isPrivate != privateMode {
            guard let _ = collectionView else {
                privateMode = isPrivate
                return
            }
            SELdidTogglePrivateMode()
        }
    }

    private func openNewTab(request: NSURLRequest? = nil) {
        toolbar.userInteractionEnabled = false
        let tab = self.tabManager.addTab(request, isPrivate: self.privateMode)
        self.tabManager.selectTab(tab)
        self.navigationController?.popViewControllerAnimated(true)
    }

    private func updateAppState() {
        let state = mainStore.updateState(.TabTray(tabTrayState: self.tabTrayState))
        self.appStateDelegate?.appDidUpdateState(state)
    }

    private func closeTabsForCurrentTray() {
        tabManager.removeTabsWithUndoToast(tabsToDisplay)
    }
}

// MARK: - App Notifications
extension TabTrayController {
    func SELappWillResignActiveNotification() {
        if privateMode {
            collectionView.alpha = 0
        }
    }

    func SELappDidBecomeActiveNotification() {
        // Re-show any components that might have been hidden because they were being displayed
        // as part of a private mode tab
        UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
            self.collectionView.alpha = 1
        },
        completion: nil)
    }
}

extension TabTrayController: TabSelectionDelegate {
    func didSelectTabAtIndex(index: Int) {
        let tab = tabsToDisplay[index]
        tabManager.selectTab(tab)
        self.navigationController?.popViewControllerAnimated(true)
    }
}

extension TabTrayController: PresentingModalViewControllerDelegate {
    func dismissPresentedModalViewController(modalViewController: UIViewController, animated: Bool) {
        dismissViewControllerAnimated(animated, completion: { })
    }
}

extension TabTrayController: TabManagerDelegate {
    func tabManager(tabManager: TabManager, didSelectedTabChange selected: Tab?, previous: Tab?) {
    }

    func tabManager(tabManager: TabManager, didCreateTab tab: Tab) {
    }

    func tabManager(tabManager: TabManager, didAddTab tab: Tab) {
    }

    func tabManager(tabManager: TabManager, didRemoveTab tab: Tab) {
        adapter.performUpdatesAnimated(true, completion: nil)
    }

    func tabManagerDidAddTabs(tabManager: TabManager) {
    }

    func tabManagerDidRestoreTabs(tabManager: TabManager) {
    }
    
    func tabManagerDidRemoveAllTabs(tabManager: TabManager, toast: ButtonToast?) {
        guard privateMode else {
            return
        }
        if let undoToast = toast {
            view.addSubview(undoToast)
            undoToast.snp_makeConstraints { make in
                make.left.right.equalTo(view)
                make.bottom.equalTo(toolbar.snp_top)
            }
            undoToast.showToast()
        }
    }
}

extension TabTrayController: UIScrollViewAccessibilityDelegate {
    func accessibilityScrollStatusForScrollView(scrollView: UIScrollView) -> String? {
        var visibleCells = collectionView.visibleCells() as! [TabCell]
        var bounds = collectionView.bounds
        bounds = CGRectOffset(bounds, collectionView.contentInset.left, collectionView.contentInset.top)
        bounds.size.width -= collectionView.contentInset.left + collectionView.contentInset.right
        bounds.size.height -= collectionView.contentInset.top + collectionView.contentInset.bottom
        // visible cells do sometimes return also not visible cells when attempting to go past the last cell with VoiceOver right-flick gesture; so make sure we have only visible cells (yeah...)
        visibleCells = visibleCells.filter { !CGRectIsEmpty(CGRectIntersection($0.frame, bounds)) }

        let cells = visibleCells.map { self.collectionView.indexPathForCell($0)! }
        let indexPaths = cells.sort { (a: NSIndexPath, b: NSIndexPath) -> Bool in
            return a.section < b.section || (a.section == b.section && a.row < b.row)
        }

        if indexPaths.count == 0 {
            return NSLocalizedString("No tabs", comment: "Message spoken by VoiceOver to indicate that there are no tabs in the Tabs Tray")
        }

        let firstTab = indexPaths.first!.row + 1
        let lastTab = indexPaths.last!.row + 1
        let tabCount = collectionView.numberOfItemsInSection(0)

        if (firstTab == lastTab) {
            let format = NSLocalizedString("Tab %@ of %@", comment: "Message spoken by VoiceOver saying the position of the single currently visible tab in Tabs Tray, along with the total number of tabs. E.g. \"Tab 2 of 5\" says that tab 2 is visible (and is the only visible tab), out of 5 tabs total.")
            return String(format: format, NSNumber(integer: firstTab), NSNumber(integer: tabCount))
        } else {
            let format = NSLocalizedString("Tabs %@ to %@ of %@", comment: "Message spoken by VoiceOver saying the range of tabs that are currently visible in Tabs Tray, along with the total number of tabs. E.g. \"Tabs 8 to 10 of 15\" says tabs 8, 9 and 10 are visible, out of 15 tabs total.")
            return String(format: format, NSNumber(integer: firstTab), NSNumber(integer: lastTab), NSNumber(integer: tabCount))
        }
    }
}

extension TabTrayController: SwipeAnimatorDelegate {
    func swipeAnimator(animator: SwipeAnimator, viewWillExitContainerBounds: UIView) {
        let tabCell = animator.container as! TabCell
        if let indexPath = collectionView.indexPathForCell(tabCell) {
            let tab = tabsToDisplay[indexPath.item]
            tabManager.removeTab(tab)
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, NSLocalizedString("Closing tab", comment: "Accessibility label (used by assistive technology) notifying the user that the tab is being closed."))
        }
    }
}

extension TabTrayController: TabCellDelegate {
    func tabCellDidClose(cell: TabCell) {
        let indexPath = collectionView.indexPathForCell(cell)!
        let tab = tabsToDisplay[indexPath.item]
        tabManager.removeTab(tab)
    }
}

extension TabTrayController: SettingsDelegate {
    func settingsOpenURLInNewTab(url: NSURL) {
        let request = NSURLRequest(URL: url)
        openNewTab(request)
    }
}

@objc protocol TabSelectionDelegate: class {
    func didSelectTabAtIndex(index: Int)
}


extension TabTrayController: TabPeekDelegate {

    func tabPeekDidAddBookmark(tab: Tab) {
        delegate?.tabTrayDidAddBookmark(tab)
    }

    func tabPeekDidAddToReadingList(tab: Tab) -> ReadingListClientRecord? {
        return delegate?.tabTrayDidAddToReadingList(tab)
    }

    func tabPeekDidCloseTab(tab: Tab) {
        if let index = self.tabsToDisplay.indexOf(tab),
            let cell = self.collectionView?.cellForItemAtIndexPath(NSIndexPath(forItem: index, inSection: 0)) as? TabCell {
            cell.SELclose()
        }
    }

    func tabPeekRequestsPresentationOf(viewController viewController: UIViewController) {
        delegate?.tabTrayRequestsPresentationOf(viewController: viewController)
    }
}

extension TabTrayController: UIViewControllerPreviewingDelegate {

    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let collectionView = collectionView else { return nil }
        let convertedLocation = self.view.convertPoint(location, toView: collectionView)

        guard let indexPath = collectionView.indexPathForItemAtPoint(convertedLocation),
            let cell = collectionView.cellForItemAtIndexPath(indexPath) else {
                return nil
        }

        let tab = self.tabsToDisplay[indexPath.row]
        let tabVC = TabPeekViewController(tab: tab, delegate: self)
        if let browserProfile = profile as? BrowserProfile {
            tabVC.setState(withProfile: browserProfile, clientPickerDelegate: self)
        }
        previewingContext.sourceRect = self.view.convertRect(cell.frame, fromView: collectionView)
        return nil
    }

    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController) {
        guard let tpvc = viewControllerToCommit as? TabPeekViewController else { return }
        tabManager.selectTab(tpvc.tab)
        self.navigationController?.popViewControllerAnimated(true)
        delegate?.tabTrayDidDismiss(self)
    }
}

extension TabTrayController: ClientPickerViewControllerDelegate {

    func clientPickerViewController(clientPickerViewController: ClientPickerViewController, didPickClients clients: [RemoteClient]) {
        if let item = clientPickerViewController.shareItem {
            self.profile.sendItems([item], toClients: clients)
        }
        clientPickerViewController.dismissViewControllerAnimated(true, completion: nil)
    }

    func clientPickerViewControllerDidCancel(clientPickerViewController: ClientPickerViewController) {
        clientPickerViewController.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension TabTrayController: UIAdaptivePresentationControllerDelegate, UIPopoverPresentationControllerDelegate {
    // Returning None here makes sure that the Popover is actually presented as a Popover and
    // not as a full-screen modal, which is the default on compact device classes.
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.None
    }
}

extension TabTrayController: MenuViewControllerDelegate {
    func menuViewControllerDidDismiss(menuViewController: MenuViewController) { }

    func shouldCloseMenu(menuViewController: MenuViewController, forRotationToNewSize size: CGSize, forTraitCollection traitCollection: UITraitCollection) -> Bool {
        return false
    }
}

extension TabTrayController: MenuActionDelegate {
    func performMenuAction(action: MenuAction, withAppState appState: AppState) {
        if let menuAction = AppMenuAction(rawValue: action.action) {
            switch menuAction {
            case .OpenNewNormalTab:
                dispatch_async(dispatch_get_main_queue()) {
                    if self.privateMode {
                        self.SELdidTogglePrivateMode()
                    }
                    self.openNewTab()
                }
            case .OpenNewPrivateTab:
                dispatch_async(dispatch_get_main_queue()) {
                    if !self.privateMode {
                        self.SELdidTogglePrivateMode()
                    }
                    self.openNewTab()
                }
            case .OpenSettings:
                dispatch_async(dispatch_get_main_queue()) {
                    self.SELdidClickSettingsItem()
                }
            case .CloseAllTabs:
                dispatch_async(dispatch_get_main_queue()) {
                    self.closeTabsForCurrentTray()
                }
            case .OpenTopSites:
                dispatch_async(dispatch_get_main_queue()) {
                    //testing will remove
                    for var i = 0; i<100; i++ {
                        self.openNewTab(PrivilegedRequest(URL: HomePanelType.TopSites.localhostURL))
                    }
                }
            case .OpenBookmarks:
                dispatch_async(dispatch_get_main_queue()) {
                    self.openNewTab(PrivilegedRequest(URL: HomePanelType.Bookmarks.localhostURL))
                }
            case .OpenHistory:
                dispatch_async(dispatch_get_main_queue()) {
                    self.openNewTab(PrivilegedRequest(URL: HomePanelType.History.localhostURL))
                }
            case .OpenReadingList:
                dispatch_async(dispatch_get_main_queue()) {
                    self.openNewTab(PrivilegedRequest(URL: HomePanelType.ReadingList.localhostURL))
                }
            default: break
            }
        }
    }
}

// MARK: - Empty view for Private Tabs
struct EmptyPrivateTabsViewUX {
    static let TitleColor = UIColor.whiteColor()
    static let TitleFont = UIFont.systemFontOfSize(22, weight: UIFontWeightMedium)
    static let DescriptionColor = UIColor.whiteColor()
    static let DescriptionFont = UIFont.systemFontOfSize(17)
    static let LearnMoreFont = UIFont.systemFontOfSize(15, weight: UIFontWeightMedium)
    static let TextMargin: CGFloat = 18
    static let LearnMoreMargin: CGFloat = 30
    static let MaxDescriptionWidth: CGFloat = 250
    static let MinBottomMargin: CGFloat = 10
}

private class EmptyPrivateTabsView: UIView {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = EmptyPrivateTabsViewUX.TitleColor
        label.font = EmptyPrivateTabsViewUX.TitleFont
        label.textAlignment = NSTextAlignment.Center
        return label
    }()

    private var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = EmptyPrivateTabsViewUX.DescriptionColor
        label.font = EmptyPrivateTabsViewUX.DescriptionFont
        label.textAlignment = NSTextAlignment.Center
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = EmptyPrivateTabsViewUX.MaxDescriptionWidth
        return label
    }()

    private var learnMoreButton: UIButton = {
        let button = UIButton(type: .System)
        button.setTitle(
            NSLocalizedString("Learn More", tableName: "PrivateBrowsing", comment: "Text button displayed when there are no tabs open while in private mode"),
            forState: .Normal)
        button.setTitleColor(UIConstants.PrivateModeTextHighlightColor, forState: .Normal)
        button.titleLabel?.font = EmptyPrivateTabsViewUX.LearnMoreFont
        return button
    }()

    private var iconImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "largePrivateMask"))
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.text =  NSLocalizedString("Private Browsing",
                                             tableName: "PrivateBrowsing", comment: "Title displayed for when there are no open tabs while in private mode")
        descriptionLabel.text = NSLocalizedString("Firefox won't remember any of your history or cookies, but new bookmarks will be saved.",
                                                  tableName: "PrivateBrowsing", comment: "Description text displayed when there are no open tabs while in private mode")

        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(iconImageView)
        addSubview(learnMoreButton)

        titleLabel.snp_makeConstraints { make in
            make.center.equalTo(self)
        }

        iconImageView.snp_makeConstraints { make in
            make.bottom.equalTo(titleLabel.snp_top).offset(-EmptyPrivateTabsViewUX.TextMargin)
            make.centerX.equalTo(self)
        }

        descriptionLabel.snp_makeConstraints { make in
            make.top.equalTo(titleLabel.snp_bottom).offset(EmptyPrivateTabsViewUX.TextMargin)
            make.centerX.equalTo(self)
        }

        learnMoreButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(descriptionLabel.snp_bottom).offset(EmptyPrivateTabsViewUX.LearnMoreMargin).priorityLow()
            make.bottom.lessThanOrEqualTo(self).offset(-EmptyPrivateTabsViewUX.MinBottomMargin).priorityHigh()
            make.centerX.equalTo(self)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


// MARK: - Toolbar
class TrayToolbar: UIView {
    private let toolbarButtonSize = CGSize(width: 44, height: 44)
    private let sideOffset: CGFloat = 32

    lazy var settingsButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.templateImageNamed("settings"), forState: .Normal)
        button.accessibilityLabel = NSLocalizedString("Settings", comment: "Accessibility label for the Settings button in the Tab Tray.")
        button.accessibilityIdentifier = "TabTrayController.settingsButton"
        return button
    }()

    lazy var addTabButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.templateImageNamed("add"), forState: .Normal)
        button.accessibilityLabel = NSLocalizedString("Add Tab", comment: "Accessibility label for the Add Tab button in the Tab Tray.")
        button.accessibilityIdentifier = "TabTrayController.addTabButton"
        return button
    }()

    lazy var menuButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.templateImageNamed("bottomNav-menu-pbm"), forState: .Normal)
        button.accessibilityLabel = AppMenuConfiguration.MenuButtonAccessibilityLabel
        button.accessibilityIdentifier = "TabTrayController.menuButton"
        return button
    }()

    lazy var maskButton: PrivateModeButton = PrivateModeButton()

    private override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .whiteColor()
        addSubview(addTabButton)

        var buttonToCenter: UIButton?
        addSubview(menuButton)
        buttonToCenter = menuButton

        buttonToCenter?.snp_makeConstraints { make in
            make.center.equalTo(self)
            make.size.equalTo(toolbarButtonSize)
        }

        addTabButton.snp_makeConstraints { make in
            make.centerY.equalTo(self)
            make.left.equalTo(self).offset(sideOffset)
            make.size.equalTo(toolbarButtonSize)
        }

        addSubview(maskButton)
        maskButton.snp_makeConstraints { make in
            make.centerY.equalTo(self)
            make.right.equalTo(self).offset(-sideOffset)
            make.size.equalTo(toolbarButtonSize)
        }

        styleToolbar(isPrivate: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func styleToolbar(isPrivate isPrivate: Bool) {
        addTabButton.tintColor = isPrivate ? .whiteColor() : .darkGrayColor()
        menuButton.tintColor = isPrivate ? .whiteColor() : .darkGrayColor()
        backgroundColor = isPrivate ? UIConstants.PrivateModeToolbarTintColor : .whiteColor()
        maskButton.styleForMode(privateMode: isPrivate)
    }
}
