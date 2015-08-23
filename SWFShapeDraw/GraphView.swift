//
//  GraphView.swift
//  SWFShapeDraw
//
//  Created by larryhou on 22/8/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import Foundation
import UIKit

class GraphView:UIView
{
    struct GraphicsState:OptionSetType
    {
        let rawValue:Int
        init(rawValue:Int) { self.rawValue = rawValue }
        
        static let SolidStroke    = GraphicsState(rawValue: 1 << 0)
        static let GradientStroke = GraphicsState(rawValue: 1 << 1)
        static let SolidFill      = GraphicsState(rawValue: 1 << 2)
        static let GradientFill   = GraphicsState(rawValue: 1 << 3)
        
        static let Stroke:GraphicsState = [GraphicsState.SolidStroke, GraphicsState.GradientStroke]
        static let Fill:GraphicsState   = [GraphicsState.SolidFill,   GraphicsState.GradientFill]
    }
    
    struct GradientStyle
    {
        var type:String
        var gradient:CGGradient
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat)
        var focalPointRatio:CGFloat
    }
    
    private var state:GraphicsState!
    private var queue:[(method:String, params:NSDictionary)] = []
    
    private var path:CGMutablePath!
    
    func doStep(method:String, params:NSDictionary)
    {
        queue.append((method, params))
        setNeedsDisplay()
    }
    
    func getGradientStyle(params:NSDictionary) -> GradientStyle
    {
        let type = params.valueForKey("type") as! String
        let colors = params.valueForKey("colors") as! [Int]
        let alphas = params.valueForKey("alphas") as! [Double]
        
        var rgbaColors:[CGColor] = []
        for i in 0..<colors.count
        {
            let rgbColor = colors[i]
            let b = (rgbColor >> 00) & 0xFF
            let g = (rgbColor >> 08) & 0xFF
            let r = (rgbColor >> 16) & 0xFF
            let color = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alphas[i])).CGColor
            rgbaColors.append(color)
        }
        
        let ratios = params.valueForKey("ratios") as! [Int]
        var locations = ratios.map({ CGFloat($0) / 0xFF })
        
        let gradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), rgbaColors, &locations)
        
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat) = (0,0,0,0,0,0)
        matrix.a = CGFloat(params.valueForKeyPath("matrix.a") as! Double)
        matrix.b = CGFloat(params.valueForKeyPath("matrix.b") as! Double)
        matrix.c = CGFloat(params.valueForKeyPath("matrix.c") as! Double)
        matrix.d = CGFloat(params.valueForKeyPath("matrix.d") as! Double)
        matrix.tx = CGFloat(params.valueForKeyPath("matrix.tx") as! Double)
        matrix.ty = CGFloat(params.valueForKeyPath("matrix.ty") as! Double)
        
        let focalPointRatio = CGFloat(params.valueForKey("focalPointRatio") as! Double)
        return GradientStyle(type: type, gradient: gradient!, matrix: matrix, focalPointRatio: focalPointRatio)
    }
    
    func getCoord(params:NSDictionary, key:String) -> CGFloat
    {
        let value = params.valueForKey(key) as! Double
        return CGFloat(value)
    }
    
    func getColor(params:NSDictionary, colorKey:String, alphaKey:String) -> UIColor
    {
        let rgbColor:Int
        if params.valueForKey(colorKey) != nil
        {
            rgbColor = params.valueForKey(colorKey) as! Int
        }
        else
        {
            rgbColor = 0
        }
        
        let b = (rgbColor >> 00) & 0xFF
        let g = (rgbColor >> 08) & 0xFF
        let r = (rgbColor >> 16) & 0xFF
        
        let a:Double
        if params.valueForKey(alphaKey) != nil
        {
            a = params.valueForKey(alphaKey) as! Double
        }
        else
        {
            a = 1.0
        }
        
        return UIColor(red: CGFloat(r)/0xFF, green: CGFloat(g)/0xFF, blue: CGFloat(b)/0xFF, alpha: CGFloat(a)/0xFF)
    }
    
    override func drawRect(rect: CGRect)
    {
        if queue.count == 0
        {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        let step = queue.removeFirst()
        
        let params = step.params
        
        switch step.method
        {
            case "LINE_STYLE":
                CGContextRestoreGState(context)
                CGContextSaveGState(context)
               
                state = GraphicsState.SolidStroke
            
            case "LINE_GRADIENT_STYLE":
                CGContextRestoreGState(context)
                CGContextSaveGState(context)
                
                state = GraphicsState.GradientStroke
                setContextGradientStyle(context!, params: params)
                
            case "LINE_TO":
                if GraphicsState.Stroke.contains(state)
                {
                    CGContextAddLineToPoint(context,
                        getCoord(params, key: "x"), getCoord(params, key: "y"))
                }
                else
                {
                    CGPathAddLineToPoint(path, nil,
                        getCoord(params, key: "x"), getCoord(params, key: "y"))
                }
            
            case "MOVE_TO":
                if GraphicsState.Stroke.contains(state)
                {
                    CGContextMoveToPoint(context,
                        getCoord(params, key: "x"), getCoord(params, key: "y"))
                }
                else
                {
                    CGPathMoveToPoint(path, nil,
                        getCoord(params, key: "x"), getCoord(params, key: "y"))
                }
                
            case "CURVE_TO":
                if GraphicsState.Stroke.contains(state)
                {
                    CGContextAddQuadCurveToPoint(context,
                        getCoord(params, key: "controlX"), getCoord(params, key: "controlY"),
                        getCoord(params, key: "anchorX"),  getCoord(params, key: "anchorY"))
                }
                else
                {
                    CGPathAddQuadCurveToPoint(path, nil,
                        getCoord(params, key: "controlX"), getCoord(params, key: "controlY"),
                        getCoord(params, key: "anchorX"),  getCoord(params, key: "anchorY"))
                }
                
            case "BEGIN_FILL":
                CGContextRestoreGState(context)
                CGContextSaveGState(context)
                
                CGContextSetFillColorWithColor(context, getColor(params, colorKey: "color", alphaKey: "alpha").CGColor)
                
                path = CGPathCreateMutable()
            
                state = GraphicsState.SolidFill
            
            case "BEGIN_GRADIENT_FILL":
                CGContextRestoreGState(context)
                CGContextSaveGState(context)
                
                path = CGPathCreateMutable()
                
                state = GraphicsState.GradientFill
                setContextGradientStyle(context!, params: params)
            
            case "END_FILL":
                CGContextAddPath(context, path)
                CGContextFillPath(context)
                
                path = nil
                CGContextRestoreGState(context)
                
            default:break
        }
    }
    
    func setContextGradientStyle(context:CGContext, params:NSDictionary)
    {
        let style = getGradientStyle(params)
        let matrix = style.matrix
        
        let angle = -atan2(matrix.c, matrix.a)
        let scaleX = matrix.a / cos(angle)
        let scaleY = matrix.b / sin(angle)
        
        let width = scaleX * 1638.4, height = scaleY * 1638.4
        
        if style.type == "radial"
        {
            if width != height
            {
                //TODO: 椭圆情况做变形处理
            }
            
            let endRadius = max(width / 2, height / 2);
            let startCenter = CGPointMake(width / 2 * cos(angle) * style.focalPointRatio + matrix.tx,
                                         height / 2 * sin(angle) * style.focalPointRatio + matrix.ty)
            let endCenter = CGPointMake(matrix.tx, matrix.ty)
            
            CGContextDrawRadialGradient(context, style.gradient, startCenter, 0, endCenter, endRadius, CGGradientDrawingOptions(rawValue: 0))
        }
        else
        {
            let sp = CGPointMake(-819.2 * scaleX, 0)
            let startPoint = CGPointMake(sp.x * cos(angle) - sp.y * sin(angle) + matrix.tx,
                                         sp.x * sin(angle) + sp.y * cos(angle) + matrix.ty)
            let ep = CGPointMake( 819.2 * scaleX, 0)
            let endPoint = CGPointMake(ep.x * cos(angle) - ep.y * sin(angle) + matrix.tx,
                                       ep.x * sin(angle) + ep.y * cos(angle) + matrix.ty)
            
            CGContextDrawLinearGradient(context, style.gradient, startPoint, endPoint, CGGradientDrawingOptions(rawValue: 0))
        }
        
        CGContextFillPath(context)
    }
}
