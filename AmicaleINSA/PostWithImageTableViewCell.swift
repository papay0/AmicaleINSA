//
//  PostWithImageTableViewCell.swift
//  AmicaleINSA
//
//  Created by Arthur Papailhau on 03/04/16.
//  Copyright © 2016 Arthur Papailhau. All rights reserved.
//

import UIKit
import NYTPhotoViewer

class PostWithImageTableViewCell: UITableViewCell, NYTPhotosViewControllerDelegate {
    
    @IBOutlet weak var postImageView: UIImageView!
    @IBOutlet weak var titlePostLabel: UILabel!
    @IBOutlet weak var datePostLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    


}
