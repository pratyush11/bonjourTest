//
//  ViewController.swift
//  bonjourTest
//
//  Created by Shishir Jain on 29/05/18.
//

import UIKit

class ViewController: UIViewController {

    var netService:NetService
    var type:String
    var ipAddress:String
    
    init(netService:NetService, type:String, ipAddress:String) {
        self.netService = netService
        self.type = type
        self.ipAddress = ipAddress
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

