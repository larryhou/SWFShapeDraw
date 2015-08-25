//
//  ViewController.swift
//  SWFShapeDraw
//
//  Created by larryhou on 20/8/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import UIKit
import Foundation

class TestView:UIView
{
    override func drawRect(rect: CGRect)
    {
        let start  = CGPoint(x: frame.width / 2, y: 050)
        let center = CGPoint(x: frame.width / 2, y: 200)
        
        let arc = CGPathCreateMutable()
        CGPathMoveToPoint(arc, nil, start.x, start.y)
        CGPathAddArc(arc, nil, center.x, center.y, center.y - start.y, -CGFloat(M_PI) / 2.0, CGFloat(M_PI), false)
        
        let lineWidth:CGFloat = 40.0
        let strokedArc = CGPathCreateCopyByStrokingPath(arc, nil, lineWidth, CGLineCap.Butt, CGLineJoin.Miter, 10)
        
        let context = UIGraphicsGetCurrentContext()
        
        CGContextAddPath(context, strokedArc)
        CGContextSetFillColorWithColor(context, UIColor.lightGrayColor().CGColor)
        CGContextSetStrokeColorWithColor(context, UIColor.blackColor().CGColor)
        CGContextDrawPath(context, CGPathDrawingMode.FillStroke)
        
        let shadowColor = UIColor(white: 0, alpha: 0.75).CGColor
        CGContextSaveGState(context)
        
        CGContextAddPath(context, strokedArc)
        CGContextSetShadowWithColor(context, CGSizeMake(0, 2), 3, shadowColor)
        CGContextFillPath(context)
        
        CGContextRestoreGState(context)
        
        let colors:[CGFloat] = [0.75, 1.0,
                                0.90, 1.0]
        let space = CGColorSpaceCreateDeviceGray()
        let gradient = CGGradientCreateWithColorComponents(space, colors, nil, 2)
        
        CGContextSaveGState(context)
        
        CGContextAddPath(context, strokedArc)
        CGContextClip(context)
        
        let bounds = CGPathGetBoundingBox(strokedArc)
        let gradientStart = CGPointMake(0, CGRectGetMinY(bounds))
        let gradientEnd = CGPointMake(0, CGRectGetMaxY(bounds))
        
        CGContextDrawLinearGradient(context, gradient, gradientStart, gradientEnd, CGGradientDrawingOptions.DrawsBeforeStartLocation)
        CGContextRestoreGState(context)
    }
}

class ViewController: UIViewController
{
    private var shape:VectorShapeView!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
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
        
        let testView = TestView(frame: view.frame)
        testView.backgroundColor = UIColor.clearColor()
//        view.addSubview(testView)
        
        var frame = view.frame
        frame.origin.x = frame.width / 2
        frame.origin.y = frame.height / 2
        frame = view.frame
        
        shape = VectorShapeView(frame:frame);
        shape.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
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

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

