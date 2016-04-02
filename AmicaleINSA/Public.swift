//
//  Public.swift
//  AmicaleINSA
//
//  Created by Arthur Papailhau on 28/02/16.
//  Copyright © 2016 Arthur Papailhau. All rights reserved.
//

import Foundation
import UIKit

public struct Storyboard {
    
    // Chat
    static let usernameChat = "usernameChat"
    static let usernameChatRegistred = "usernameChatRegistred"
    
    // Settings
    static let profilePictureIsSet = "profilePictureIsSet"
    static let profilePicture = "profilePicture"
    
    // Webview offset
    static let Monday_iPhone4 = 0
    static let Tuesday_iPhone4 = 160
    static let Wednesday_iPhone4 = 350
    static let Thursday_iPhone4 = 530
    static let Friday_iPhone4 = 700
    static let Weekend_iPhone4 = 0
    
    static let Monday_iPhone5 = 0
    static let Tuesday_iPhone5 = 165
    static let Wednesday_iPhone5 = 350
    static let Thursday_iPhone5 = 530
    static let Friday_iPhone5 = 700
    static let Weekend_iPhone5 = 0
    
    static let Monday_iPhone6 = 0
    static let Tuesday_iPhone6 = 190
    static let Wednesday_iPhone6 = 410
    static let Thursday_iPhone6 = 625
    static let Friday_iPhone6 = 850
    static let Weekend_iPhone6 = 0
    
    static let Monday_iPhone6Plus = 0
    static let Tuesday_iPhone6Plus = 210
    static let Wednesday_iPhone6Plus = 445
    static let Thursday_iPhone6Plus = 685
    static let Friday_iPhone6Plus = 860
    static let Weekend_iPhone6Plus = 0
    
    static let urlProxyWash = "http://www.proxiwash.com/weblaverie/ma-laverie-2?s=cf4f39&16d33a57b3fb9a05d4da88969c71de74=1"
    
    static let idPlanningExpress = "idPlanningExpress"
    static let rowPickerViewSettings = "rowPickerViewSettings"
    
}

/*
    Function called when app launched
*/

public func initApp() {
    if (NSUserDefaults.standardUserDefaults().boolForKey(Storyboard.usernameChatRegistred) ==  false) {
        let usernameChat = "invite\(Int(arc4random_uniform(UInt32(2500))))"
        NSUserDefaults.standardUserDefaults().setObject(usernameChat, forKey: Storyboard.usernameChat)
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: Storyboard.usernameChatRegistred)
    }
}

/*
    username getter/setter
*/

public func setUsernameChat(username: String) {
    NSUserDefaults.standardUserDefaults().setObject(username, forKey: Storyboard.usernameChat)
}

public func getUsernameChat() -> String {
    return NSUserDefaults.standardUserDefaults().stringForKey(Storyboard.usernameChat)!
}


/*
    profile picture getter/setter
*/

public func setProfilPicture(image : UIImage){
    NSUserDefaults.standardUserDefaults().setObject(UIImagePNGRepresentation(image), forKey: Storyboard.profilePicture)
    NSUserDefaults.standardUserDefaults().setBool(true, forKey: Storyboard.profilePictureIsSet)
    NSUserDefaults.standardUserDefaults().synchronize()
}

public func getProfilPicture() -> UIImage {
    let isProfilePictureIsSet = NSUserDefaults.standardUserDefaults().boolForKey(Storyboard.profilePictureIsSet)
    if isProfilePictureIsSet{
        if let  imageData = NSUserDefaults.standardUserDefaults().objectForKey(Storyboard.profilePicture) as? NSData {
            let profilePicture = UIImage(data: imageData)
            return profilePicture!
        } else{
            return  UIImage(named: "defaultPic")! }
    } else {
        return UIImage(named: "defaultPic")!
    }
}