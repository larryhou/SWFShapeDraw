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
    private var index = 0

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
                print((steps[0] as! NSArray)[1])
            }
            catch
            {
                print(error)
                return
            }
            
            index = 0
            NSTimer.scheduledTimerWithTimeInterval(1.0/50, target: self, selector: "timeTickUpdate:", userInfo: nil, repeats: true)
            
        }
        
        let testView = TestView(frame: view.frame)
        testView.backgroundColor = UIColor.clearColor()
        view.addSubview(testView)
        
    }
    
    func timeTickUpdate(timer:NSTimer)
    {
        if (index >= steps.count)
        {
            timer.invalidate()
            return
        }
        
        let data = steps[index] as! NSArray
        let method = data.objectAtIndex(0) as! String
        let params = data.objectAtIndex(1) as! NSDictionary
        switch method
        {
            case "LINE_STYLE":break
            case "LINE_GRADIENT_STYLE":break
            case "LINE_TO":break
            case "MOVE_TO":break
            case "CURVE_TO":break
            case "BEGIN_FILL":break
            case "BEGIN_GRADIENT_FILL":break
            case "END_FILL":break
            default:break
        }
        
        print(params.valueForKey("caps"))
        
        index++
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

