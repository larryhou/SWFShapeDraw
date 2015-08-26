//
//  ViewController.swift
//  SWFShapeDraw
//
//  Created by larryhou on 20/8/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import UIKit
import Foundation

class ViewController: UIViewController, UIScrollViewDelegate
{
    private var shape:RedrawView!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        let view = self.view as! UIScrollView
        view.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        view.delegate = self
        view.maximumZoomScale = 2.0
        view.minimumZoomScale = 1.0
        
        var steps:NSArray!
        let jurl = NSBundle.mainBundle().URLForResource("graph", withExtension: "json")
        if jurl != nil
        {
            let data = NSData(contentsOfURL: jurl!)
            
            do
            {
                steps = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as! NSArray
            }
            catch
            {
                print(error)
                return
            }
        }
        
        shape = RedrawView(frame:view.frame);
        shape.backgroundColor = UIColor.clearColor()
        shape.center = CGPoint(x: CGRectGetMidX(shape.bounds), y: CGRectGetMidY(shape.bounds))
        view.addSubview(shape)
        
        drawShape(steps)
    }
    
    func unionBoundsWithPoint(inout bounds:(left:CGFloat, top:CGFloat, right:CGFloat, bottom:CGFloat), x:CGFloat, y:CGFloat)
    {
        bounds.left   = min(x, bounds.left)
        bounds.right  = max(x, bounds.right)
        bounds.top    = min(y, bounds.top)
        bounds.bottom = max(y, bounds.bottom)
    }
    
    func drawShape(steps:NSArray)
    {
        var list:[(method:String, params:NSDictionary)] = []
        var bounds:(left:CGFloat, top:CGFloat, right:CGFloat, bottom:CGFloat) = (0,0,0,0)
        
        for i in 0..<steps.count
        {
            let data = steps[i] as! NSArray
            let method = data.objectAtIndex(0) as! String
            let params = data.objectAtIndex(1) as! NSDictionary
            list.append((method, params))
            
            var x:CGFloat = 0.0, y:CGFloat = 0.0
            switch method
            {
                case "MOVE_TO", "LINE_TO":
                    x = CGFloat(params.valueForKey("x") as! Double)
                    y = CGFloat(params.valueForKey("y") as! Double)
                    unionBoundsWithPoint(&bounds, x: x, y: y)
                    
                case "CURVE_TO":
                    x = CGFloat(params.valueForKey("anchorX") as! Double)
                    y = CGFloat(params.valueForKey("anchorY") as! Double)
                    unionBoundsWithPoint(&bounds, x: x, y: y)
                    
                    x = CGFloat(params.valueForKey("controlX") as! Double)
                    y = CGFloat(params.valueForKey("controlY") as! Double)
                    unionBoundsWithPoint(&bounds, x: x, y: y)
                default:break
            }
        }
        
        shape.irect = CGRectMake(bounds.left, bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top)
        shape.importSteps(list)
        
        NSTimer.scheduledTimerWithTimeInterval(1.0 / 25, target: self, selector: "timeTickUpdate:", userInfo: nil, repeats: true)
    }
    
    func timeTickUpdate(timer:NSTimer)
    {
        if shape.stepsAvaiable
        {
            shape.setNeedsDisplay()
        }
        else
        {
            timer.invalidate()
        }
    }
    
    //MARK: zoom
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView?
    {
        return shape
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

