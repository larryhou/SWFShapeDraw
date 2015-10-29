//
//  SWFShapeDrawTests.swift
//  SWFShapeDrawTests
//
//  Created by larryhou on 20/8/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import XCTest

class SWFShapeDrawTests: XCTestCase
{
    
    func testQuartzPerformance()
    {
        let bundle = NSBundle(forClass: VectorImageView.self)
        let url = bundle.URLForResource("graph", withExtension: "json")
        assert(url != nil)
        
        var steps:NSArray!
        if url != nil
        {
            let data = NSData(contentsOfURL: url!)
            
            do
            {
                steps = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as! NSArray
            }
            catch
            {
                assertionFailure("JSON parsing failed")
            }
        }
        
        let rect = UIScreen.mainScreen().bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.mainScreen().scale)
        
        let vector = VectorImageView(frame:rect)
        vector.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        vector.importVectorGraphics(steps)
        self.measureBlock
        {
            vector.drawRect(rect)
        }
    }
}
