//
//  ViewController.swift
//  imgZip4Flutter
//
//  Created by songxing10000 on 02/22/2022.
//  Copyright (c) 2022 songxing10000. All rights reserved.
//

import Cocoa
import imgZip4Flutter
class ViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    @IBAction func clickBtn(_ sender: NSButton) {
        let vc = ReNameVC.vc()
        presentAsModalWindow(vc)
    }
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
}

