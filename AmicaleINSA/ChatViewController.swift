//
//  ChatViewController.swift
//  AmicaleINSA
//
//  Created by Arthur Papailhau on 28/02/16.
//  Copyright © 2016 Arthur Papailhau. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import SVPullToRefresh
import MobileCoreServices
import MediaPlayer
import NYTPhotoViewer
import ALCameraViewController
import ImagePicker
import SWRevealViewController
import MBProgressHUD



class ChatViewController: JSQMessagesViewController, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MenuControllerDelegate, ImagePickerDelegate,JSQMessagesViewControllerScrollingDelegate {
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    // var myActivityIndicator: UIActivityIndicatorView!
    var myActivityIndicatorHUD = MBProgressHUD()
    
    var messages = [JSQMessage]()
    var messagesHashValue = [String]()
    
    var delegate : ChatViewController?
    
    static let chatViewController : ChatViewController = {
        return ChatViewController()
    }()
    
    let LOG = false
    let shouldDisplayAvatar = true
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    
    var outgoingBubbleImageView: JSQMessagesBubbleImage!
    var incomingBubbleImageView: JSQMessagesBubbleImage!
    
    var messageRef: FIRDatabaseReference!
    var firebaseRef = FIRDatabase.database().reference()
    
    var lastTimestamp: NSTimeInterval!
    let LOAD_MORE_MESSAGE_LIMIT  = UInt(60)
    let INITIAL_MESSAGE_LIMIT = UInt(60)
    var userIsTypingRef: FIRDatabaseReference!
    private var localTyping = false
    
    let timeIntervalBetweenMessages = 20*60
    
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    var timer = NSTimer()
    
    let imagePicker = UIImagePickerController()
    var usersTypingQuery: FIRDatabaseQuery!
    
    private func observeTyping() {
        let typingIndicatorRef = FirebaseManager.firebaseManager.createTypingIndicatorRef()
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        usersTypingQuery = typingIndicatorRef.queryOrderedByValue().queryEqualToValue(true)
        usersTypingQuery.observeEventType(.Value) { (data: FIRDataSnapshot!) in
            _log_Title("User Typing", location: "ChatVC.observeTyping()", shouldLog: false)
            _log_Element("Number Users Typing: \(data.childrenCount)", shouldLog: false)
            _log_FullLineStars(false)
            if data.childrenCount == 1 && self.isTyping {
                return
            }
            self.showTypingIndicator = data.childrenCount > 0
            if self.showTypingIndicator && self.isLastCellVisible {
                //print("Je scroll tout bottom car last cell visible and showTypingIndicator")
                self.scrollToBottomAnimated(true)
            }
        }
    }
    
