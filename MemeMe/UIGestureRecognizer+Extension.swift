//
//  UIGestureRecognizer+Extension.swift
//  MemeMe
//
//  Created by Luke Van In on 2017/01/05.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

extension UIGestureRecognizer {
    //
    //  Check if a given view is being touched by the gesture.
    //  Returns true if the gesture location is contained within the view bounds.
    //  Used by MemeViewController to determine if a non-interactive text field is tapped.
    //
    func isContained(in view: UIView) -> Bool {
        let p = location(in: view)
        return view.bounds.contains(p)
    }
}
