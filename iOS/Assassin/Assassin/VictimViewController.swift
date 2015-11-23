//
//  ViewController.swift
//  Assassin
//
//  Created by Yuanhao Li on 16/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit


class VictimViewController: UIViewController {

    @IBOutlet weak var victimStatusImage: UIImageView!
    @IBOutlet weak var victimHPLabel: UILabel!
    var overlayView: UIView!
    
    var manager: VictimManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initViews()
        self.manager = VictimManager(controller: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func initViews() {
        self.overlayView = DamageWarningView(frame: self.view.bounds)
    }
    
    func flashDamageWarning() {
        self.view.addSubview(self.overlayView)
        // Delay 0.5 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                self.overlayView.removeFromSuperview()
        }
    }
}


class DamageWarningView: UIView {
    var label: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    func setupView() {
        self.backgroundColor = UIColor.redColor().colorWithAlphaComponent(0.5)

        self.label = UILabel()
        self.label.text = "Run!"
        self.label.font = self.label.font.fontWithSize(100)
        self.label.textColor = UIColor.whiteColor()
        self.label.sizeToFit()
        self.label.frame.origin = CGPoint(x: (self.bounds.width - self.label.frame.width) / 2.0, y: (self.bounds.height - self.label.frame.height) / 2.0)
        self.addSubview(self.label)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

