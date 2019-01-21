//
//  ViewController.swift
//  bonjourTest
//
//  Created by Pratyush on 29/05/18.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var discoverButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func discoverAction(_ sender: Any) {
        let browser: BonjourService = BonjourService()
//         This will find all HTTP servers - Check out BonjourService.Services for common services
        let result = browser.findService(BonjourService.Services.Hypertext_Transfer, domain: "") { (services) in
            // services will be an empty array if nothing was found
            print(services)
        }
        if !result {
            print("Not searching.")
        }
//        browser.publishService(port: 8080)
    }
}