    func initActivityIndicatorMessages() {
        let myActivityIndicatorHUD = MBProgressHUD.showHUDAddedTo(self.navigationController?.view, animated: true)
        myActivityIndicatorHUD.mode = MBProgressHUDMode.Indeterminate
        myActivityIndicatorHUD.labelText = "Loading messages..."
        myActivityIndicatorHUD.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ChatViewController.tapToCancel)))
    }
    
    func initActivityIndicatorPictures() {
        let myActivityIndicatorHUD = MBProgressHUD.showHUDAddedTo(self.navigationController?.view, animated: true)
        myActivityIndicatorHUD.mode = MBProgressHUDMode.Indeterminate
        myActivityIndicatorHUD.labelText = "Loading pictures..."
        myActivityIndicatorHUD.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ChatViewController.tapToCancel)))
    }
    
    func tapToCancel(){
        print("cancel tap")
        MBProgressHUD.hideAllHUDsForView(self.navigationController?.view, animated: true)
    }
    
    func initObservers() {
        observeMessages()
        observeTyping()
        observeActiveUsers()
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if self.revealViewController() != nil {
            menuButton.target = self.revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        initChat()
        initActivityIndicatorMessages()
        collectionView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRectMake(0, 0, 24, 24))
        /*[JSQMessage, scroll to bottom]*/
        self.scrollingDelegate = self
        
        title = "Chat"
        setupBubbles()
        
        if shouldDisplayAvatar {
            // collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
            collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
        } else {
            collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
            collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
        }
        
        messageRef = FirebaseManager.firebaseManager.createMessageRef()
        
        automaticallyAdjustsScrollViewInsets = true
        
        collectionView!.addInfiniteScrollingWithActionHandler( { () -> Void in
            self.loadMoreMessages()
            }, direction: UInt(SVInfiniteScrollingDirectionTop) )
        
        self.inputToolbar?.contentView?.leftBarButtonItem?.setImage(UIImage(named: "Camera"), forState: .Normal)
        self.inputToolbar?.contentView?.leftBarButtonItem?.setImage(UIImage(named: "Camera"), forState: .Highlighted)
        self.inputToolbar?.contentView?.leftBarButtonItem?.imageView?.contentMode = UIViewContentMode.ScaleAspectFit
        
        self.inputToolbar?.contentView?.leftBarButtonItemWidth = 30
        
        // test pour voir si ça résout le bug d'appeler plusieurs fois observeMessages() quand j'envoie une image
        initObservers()
    }
    
    
    func initChat(){}
    
    
    private func observeActiveUsers() {
        let activeUsersRef = FirebaseManager.firebaseManager.createActiveUsersRef()
        let singleUserRef = activeUsersRef.child(self.senderId)
        var value = "\(self.senderDisplayName)"
        singleUserRef.onDisconnectRemoveValue()
        activeUsersRef.observeEventType(.Value, withBlock: { (snapshot: FIRDataSnapshot!) in
            value = getUsernameChat()
            singleUserRef.setValue(value)
            var count = 0
            if snapshot.exists() {
                count = Int(snapshot.childrenCount)
                var titleChat = "Chat (\(count)) "
                if count == 1 {
                    titleChat += "👶"
                } else if  count == 2 {
                    titleChat += "👦"
                } else if  count == 3 {
                    titleChat += "👧"
                } else if  count == 4 {
                    titleChat += "🤗"
                } else if  count == 5 {
                    titleChat += "🚶"
                } else if  count == 6 {
                    titleChat += "🍻"
                } else if count <= 7 {
                    titleChat += "😎"
                } else if count <= 10 {
                    titleChat += "🤓"
                } else if count <= 15 {
                    titleChat += "😱"
                } else if count <= 20 {
                    titleChat += "😍"
                } else if count <= 25 {
                    titleChat += "🍷"
                } else if count <= 30 {
                    titleChat += "🐤"
                } else if count <= 35 {
                    titleChat += "🐙"
                } else if count <= 40 {
                    titleChat += "🐸"
                } else if count <= 45 {
                    titleChat += "🐔"
                } else if count <= 50 {
                    titleChat += "🐌"
                } else if count <= 60 {
                    titleChat += "🐨"
                } else if count <= 70 {
                    titleChat += "🐢"
                } else if count <= 80 {
                    titleChat += "🐳"
                } else if count <= 90 {
                    titleChat += "🐲"
                } else if count <= 100 {
                    titleChat += "💥"
                } else if count <= 110 {
                    titleChat += "🌨"
                } else if count <= 120 {
                    titleChat += "🌩"
                } else if count <= 130 {
                    titleChat += "⛈"
                } else if count <= 140 {
                    titleChat += "🌧"
                } else if count <= 150 {
                    titleChat += "🌦"
                } else if count <= 160 {
                    titleChat += "🌬"
                } else if count <= 170 {
                    titleChat += "☁️"
                } else if count <= 180 {
                    titleChat += "⛅️"
                } else if count <= 190 {
                    titleChat += "🌤"
                } else if count <= 195 {
                    titleChat += "☀️"
                } else if count <= 200 {
                    titleChat += "🔥"
                } else {
                    titleChat += "👁"
                }
                self.title = titleChat
            }
        })
    }
    
    func dismissKeyboard(){
        inputToolbar?.contentView?.textView?.resignFirstResponder()
    }
    
    
    func dismissKeyboardFromMenu(ViewController:MenuController) {
        inputToolbar?.contentView?.textView?.resignFirstResponder()
    }
    
    
    func shouldAddInArray(hashValue: String) -> Bool {
        return !messagesHashValue.contains(hashValue)
    }
    
    
    func messageAlreadyPresent(id: String, senderDisplayName: String, text: String, date: NSDate) -> Bool {
        let msg = "\(id)\(senderDisplayName)\(text)\(date)"
        var msgToCompare = ""
        for message in messages {
            if message.isMediaMessage == false {
                msgToCompare = "\(message.senderId)\(message.senderDisplayName)\(message.text)\(message.date)"
                if msgToCompare == msg {
                    return true
                }
            }
        }
        return false
    }
    
    private func observeMessages() {
        _log_Title("Count Messages", location: "ChatVC.observeMessages", shouldLog: LOG)
        var SwiftSpinnerAlreadyHidden = false
        var index = 0;
        let messagesQuery = messageRef.queryLimitedToLast(INITIAL_MESSAGE_LIMIT)
        messagesQuery.observeEventType(.ChildAdded) { (snapshot: FIRDataSnapshot!) in
            if !SwiftSpinnerAlreadyHidden {
                SwiftSpinnerAlreadyHidden = true
                MBProgressHUD.hideAllHUDsForView(self.navigationController?.view, animated: true)
                self.initActivityIndicatorPictures()
            }
    
            guard let idString = snapshot.value!["senderId"] as? String else {return}
            guard let textString = snapshot.value!["text"] as? String else {return}
            guard let senderDisplayNameString = snapshot.value!["senderDisplayName"] as? String else {return}
            guard let dateTimestampInterval = snapshot.value!["dateTimestamp"] as? NSTimeInterval else {return}
            
            var imageURLString = ""
            if let imageURL = snapshot.value!["imageURL"] as? String {
                imageURLString = imageURL
            }
            
            if (self.shouldUpdateLastTimestamp(dateTimestampInterval)){
                self.lastTimestamp = dateTimestampInterval
            }
            
            let date = NSDate(timeIntervalSince1970: dateTimestampInterval)
            let hashValue = "\(idString)\(date)\(senderDisplayNameString)\(dateTimestampInterval)".md5()
            let canAdd = self.shouldAddInArray(hashValue)
            if canAdd {
                if imageURLString != "" {
                    let httpsReferenceImage = FIRStorage.storage().referenceForURL(imageURLString)
                    httpsReferenceImage.dataWithMaxSize(3 * 1024 * 1024) { (data, error) -> Void in
                        if (error != nil) {
                            print("Error downloading image from httpsReferenceImage firebase")
                        } else {
                            //print("I download image from firebase reference")
                            let image = UIImage(data: data!)?.resizedImageClosestTo1000
                            let mediaMessageData: JSQPhotoMediaItem = JSQPhotoMediaItem(image: image)
                            self.addMessage(idString, media: mediaMessageData, senderDisplayName: senderDisplayNameString, date: date, isLoadMoreLoading: false)
                            index = self.finishReceivingAsyncMessage(index, isInitialLoading: true, isLoadMoreLoading: false)
                            _log_Element("Should have \(self.INITIAL_MESSAGE_LIMIT) messages, have: \(index)", shouldLog: self.LOG)
                        }
                    }
                } else {
                    self.addMessage(idString, text: textString, senderDisplayName: senderDisplayNameString, date: date, isLoadMoreLoading: false)
                    index = self.finishReceivingAsyncMessage(index, isInitialLoading: true, isLoadMoreLoading: false)
                }
                self.messagesHashValue += [hashValue]
            } else {
                print("I cannot add the message, PROBLEM!")
                print("Timestamp qui cause problème est: \(dateTimestampInterval), data: \(date)")
            }
        }
    }

    
    func finishReceivingAsyncMessage(index: Int, isInitialLoading: Bool, isLoadMoreLoading: Bool) -> Int {
        self.finishReceivingMessage()
        if UInt(index+1) == self.INITIAL_MESSAGE_LIMIT && isInitialLoading {
            self.scrollToBottomAnimated(true)
            MBProgressHUD.hideAllHUDsForView(self.navigationController?.view, animated: true)
        } else if UInt(index+1) == LOAD_MORE_MESSAGE_LIMIT && isLoadMoreLoading {
            self.collectionView!.infiniteScrollingView.stopAnimating()
        }
        return index+1
    }
    
    func shouldUpdateLastTimestamp(timestamp: NSTimeInterval) -> Bool {
        return (lastTimestamp == nil) || timestamp < lastTimestamp
    }
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!,
                                     senderDisplayName: String!, date: NSDate!) {
        FirebaseManager.firebaseManager.sendMessageFirebase2(text, senderId: senderId, senderDisplayName: senderDisplayName, date: date, isMedia: false, imageURL: "")
        finishSendingMessage()
        isTyping = false
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func textViewDidChange(textView: UITextView) {
        super.textViewDidChange(textView)
        isTyping = textView.text != ""
    }
    
    func shouldDisplayDate (index: Int) -> Bool{
        
        let message = messages[index]
        
        if index > 0 {
            if let _ = message.date {
                let previousMessage = messages[index-1]
                if let _ = previousMessage.date {
                    let timeInterval = Int(message.date.timeIntervalSinceDate(previousMessage.date))
                    let shouldDisplay: Bool = timeInterval >= timeIntervalBetweenMessages
                    return shouldDisplay
                }
            }
        }
        return false
    }
    
    
    func loadMoreMessages(){
        let oldBottomOffset = self.collectionView!.contentSize.height - self.collectionView!.contentOffset.y
        let messagesQuery = messageRef.queryOrderedByChild("dateTimestamp").queryEndingAtValue(lastTimestamp).queryLimitedToLast(LOAD_MORE_MESSAGE_LIMIT)
        var index = 0
        messagesQuery.observeEventType(.ChildAdded) { (snapshot: FIRDataSnapshot!) in
            
            guard let id = snapshot.value!["senderId"] as? String else {return}
            guard let text = snapshot.value!["text"] as? String else {return}
            guard let senderDisplayName = snapshot.value!["senderDisplayName"] as? String else {return}
            guard let dateTimestampInterval = snapshot.value!["dateTimestamp"] as? NSTimeInterval else {return}
            var imageURLString = ""
            if let imageURL = snapshot.value!["imageURL"] as? String {
                imageURLString = imageURL
            }
            
            if (self.shouldUpdateLastTimestamp(dateTimestampInterval)){
                self.lastTimestamp = dateTimestampInterval
            }
            
            let date = NSDate(timeIntervalSince1970: dateTimestampInterval)
            
            if index < Int(self.LOAD_MORE_MESSAGE_LIMIT) {
                if imageURLString != "" {
                    let httpsReferenceImage = FIRStorage.storage().referenceForURL(imageURLString)
                    httpsReferenceImage.dataWithMaxSize(3 * 1024 * 1024) { (data, error) -> Void in
                        if (error != nil) {
                            print("Error downloading image from httpsReferenceImage firebase")
                        } else {
                            let image = UIImage(data: data!)?.resizedImageClosestTo1000
                            let mediaMessageData: JSQPhotoMediaItem = JSQPhotoMediaItem(image: image)
                            self.addMessage(id, media: mediaMessageData, senderDisplayName: senderDisplayName, date: date, isLoadMoreLoading: true)
                            index = self.finishReceivingAsyncMessage(index, isInitialLoading: false, isLoadMoreLoading: true)
                            print("index: \(index), load_more_message_limit: \(Int(self.LOAD_MORE_MESSAGE_LIMIT))")
                        }
                    }
                }
                else {
                    index += 1
                    self.addMessage(id, text: text, senderDisplayName: senderDisplayName, date: date, isLoadMoreLoading: true)
                }
            } else {
                print("I stop animating the loading indicator")
                self.collectionView!.infiniteScrollingView.stopAnimating()
            }
            self.finishReceivingMessageAnimated(false)
            self.collectionView!.layoutIfNeeded()
            self.collectionView!.contentOffset = CGPointMake(0, self.collectionView!.contentSize.height - oldBottomOffset)
        }
        self.resetTimer()
    }
    
    func resetTimer() {
        timer.invalidate()
        let nextTimer = NSTimer.scheduledTimerWithTimeInterval(4.0, target: self, selector: #selector(ChatViewController.handleIdleEvent(_:)), userInfo: nil, repeats: false)
        print("TIMERRRR 1")
        timer = nextTimer
    }
    
    func handleIdleEvent(timer: NSTimer) {
        print("TIMERRRR 2")
        self.collectionView!.infiniteScrollingView.stopAnimating()
    }
    
    func customSortJSQMessage(msg1: JSQMessage, msg2 : JSQMessage) -> Bool {
        return (msg1.date.compare(msg2.date) == NSComparisonResult.OrderedAscending)
    }
    
    func addMessageAtFirstPosition(id: String, text: String, senderDisplayName: String, date: NSDate) {
        let msg = JSQMessage(senderId: id, senderDisplayName: senderDisplayName, date: date, text: text)
        messages.append(msg)
        messages.sortInPlace({
            return ($0.date.compare($1.date) == NSComparisonResult.OrderedAscending)
        })
    }
    
    func addMessage(id: String, text: String, senderDisplayName: String, date: NSDate, isLoadMoreLoading: Bool) {
        if messageAlreadyPresent(id, senderDisplayName:senderDisplayName, text: text, date: date) == false {
            let msg = JSQMessage(senderId: id, senderDisplayName: senderDisplayName, date: date, text: text)
            if isLoadMoreLoading {
                messages.insert(msg, atIndex: 0)
            } else {
                messages.append(msg)
            }
            messages.sortInPlace({
                return ($0.date.compare($1.date) == NSComparisonResult.OrderedAscending)
            })
        }
    }
    
    func addMessage(id: String, media: JSQPhotoMediaItem, senderDisplayName: String, date: NSDate, isLoadMoreLoading: Bool) {
        if messageAlreadyPresent(id, senderDisplayName: senderDisplayName, media: media, date: date) == false {
            let msg = JSQMessage(senderId: id, senderDisplayName: senderDisplayName, date: date, media: media)
            if isLoadMoreLoading {
                messages.insert(msg, atIndex: 0)
            } else {
                messages.append(msg)
            }
            messages.sortInPlace({
                return ($0.date.compare($1.date) == NSComparisonResult.OrderedAscending)
            })
        }
    }
    
    func messageAlreadyPresent(id: String, senderDisplayName: String, media: JSQPhotoMediaItem, date: NSDate) -> Bool {
        let msg = "\(id)\(senderDisplayName)\(date)"
        var msgToCompare = ""
        for message in messages {
            if message.isMediaMessage == true {
                msgToCompare = "\(message.senderId)\(message.senderDisplayName)\(message.date)"
                if msgToCompare == msg {
                    return true
                }
            }
        }
        return false
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, header headerView: JSQMessagesLoadEarlierHeaderView!, didTapLoadEarlierMessagesButton sender: UIButton!) {
        print("didTapLoadEarlierMessagesButton")
        headerView.loadButton?.hidden = false
        loadMoreMessages()
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat
    {
        if indexPath.item == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        if shouldDisplayDate(indexPath.item) {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        return 0.0
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return 0
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    
    override func collectionView(collectionView: UICollectionView,
                                 cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
            as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        if message.isMediaMessage == false {
            if message.senderId == senderId {
                cell.textView!.textColor = UIColor.whiteColor()
            } else {
                cell.textView!.linkTextAttributes = [NSForegroundColorAttributeName:UIColor.blueColor(), NSUnderlineColorAttributeName: UIColor.blueColor(), NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue]
                cell.textView!.textColor = UIColor.blackColor()
            }
        }
        return cell
    }
    
    /* 
     Display an Avatar 
    */
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        if shouldDisplayAvatar {
            let currentMessage = messages[indexPath.item]
            //let initial = String(currentMessage.senderDisplayName.characters.first!)
            let senderDisplayNameCurrentMessage = currentMessage.senderDisplayName
            var initial = String(senderDisplayNameCurrentMessage[senderDisplayNameCurrentMessage.startIndex])
            if senderDisplayNameCurrentMessage.characters.count >= 2 {
                initial = senderDisplayNameCurrentMessage[senderDisplayNameCurrentMessage.startIndex...senderDisplayNameCurrentMessage.startIndex.advancedBy(1)]
            }
            // si c'est le dernier de la liste, j'affiche l'avatar
            if indexPath.item == messages.count-1 {
                return JSQMessagesAvatarImageFactory.avatarImageWithUserInitials(initial, backgroundColor: UIColor.jsq_messageBubbleLightGrayColor(), textColor: UIColor(white: 0.60, alpha: 1.0), font: UIFont.systemFontOfSize(14), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
            }
            let nextMessage = messages[indexPath.item+1]
            if currentMessage.senderId == nextMessage.senderId && currentMessage.senderDisplayName == nextMessage.senderDisplayName {
                return JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("", backgroundColor: UIColor.whiteColor(), textColor: UIColor.whiteColor(), font: UIFont.systemFontOfSize(14), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
            } else {
                return JSQMessagesAvatarImageFactory.avatarImageWithUserInitials(initial, backgroundColor: UIColor.jsq_messageBubbleLightGrayColor(), textColor: UIColor(white: 0.60, alpha: 1.0), font: UIFont.systemFontOfSize(14), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
            }
        } else {
            return nil
        }
        // return JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("AP", backgroundColor: UIColor.jsq_messageBubbleLightGrayColor(), textColor: UIColor(white: 0.60, alpha: 1.0), font: UIFont.systemFontOfSize(14), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
    }
    
    func getInitials(name: String) -> String {
        return name.characters.split { token in
            return token == " "
            }
            .map { String($0) }
            .map { word in
                return word[word.startIndex]
            }
            .reduce("") { accIn, firstCharacter in
                return "\(accIn)\(firstCharacter)"
        }
    }
    
    /*
     Si le message que j'ai envoyé est signé d'un senderDisplayName différent, alors que renvoit true, sinon je renvoie false
     True: senderDisplayName différent du current, donc je dois mettre un espace et afficher le nom
     False: senderDisplayName égale au current, je mets pas d'espace et j'affiche pas le nom
     */
    func lastMessageFromSenderDisplayNameAndOutComming(senderDisplayName: String) -> Bool {
        var i = 0;
        for message in messages {
            /* ce qui veut dire que j'ai envoyé le message */
            if message.senderId == senderId {
                i += 1
                if i == 2 { /* <=> C'est le message juste avant*/
                    if message.senderDisplayName == senderDisplayName {
                        return false
                    }
                } else {
                    return true
                }
            }
        }
        return false
    }
    
    
    /*
     ça c'est pour savoir si on affiche le nom (senderDisplayName) avant le message ou pas
     */
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString!
    {
        let LOG = false
        _log_Title("Should display name sender", location: "ChatVC.attributedTextForMessageBubbleTopLabelAtIndexPath()", shouldLog: LOG)
        let message = messages[indexPath.item];
        /*Ceci est pour savoir si je dois afficher le pseudo si c'est moi qui envoi
         Commenter si je veux que oui */
        if(message.senderId == self.senderId){
            return nil;
        }
        if(indexPath.row - 1 > 0){
            let prevMessage = messages[indexPath.row-1];
            let timeInterval = Int(message.date.timeIntervalSinceDate(prevMessage.date))
            let shouldDisplayNameSender: Bool = timeInterval < timeIntervalBetweenMessages
            _log_Element("message content: \(message.text)", shouldLog: LOG)
            _log_Element("timeInterval: \(timeInterval)", shouldLog: LOG)
            _log_Element("shouldDisplay name sender: \(shouldDisplayNameSender)", shouldLog: LOG)
            if prevMessage.senderDisplayName == message.senderDisplayName && prevMessage.senderId == message.senderId && shouldDisplayNameSender {
                //print("message.senderId \(message.senderId), message.DN: \(message.senderDisplayName)")
                return nil;
            }
        }
        return NSAttributedString(string: message.senderDisplayName);
    }
    
    /*
     ça c'est pour savoir si on affiche un espace avant le message ou pas, pour laisser une place
     */
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        //print("isLastCellVisible: \(self.isLastCellVisible)")
        let LOG = false
        let currentMessage = self.messages[indexPath.item]
        
        /*Ceci est pour savoir si je dois afficher le pseudo si c'est moi qui envoi
         Commenter si je veux que oui
         */
        if(currentMessage.senderId == self.senderId){
            return 0.0
        }
        if(indexPath.item - 1 >= 0){
            let previousMessage = self.messages[indexPath.item - 1]
            let timeInterval = Int(currentMessage.date.timeIntervalSinceDate(previousMessage.date))
            let shouldLetSpaceToDisplaySomething: Bool = timeInterval < 20*60
            _log_Element("message content: \(currentMessage.text)", shouldLog: LOG)
            _log_Element("timeInterval: \(timeInterval)", shouldLog: LOG)
            _log_Element("shouldDisplay name sender: \(shouldLetSpaceToDisplaySomething)", shouldLog: LOG)
            if(previousMessage.senderDisplayName == currentMessage.senderDisplayName && previousMessage.senderId == currentMessage.senderId && shouldLetSpaceToDisplaySomething){
                return 0.0
            }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString!
    {
        let message = messages[indexPath.item]
        if indexPath.item == 0 {
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(message.date)
        } else if shouldDisplayDate(indexPath.item) {
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(message.date)
        }
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    private func setupBubbles() {
        let factory = JSQMessagesBubbleImageFactory()
        outgoingBubbleImageView = factory.outgoingMessagesBubbleImageWithColor(
            UIColor.jsq_messageBubbleBlueColor())
        incomingBubbleImageView = factory.incomingMessagesBubbleImageWithColor(
            UIColor.jsq_messageBubbleLightGrayColor())
    }
    
    override func didPressAccessoryButton(sender: UIButton!) {
        let imagePickerController = ImagePickerController()
        imagePickerController.imageLimit = 1
        imagePickerController.delegate = self
        self.presentViewController(imagePickerController, animated: true, completion: nil)
    }
    
    func wrapperDidPress(imagePicker: ImagePickerController, images: [UIImage]) {
        print("wrapperDidPress")
    }
    
    func doneButtonDidPress(imagePicker: ImagePickerController, images: [UIImage]) {
        print("done button did press")
        let pickedImage = images[0].resizedImageClosestTo1000
        let imageData = pickedImage.lowQualityJPEGNSData
        let imageName = "\(self.senderDisplayName)-\(NSDate())"
        let imageChatRef = FirebaseManager().createStorageRefChat(imageName)
        self.finishSendingMessage()
        dismissViewControllerAnimated(true, completion: nil)
        
        let _ = imageChatRef.putData(imageData, metadata: nil) { metadata, error in
            if (error != nil) {
                print("Error with imageData uploadTask [send image in Chat]")
            } else {
                // Metadata contains file metadata such as size, content-type, and download URL.
                let downloadURL = metadata!.downloadURL
                let imageURL = downloadURL()!.absoluteString
                print("imageURL = \(imageURL)")
                FirebaseManager.firebaseManager.sendMessageFirebase2("", senderId: self.senderId, senderDisplayName: self.senderDisplayName, date: NSDate(), isMedia: true, imageURL: imageURL)
            }
        }
    }
    
    func cancelButtonDidPress(imagePicker: ImagePickerController) {
        print("cancel button pressed")
    }
    
    func createPhotoArray(image: UIImage) -> ([Photo], Int) {
        var arrayPhoto = [Photo]()
        var index = 0
        var tag = -1
        for message in messages {
            
            if message.isMediaMessage {
                if let imageItem = message.media as? JSQPhotoMediaItem {
                    arrayPhoto.append(Photo(photo: imageItem.image))
                    if imageItem.image == image {
                        tag = index
                    }
                    index += 1
                }
            }
        }
        return (arrayPhoto, tag)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAtIndexPath indexPath: NSIndexPath!) {
        let message = self.messages[indexPath.row]
        if let imageItem = message.media as? JSQPhotoMediaItem {
            let image = imageItem.image
            let photo = Photo(photo: image!)
            let photos = createPhotoArray(image!)
            let tagIndexPhotoInArray = photos.1
            if tagIndexPhotoInArray != -1 {
                print("Tag calc = \(tagIndexPhotoInArray)")
                let viewer = NYTPhotosViewController(photos: photos.0, initialPhoto: photos.0[tagIndexPhotoInArray])
                presentViewController(viewer, animated: true, completion: nil)
            } else {
                let viewer = NYTPhotosViewController(photos: [photo])
                presentViewController(viewer, animated: true, completion: nil)
            }
        } else {
            print("Problem with the image JSQMediaItem when I click on an image on chat")
        }
    }
    
    /*[JSQMessage, scroll to bottom]*/
    /*
     Delegate JSQMessage
     */
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func shouldScrollToNewlyReceivedMessageAtIndexPath(indexPath: NSIndexPath!) -> Bool {
        //print("should scroll to botom: \(self.isLastCellVisible)")
        return self.isLastCellVisible
    }
    
    func shouldScrollToLastMessageAtStartup() -> Bool {
        return true
    }
    
}