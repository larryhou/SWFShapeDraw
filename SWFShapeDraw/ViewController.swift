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
    private var steps:NSArray!
    private var stepIndex = 0
    private var shape:VectorShapeView!

    override func viewDidLoad()
    {
        super.viewDidLoad()
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
            
            stepIndex = 0
//            NSTimer.scheduledTimerWithTimeInterval(1.0/50, target: self, selector: "timeTickUpdate:", userInfo: nil, repeats: true)
            
        }
        
        let testView = TestView(frame: view.frame)
        testView.backgroundColor = UIColor.clearColor()
//        view.addSubview(testView)
        
        var frame = view.frame
        frame.origin.x = frame.width / 2
        frame.origin.y = frame.height / 2
        frame = view.frame
        
        shape = VectorShapeView(frame:frame);
        shape.backgroundColor = UIColor.clearColor()
        view.addSubview(shape)
        
        setupShape()
        drawShape()
    }
    
    func setupShape()
    {
        var bounds:(left:CGFloat, top:CGFloat, right:CGFloat, bottom:CGFloat) = (0,0,0,0)
        for i in 0..<steps.count
        {
            let data = steps[i] as! NSArray
            let method = data.objectAtIndex(0) as! String
            let params = data.objectAtIndex(1) as! NSDictionary
            
            var x:CGFloat = 0.0, y:CGFloat = 0.0
            switch method
            {
                case "MOVE_TO", "LINE_TO":
                    x = CGFloat(params.valueForKey("x") as! Double)
                    y = CGFloat(params.valueForKey("y") as! Double)
                case "CURVE_TO":
                    x = CGFloat(params.valueForKey("anchorX") as! Double)
                    y = CGFloat(params.valueForKey("anchorY") as! Double)
                default:break
            }
            
            bounds.left   = min(x, bounds.left)
            bounds.right  = max(x, bounds.right)
            bounds.top    = min(y, bounds.top)
            bounds.bottom = max(y, bounds.bottom)
        }
        
        shape.irect = CGRectMake(bounds.left, bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top)
    }
    
    func drawShape()
    {
        for i in 0..<steps.count
        {
            let data = steps[i] as! NSArray
            let method = data.objectAtIndex(0) as! String
            let params = data.objectAtIndex(1) as! NSDictionary
            
            shape.doStep(method, params: params)
        }
        
        shape.setNeedsDisplay()
    }
    
    func timeTickUpdate(timer:NSTimer)
    {
        if (stepIndex >= steps.count)
        {
            timer.invalidate()
            return
        }
        
        let data = steps[stepIndex] as! NSArray
        let method = data.objectAtIndex(0) as! String
        let params = data.objectAtIndex(1) as! NSDictionary
        
        shape.doStep(method, params: params)
        
        stepIndex++
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

